#!/usr/local/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2006  Michael J. Radwin.
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
use Net::SMTP ();
use Getopt::Long ();

my $VERSION = '$Revision$$';
if ($VERSION =~ /(\d+)\.(\d+)/) {
    $VERSION = "$1.$2";
}

my $opt_all = 0;
my $opt_help;
my $opt_verbose = 0;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "all" => \$opt_all,
     "verbose|v" => \$opt_verbose)) {
    usage();
}

$opt_help && usage();
usage() if !@ARGV && !$opt_all;

my %SUBS = load_subs();
if (! keys(%SUBS) && !$opt_all) {
    die "$ARGV[0]: not found.\n";
}

my($LOGIN) = getlogin() || getpwuid($<) || "UNKNOWN";

my $now = time;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;

my $midnight = Time::Local::timelocal(0,0,0,
				      $mday,$mon,$year,$wday,$yday,$isdst);
my $saturday = $now + ((6 - $wday) * 60 * 60 * 24);
my $endofweek = $midnight + (5 * 60 * 60 * 24);
my $sat_year = (localtime($saturday))[5] + 1900;
my $subject = strftime("[shabbat] %b %d",
		       localtime($now + ((5 - $wday) * 60 * 60 * 24)));

my $ZIPS = Hebcal::zipcode_open_db("/home/hebcal/web/hebcal.com/hebcal/zips99.db");

# walk through subs to make sure there are no errors first
while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    parse_config($cfg);
}

my $logfile = sprintf("%s/local/var/log/shabbat-%04d%02d%02d",
		      "/home/hebcal", $year, $mon+1, $mday);
if ($opt_all) {
    if (open(LOG, "<$logfile")) {
	my $count;
	while(<LOG>) {
	    my($msgid,$status,$to,$loc) = split(/:/);
	    if ($status) {
		delete $SUBS{$to};
		$count++;
	    }
	}
	close(LOG);
	warn "Skipping $count users from $logfile\n" if $opt_verbose;
    }
}
open(LOG, ">>$logfile") || die "$logfile: $!";
select LOG;
$| = 1;

my $HOSTNAME = `/bin/hostname -f`;
chomp($HOSTNAME);

my $smtp = smtp_connect("mail.hebcal.com");
$smtp || die "Can't connect to SMTP server";

my $count = 0;
while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    my($cmd,$loc,$args) = parse_config($cfg);
    my @events = Hebcal::invoke_hebcal("$cmd $sat_year","",undef);
    if ($sat_year != $year) {
	# Happens when Friday is Dec 31st and Sat is Jan 1st
	my @ev2 = Hebcal::invoke_hebcal("$cmd 12 $year","",undef);
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

    # hack for pesach
    if ($sat_year == 2006 && $subject eq "[shabbat] Mar 24") {
	$body = 
"Pesach begins April 12 at sundown. If you're in search of a
Haggadah for your Seder, Hebcal.com recommends the following
traditional and liberal Haggadot:

  Family Haggadah (Artscroll Mesorah Series) by Scherkan Zlotowitz
  http://www.amazon.com/exec/obidos/ASIN/0899061788/hebcal-20
  A Different Night by David Dishon and Noam Zion
  http://www.amazon.com/exec/obidos/ASIN/0966474007/hebcal-20
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

" . $body;
    }

    if ($sat_year == 2006 && $subject eq "[shabbat] Oct 06") {
	my $geo;
	if (defined $args->{"zip"}) {
	    $geo = "zip=" . $args->{"zip"};
	} else {
	    $geo = "city=" . $args->{"city"};
	    $geo =~ s/ /%20/g;
	}

	$body = 
"It's 5767! Print out candle lighting times for the entire year
and post them on your refrigerator:
  http://www.hebcal.com/shabbat/fridge.cgi?$geo

" . $body;
    }



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
	 "Subject" => "$subject Candles $lighting",
	 "List-Unsubscribe" => "<$unsub_url&unsubscribe=1&v=1>",
	 "Errors-To" => $return_path,
	 "Precedence" => "bulk",
	 "Message-ID" => "<$msgid\@hebcal.com>",
	 );

    # hack for pesach
    if ($sat_year == 2006 && $subject eq "[shabbat] Apr 14") {
	$headers{"Subject"} = "[shabbat] Apr 12 Special Pesach Edition";
    }

    # try 3 times to avoid intermittent failures
    my $status = 0;
    for (my $i = 0; $status == 0 && $i < 3; $i++)
    {
	$status = my_sendmail($smtp,$return_path,\%headers,$body);
	sleep(1);

	if ($status == 0)
	{
	    warn "mail to $to failed, reconnecting...\n" if $opt_verbose;
	    $smtp->quit;
	    $smtp = smtp_connect("mail.hebcal.com");
	    $smtp || die "Can't reconnect to SMTP server";
	}
    }

    print LOG join(":", $msgid, $status, $to,
		   defined $args->{"zip"} 
		   ? $args->{"zip"} : $args->{"city"}), "\n";
    $count++;
}

close(LOG);
warn "Successfully mailed $count users\n" if $opt_verbose;

$smtp->quit();
undef $smtp;

Hebcal::zipcode_close_db($ZIPS);
undef($ZIPS);

exit(0);

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
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($time) = Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       "","","");
	next if $time < $midnight || $time > $endofweek;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	if ($subj eq "Candle lighting")
	{
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    $hour -= 12 if $hour > 12;

	    return sprintf("%d:%02dpm", $hour, $min);
	}
    }

    return "";
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
	my($time) = Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       "","","");
	next if $time < $midnight || $time > $endofweek;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($year) = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $strtime = strftime("%A, %d %B %Y", localtime($time));

	if ($subj eq "Candle lighting" || $subj =~ /Havdalah/)
	{
	    $body .= sprintf("%s for %s is at %d:%02dpm\n",
			     $subj, $strtime, $hour, $min);
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
	    $body .= "Holiday: $subj on $strtime\n";
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
    my(%subs);

    my $dsn = "DBI:mysql:database=hebcal1;host=mysql.hebcal.com";
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
FROM hebcal1.hebcal_shabbat_email
WHERE hebcal1.hebcal_shabbat_email.email_status = 'active'
AND hebcal1.hebcal_shabbat_email.email_ip IS NOT NULL
$all_sql
EOD
;

    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or die "can't execute the query: " . $sth->errstr;
    my $count = 0;
    while (my($email,$id,$zip,$city,$havdalah) = $sth->fetchrow_array) {
	my $cfg = "id=$id;m=$havdalah";
	if ($zip) {
	    $cfg .= ";zip=$zip";
	} elsif ($city) {
	    $cfg .= ";city=$city";
	}
	$subs{$email} = $cfg;
	$count++;
    }

    $dbh->disconnect;

    warn "Loaded $count users\n" if $opt_verbose;

    %subs;
}

sub parse_config
{
    my($config) = @_;

    my($cmd) = "/home/hebcal/web/hebcal.com/bin/hebcal";

    my %args;
    foreach my $kv (split(/;/, $config)) {
	my($key,$val) = split(/=/, $kv, 2);
	$args{$key} = $val;
    }

    my $city_descr;
    if (defined $args{"zip"}) {
	my($zipinfo) = $ZIPS->{$args{"zip"}};
	die "unknown zipcode [$config]" unless defined $zipinfo;
    
	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    Hebcal::zipcode_fields($zipinfo);

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
	die "no geographic key in [$config]";
    }

    $cmd .= " -m " . $args{"m"}
	if (defined $args{"m"} && $args{"m"} =~ /^\d+$/);

    $cmd .= " -s -c";

    ($cmd,$city_descr,\%args);
}

sub smtp_connect
{
    my($s) = @_;

    # try 3 times to avoid intermittent failures
    for (my $i = 0; $i < 3; $i++)
    {
	my $smtp = Net::SMTP->new($s, Timeout => 20);
	if ($smtp)
	{
	    $smtp->hello($HOSTNAME);
	    $smtp->auth("hebcal", "xxxxxxxx");
	    return $smtp;
	}
	else
	{
	    my $sec = 5;
	    warn "Could not connect to $s, retry in $sec seconds\n";
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
    unless ($smtp->mail($return_path)) {
        warn "smtp mail() failure for $to\n"
	    if $opt_verbose;
        return 0;
    }

    unless($smtp->to($to)) {
	warn "smtp to() failure for $to\n"
	    if $opt_verbose;
	return 0;
    }

    unless($smtp->data()) {
        warn "smtp data() failure for $to\n"
	    if $opt_verbose;
        return 0;
    }

    unless($smtp->datasend($message)) {
        warn "smtp datasend() failure for $to\n"
	    if $opt_verbose;
        return 0;
    }

    unless($smtp->dataend()) {
        warn "smtp dataend() failure for $to\n"
	    if $opt_verbose;
        return 0;
    }

    1;
}

sub usage {
    die "usage: $0 {-all | address ...}\n";
}

