#!/usr/local/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2011  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use Hebcal ();
use POSIX qw(strftime);
use MIME::Base64 ();
use Time::Local ();
use DBI ();
use Hebcal::SMTP;
use Getopt::Long ();
use Log::Message::Simple qw[:STD :CARP];

my $VERSION = '$Revision$$';
if ($VERSION =~ /(\d+)/) {
    $VERSION = $1;
}

my $opt_all = 0;
my $opt_help;
my $opt_verbose = 0;
my $opt_log = 1;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "all" => \$opt_all,
     "log!" => \$opt_log,
     "verbose|v+" => \$opt_verbose)) {
    usage();
}

$opt_help && usage();
usage() if !@ARGV && !$opt_all;

my %SUBS;
load_subs();
if (! keys(%SUBS) && !$opt_all) {
    croak "$ARGV[0]: not found";
}

my($LOGIN) = getlogin() || getpwuid($<) || "UNKNOWN";

my $now = time;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;

my $midnight = Time::Local::timelocal(0,0,0,
				      $mday,$mon,$year,$wday,$yday,$isdst);
my $saturday = $now + ((6 - $wday) * 60 * 60 * 24);
my $five_days_ahead = $midnight + (5 * 60 * 60 * 24);
my $endofweek = $five_days_ahead > $saturday ? $five_days_ahead : $saturday;
my $sat_year = (localtime($saturday))[5] + 1900;

my $HOME = "/home/hebcal";
my $ZIPS_DBH = Hebcal::zipcode_open_db();

if ($opt_log) {
    my $logfile = sprintf("%s/local/var/log/shabbat-%04d%02d%02d",
			  $HOME, $year, $mon+1, $mday);
    if ($opt_all) {
	if (open(LOG, "<$logfile")) {
	    my $count = 0;
	    while(<LOG>) {
		my($msgid,$status,$to,$loc) = split(/:/);
		if ($status && defined $to && defined $SUBS{$to}) {
		    delete $SUBS{$to};
		    $count++;
		}
	    }
	    close(LOG);
	    msg("Skipping $count users from $logfile", $opt_verbose);
	}
    }
    open(LOG, ">>$logfile") || croak "$logfile: $!";
    select LOG;
    $| = 1;
    select STDOUT;
}

my $HOSTNAME = `/bin/hostname -f`;
chomp($HOSTNAME);

my @AUTH =
    (
     ['lw7d08fj2u7guglw@hebcal.com', 'xxxxxxxxxxxxxxxx'],
     ['hebcal-shabbat-weekly@hebcal.com', 'xxxxxxxxxxxxxxxx'],
     ['shabbat-cron@hebcal.com', 'xxxxxxxxxxxxxxxxx'],
     ['kyg0f4neienvfpgx@hebcal.com', 'xxxxxxxx'],
     );
my @SMTP;
my $SMTP_HOST = "mail.hebcal.com";
my $SMTP_NUM_CONNECTIONS = scalar(@AUTH);
msg("Opening $SMTP_NUM_CONNECTIONS SMTP connections", $opt_verbose);
for (my $i = 0; $i < $SMTP_NUM_CONNECTIONS; $i++) {
    $SMTP[$i] = undef;
    smtp_reconnect($i, 1);
}
# dh limit 100 emails an hour per authenticated user
my $SMTP_SLEEP_TIME = int(40 / $SMTP_NUM_CONNECTIONS);
msg("All SMTP connections open; will sleep for $SMTP_SLEEP_TIME sec between messages",
    $opt_verbose);

my %CONFIG;
my %ZIP_CACHE;
mail_all();

close(LOG) if $opt_log;

msg("Disconnecting from SMTP", $opt_verbose);
foreach my $smtp (@SMTP) {
    $smtp->quit();
}

Hebcal::zipcode_close_db($ZIPS_DBH);

msg("Success!", $opt_verbose);
exit(0);

sub mail_all
{
    msg("Loading config", $opt_verbose);
    while(my($to,$cfg) = each(%SUBS)) {
	my($cmd,$loc,$args) = parse_config($cfg);
	$CONFIG{$to} = [$cmd,$loc,$args];
    }

    my $MAX_FAILURES = 100;
    my $RECONNECT_INTERVAL = 20;
    my $failures = 0;
    for (;;) {
	my @addrs = keys %SUBS;
	my $count =  scalar(@addrs);
	last if $count == 0;
	msg("About to mail $count users ($failures previous failures)",
	    $opt_verbose);
	# sort the addresses by timezone so we mail eastern users first
	@addrs = sort by_timezone @addrs;
	for (my $i = 0; $i < $count; $i++) {
	    my $to = $addrs[$i];
	    my $server_num = $i % $SMTP_NUM_CONNECTIONS;
	    my $success = mail_user($to, $SMTP[$server_num]);
	    if ($success) {
		delete $SUBS{$to};
		# reconnect every so often
		if (($i % $RECONNECT_INTERVAL) == ($RECONNECT_INTERVAL - 1)) {
		    smtp_reconnect($server_num, 1);
		}
	    } else {
		if (++$failures >= $MAX_FAILURES) {
		    carp "Got $failures failures, giving up";
		    return;
		}
		# reconnect to see if this helps
		smtp_reconnect($server_num, 1);
	    }
	    sleep($SMTP_SLEEP_TIME) unless $i == ($count - 1);
	}
    }
    msg("Done ($failures failures)", $opt_verbose);
}

sub get_latlong {
    my($id) = @_;
    my $args = $CONFIG{$id}->[2];
    if (defined $args->{"zip"}) {
    	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    get_zipinfo($args->{"zip"});
	my $lat = $lat_deg + ($lat_min / 60.0);
	my $long = $long_deg + ($long_min / 60.0);
	if ($opt_verbose > 2) {
	  msg("zip=" . $args->{"zip"} . ",lat=$lat,long=$long", $opt_verbose);
	}
	return ($lat, $long, $tz, $city);
    } else {
	my $latlong = $Hebcal::CITY_LATLONG{$args->{"city"}};
	my($lat,$long) = (0.0,0.0);
	if (defined $latlong) {
	  ($lat,$long) = ($latlong->[0], -1.0 * $latlong->[1]);
	}
	if ($opt_verbose > 2) {
	  msg("city=" . $args->{"city"} . ",lat=$lat,long=$long", $opt_verbose);
	}
	return ($lat, $long,
		$Hebcal::city_tz{$args->{"city"}},
		$args->{"city"});
    }
}

sub by_timezone {
    my($lat_a,$long_a,$tz_a,$city_a) = get_latlong($a);
    my($lat_b,$long_b,$tz_b,$city_b) = get_latlong($b);
    if ($tz_a != $tz_b) {
	return $tz_b <=> $tz_a;
    }
    if ($long_a == $long_b) {
	if ($lat_a == $lat_b) {
	    return $city_a cmp $city_b;
	} else {
	    return $lat_a <=> $lat_b;
	}
    } else {
	return $long_a <=> $long_b;
    }
}

sub mail_user
{
    my($to,$smtp) = @_;

    my $cfg = $SUBS{$to} or croak "invalid user $to";

    my($cmd,$loc,$args) = @{$CONFIG{$to}};
    return 1 unless $cmd;

    if ($opt_verbose > 1) {
      msg("to=$to   cmd=$cmd", $opt_verbose);
    }

    my @events = Hebcal::invoke_hebcal("$cmd $sat_year","",undef);
    if ($sat_year != $year) {
	# Happens when Friday is Dec 31st and Sat is Jan 1st
	my @ev2 = Hebcal::invoke_hebcal("$cmd $year","",undef);
	@events = (@ev2, @events);
    }

    my $encoded = MIME::Base64::encode_base64($to);
    chomp($encoded);
    my $unsub_url = "http://www.hebcal.com/email/?" .
	"e=" . my_url_escape($encoded);

    my($body) = gen_body(\@events) . qq{
$loc

Shabbat Shalom,
hebcal.com

To modify your subscription or to unsubscribe completely, visit:
$unsub_url
};

    my $email_mangle = $to;
    $email_mangle =~ s/\@/=/g;
    my $return_path = sprintf('shabbat-return-%s@hebcal.com', $email_mangle);

    my $lighting = get_friday_candles(\@events);
    my $msgid = $args->{"id"} . "." . time();

    my %headers =
	(
	 "From" => "Hebcal <shabbat-owner\@hebcal.com>",
	 "To" => $to,
	 "MIME-Version" => "1.0",
	 "Content-Type" => "text/plain",
	 "Subject" => "[shabbat] Candles $lighting",
	 "List-Unsubscribe" => "<$unsub_url&unsubscribe=1&v=1>",
	 "List-Id" => "<shabbat.hebcal.com>",
	 "Errors-To" => $return_path,
	 "Precedence" => "bulk",
	 "Message-ID" => "<$msgid\@hebcal.com>",
	 );

    my $status = my_sendmail($smtp,$return_path,\%headers,$body);
    if ($opt_log) {
	print LOG join(":", $msgid, $status, $to,
		       defined $args->{"zip"} 
		       ? $args->{"zip"} : $args->{"city"}), "\n";
    }

    $status;
}

sub my_url_escape
{
    my($str) = @_;

    $str =~ s/([^\w\$. -])/sprintf("%%%02X", ord($1))/eg;
    $str =~ s/ /+/g;

    $str;
}

sub get_friday_candles
{
    my($events) = @_;
    my($numEntries) = scalar(@{$events});
    my($i);
    my $retval = "";
    for ($i = 0; $i < $numEntries; $i++)
    {
	my $time = Hebcal::event_to_time($events->[$i]);
	next if $time < $midnight || $time > $endofweek;

	my $year = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my $mon = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $mday = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];
	my $subj = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $dow = Hebcal::get_dow($year, $mon, $mday);

	if ($dow == 5 && $subj eq "Candle lighting")
	{
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    $hour -= 12 if $hour > 12;

	    $retval .= sprintf("%d:%02dpm", $hour, $min);
	}
	elsif ($dow == 6 && $subj =~ /^(Parshas\s+|Parashat\s+)(.+)$/)
	{
	    my $parashat = $1;
	    my $sedra = $2;
	    $retval .= " - $sedra";
	}
    }

    return $retval;
}

sub gen_body
{
    my($events) = @_;

    my $body = "";

    my %holiday_seen;
    my($numEntries) = scalar(@{$events});
    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	# holiday is at 12:00:01 am
	my $time = Hebcal::event_to_time($events->[$i]);
	next if $time < $midnight || $time > $endofweek;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($year) = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $strtime = strftime("%A, %B %d", localtime($time));

	if ($subj eq "Candle lighting" || $subj =~ /Havdalah/)
	{
	    $body .= sprintf("%s is at %d:%02dpm on %s\n",
			     $subj, $hour, $min, $strtime);
	}
	elsif ($subj eq "No sunset today.")
	{
	    $body .= "No sunset on $strtime\n";
	}
	elsif ($subj =~ /^(Parshas|Parashat)\s+/)
	{
	    $body .= "This week's Torah portion is $subj\n";
	    $body .= "  http://www.hebcal.com" .
	      Hebcal::get_holiday_anchor($subj,undef,undef) . "\n";
	}
	else
	{
	    $body .= "$subj occurs on $strtime\n";
	    my $hanchor = Hebcal::get_holiday_anchor($subj,undef,undef);
	    if ($hanchor && !$holiday_seen{$hanchor}) {
		$body .= "  http://www.hebcal.com" . $hanchor . "\n";
		$holiday_seen{$hanchor} = 1;
	    }
	}
    }

    $body;
}

sub load_subs
{
    my $dsn = "DBI:mysql:database=hebcal5;host=mysql5.hebcal.com";
    my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

    my $all_sql = "";
    if (!$opt_all) {
	$all_sql = "AND email_address IN ('" . join("','", @ARGV) . "')";
    }

    my $sql = <<EOD
SELECT email_address,
       email_id,
       email_candles_zipcode,
       email_candles_city,
       email_candles_havdalah
FROM hebcal_shabbat_email
WHERE hebcal_shabbat_email.email_status = 'active'
AND hebcal_shabbat_email.email_ip IS NOT NULL
$all_sql
EOD
;

    msg($sql, $opt_verbose);
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or croak "can't execute the query: " . $sth->errstr;
    my $count = 0;
    while (my($email,$id,$zip,$city,$havdalah) = $sth->fetchrow_array) {
	my $cfg = "id=$id;m=$havdalah";
	if ($zip) {
	    $cfg .= ";zip=$zip";
	} elsif ($city) {
	    $cfg .= ";city=$city";
	}
	$SUBS{$email} = $cfg;
	$count++;
    }

    $dbh->disconnect;

    msg("Loaded $count users", $opt_verbose);
    $count;
}

sub get_zipinfo
{
    my($zip) = @_;

    if (defined $ZIP_CACHE{$zip}) {
	return @{$ZIP_CACHE{$zip}};
    } else {
	my @f = Hebcal::zipcode_get_zip_fields($ZIPS_DBH, $zip);
	$ZIP_CACHE{$zip} = \@f;
	return @f;
    }
}

sub parse_config
{
    my($config) = @_;

    my $cmd = "$HOME/web/hebcal.com/bin/hebcal";

    my %args;
    foreach my $kv (split(/;/, $config)) {
	my($key,$val) = split(/=/, $kv, 2);
	$args{$key} = $val;
    }

    my $city_descr;
    if (defined $args{"zip"}) {
    	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    get_zipinfo($args{"zip"});
	unless (defined $state) {
	    carp "unknown zipcode [$config]";
	    return undef;
	}

	$city_descr = "These times are for:";
	$city_descr .= "\n  $city, $state " . $args{"zip"};
	$city_descr .= "\n  " . $Hebcal::tz_names{$tz};

	if (defined $tz && $tz ne "?") {
	    $cmd .= " -z $tz";
	}

	if ($dst == 1) {
	    $cmd .= " -Z usa";
	} elsif ($dst == 0) {
	    $cmd .= " -Z none";
	}

	$cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    } elsif (defined $args{"city"}) {
	$city_descr = $args{"city"};
	$city_descr =~ s/\+/ /g;
	$cmd .= " -C '" . $city_descr . "'";
	$cmd .= " -i"
	    if ($Hebcal::city_dst{$city_descr} eq "israel");
	$city_descr = "These times are for $city_descr.";
    } else {
	carp "no geographic key in [$config]";
	return undef;
    }

    $cmd .= " -m " . $args{"m"}
	if (defined $args{"m"} && $args{"m"} =~ /^\d+$/);

    $cmd .= " -s -c";

    ($cmd,$city_descr,\%args);
}

sub smtp_reconnect
{
    my($server_num,$debug) = @_;

    croak "server number $server_num too large"
	if $server_num >= $SMTP_NUM_CONNECTIONS;

    if (defined $SMTP[$server_num]) {
	$SMTP[$server_num]->quit();
	$SMTP[$server_num] = undef;
    }
    my $user = $AUTH[$server_num]->[0];
    my $password = $AUTH[$server_num]->[1];
    my $smtp = smtp_connect($SMTP_HOST, $user, $password, $debug)
	or croak "Can't connect to $SMTP_HOST as $user";
    $SMTP[$server_num] = $smtp;
    return $smtp;
}

sub smtp_connect
{
    my($s,$user,$password,$debug) = @_;

    # try 3 times to avoid intermittent failures
    for (my $i = 0; $i < 3; $i++) {
	my $smtp = Hebcal::SMTP->new($s,
				       Hello => $HOSTNAME,
				       Port => 465,
				       Timeout => 20,
				       Debug => $debug);
	if ($smtp) {
	    $smtp->auth($user, $password)
		or carp "Can't authenticate as $user\n" . $smtp->debug_txt();
	    return $smtp;
	} else {
	    my $sec = 5;
	    carp "Could not connect to $s, retry in $sec seconds";
	    sleep($sec);
	}
    }
    
    undef;
}

sub my_sendmail
{
    my($smtp,$return_path,$headers,$body) = @_;
    
    $headers->{"X-Sender"} = "$LOGIN\@$HOSTNAME";
    $headers->{"X-Mailer"} = "hebcal mail v$VERSION";

    my $message = "";
    while (my($key,$val) = each %{$headers})
    {
	while (chomp($val)) {}
	$message .= "$key: $val\n";
    }
    $message .= "\n" . $body;

    my $to = $headers->{"To"};
    my $rv = $smtp->mail($return_path);
    unless ($rv) {
	carp "smtp mail() failure for $to\n" . $smtp->debug_txt();
	return 0;
    }

    $rv = $smtp->to($to);
    unless ($rv) {
	carp "smtp to() failure for $to\n" . $smtp->debug_txt();
	return 0;
    }

    $rv = $smtp->data();
    $rv = $smtp->datasend($message);
    $rv = $smtp->dataend();
    unless ($rv) {
	carp "smtp dataend() failure for $to\n" . $smtp->debug_txt();
	return 0;
    }

    1;
}

sub usage {
    die "usage: $0 {-all | address ...}\n";
}

