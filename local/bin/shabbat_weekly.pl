#!/usr/bin/perl -w

########################################################################
#
# Copyright (c) 2013  Michael J. Radwin.
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
use Carp;
use Log::Log4perl qw(:easy);
use Config::Tiny;
use MIME::Lite;
use Date::Calc;
use HebcalGPL ();
use URI::Escape;
use Time::HiRes qw(usleep);
use Fcntl qw(:flock);

my $opt_all = 0;
my $opt_dryrun = 0;
my $opt_help;
my $opt_verbose = 0;
my $opt_sleeptime = 300_000; 	# 300 milliseconds
my $opt_log = 1;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "all" => \$opt_all,
     "dryrun|n" => \$opt_dryrun,
     "sleeptime=i" => \$opt_sleeptime,
     "log!" => \$opt_log,
     "verbose|v+" => \$opt_verbose)) {
    usage();
}

$opt_help && usage();
usage() if !@ARGV && !$opt_all;
$opt_log = 0 if $opt_dryrun;
$opt_sleeptime = 0 if $opt_dryrun;

my $loglevel;
if ($opt_verbose == 0) {
    $loglevel = $WARN;
} elsif ($opt_verbose == 1) {
    $loglevel = $INFO;
} else {
    $loglevel = $DEBUG;
}
# Just log to STDERR
Log::Log4perl->easy_init($loglevel);

open(my $lockfile, ">", "/tmp/hebcal-shabbat-weekly.lock")
    or LOGDIE("Can't open lockfile: $!");

if (!flock($lockfile, LOCK_EX)) {
    WARN("Unable to acquire lock: $!");
    exit(1);
}

# don't send email on yontiff
exit_if_yomtov();

INFO("Reading $Hebcal::CONFIG_INI_PATH");
my $Config = Config::Tiny->read($Hebcal::CONFIG_INI_PATH)
    or LOGDIE "$Hebcal::CONFIG_INI_PATH: $!";

my %SUBS;
INFO("Querying database to get subscriber info");
load_subs();
if (! keys(%SUBS) && !$opt_all) {
    LOGCROAK "$ARGV[0]: not found";
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
my $UTM_PARAM = sprintf("utm_source=newsletter&amp;utm_campaign=shabbat-%04d-%02d-%02d",
			$year, $mon+1, $mday);

my $HOME = "/home/hebcal";
lfINFO("Opening ZIP code database");
my $ZIPS_DBH = Hebcal::zipcode_open_db();

my $STATUS_OK = 1;
my $STATUS_TRY_LATER = 2;
my $STATUS_FAIL_AND_CONTINUE = 3;

if ($opt_log) {
    my $logfile = sprintf("%s/local/var/log/shabbat-%04d%02d%02d",
			  $HOME, $year, $mon+1, $mday);
    if ($opt_all) {
	if (open(LOG, "<$logfile")) {
	    INFO("Scanning $logfile");
	    my $count = 0;
	    while(<LOG>) {
		my($msgid,$status,$to,$loc) = split(/:/);
		if ($status && defined $to && defined $SUBS{$to}) {
		    delete $SUBS{$to};
		    $count++;
		}
	    }
	    close(LOG);
	    INFO("Skipping $count users from previous run");
	}
    }
    open(LOG, ">>$logfile") || LOGCROAK "$logfile: $!";
    select LOG;
    $| = 1;
    select STDOUT;
}

parse_all_configs();

my $HOSTNAME = `/bin/hostname -f`;
chomp($HOSTNAME);

my @SMTP;
my @SMTP_AUTH;
my $SMTP_NUM_CONNECTIONS;
my %CONFIG;
my %ZIP_CACHE;
mail_all();

close(LOG) if $opt_log;

flock($lockfile, LOCK_UN);		# ignore failures

Hebcal::zipcode_close_db($ZIPS_DBH);

INFO("Success!");
exit(0);

sub open_smtp_connections {
    if ($Config->{_}->{"hebcal.email.shabbat.alt.enabled"}) {
	@SMTP_AUTH = ();
	for (my $i = 1; $i <= 4; $i++) {
	    push(@SMTP_AUTH, [$Config->{_}->{"hebcal.email.shabbat.alt.host"},
			      $Config->{_}->{"hebcal.email.shabbat.alt.u$i"},
			      $Config->{_}->{"hebcal.email.shabbat.alt.p$i"}]);
	}
    } else {
	@SMTP_AUTH = (
	     [$Config->{_}->{"hebcal.email.shabbat.host"},
	      $Config->{_}->{"hebcal.email.shabbat.user"},
	      $Config->{_}->{"hebcal.email.shabbat.password"}],
	    );
    }
    $SMTP_NUM_CONNECTIONS = scalar(@SMTP_AUTH);
    INFO("Opening $SMTP_NUM_CONNECTIONS SMTP connections");
    for (my $i = 0; $i < $SMTP_NUM_CONNECTIONS; $i++) {
	$SMTP[$i] = undef;
	smtp_reconnect($i, 1);
    }
    INFO("SMTP connections open; will sleep for $opt_sleeptime usec between messages");
}

sub close_smtp_connections {
    INFO("Closing $SMTP_NUM_CONNECTIONS SMTP connections");
    foreach my $smtp (@SMTP) {
	$smtp->quit();
    }
}

sub exit_if_yomtov {
    my $subj = Hebcal::get_today_yomtov();
    if ($subj) {
	WARN("Today is yomtov: $subj");
	exit(0);
    }
    1;
}

sub parse_all_configs {
    INFO("Parsing all configs");
    while(my($to,$cfg) = each(%SUBS)) {
	my($cmd,$loc,$args) = parse_config($cfg);
	$CONFIG{$to} = [$cmd,$loc,$args];
    }
}

sub mail_all {
    my $MAX_FAILURES = 100;
    my $RECONNECT_INTERVAL = 50;
    my $failures = 0;
    for (my $attempts = 0; $attempts < 3; $attempts++) {
	my @addrs = keys %SUBS;
	my $count =  scalar(@addrs);
	last if $count == 0;
	# sort the addresses by timezone so we mail eastern users first
	INFO("Sorting $count users by lat/long");
	@addrs = sort by_timezone @addrs;
	open_smtp_connections();
	INFO("About to mail $count users");
	for (my $i = 0; $i < $count; $i++) {
	    my $to = $addrs[$i];
	    my $server_num = $i % $SMTP_NUM_CONNECTIONS;
	    if ($i % 200 == 0) {
		my($cmd,$loc,$args) = @{$CONFIG{$to}};
		INFO("Sending mail #$i/$count ($loc)");
	    }
	    my $status = mail_user($to, $SMTP[$server_num]);
	    if ($status == $STATUS_FAIL_AND_CONTINUE) {
		# count this as a real failure but don't try the address again
		WARN("Failure on mail #$i/$count ($to), won't try this address again");
		delete $SUBS{$to};
		++$failures;
	    } elsif ($status == $STATUS_OK) {
		delete $SUBS{$to};
		# reconnect every so often
		if (($i % $RECONNECT_INTERVAL) == ($RECONNECT_INTERVAL - 1)) {
		    smtp_reconnect($server_num, 1);
		}
	    } else {
		WARN("Failure on mail #$i/$count ($to), reconnecting...");
		if (++$failures >= $MAX_FAILURES) {
		    ERROR("Got $failures failures, giving up");
		    return;
		}
		# reconnect to see if this helps
		smtp_reconnect($server_num, 1);
	    }
	    usleep($opt_sleeptime) unless $opt_sleeptime == 0 || $i == ($count - 1);
	}
	INFO("Sent $count messages, $failures failures");
	close_smtp_connections();
    }
}

sub get_latlong {
    my($id) = @_;
    my $args = $CONFIG{$id}->[2];
    if (defined $args->{"zip"}) {
	my($city,$state,$tzid,$latitude,$longitude,
	   $lat_deg,$lat_min,$long_deg,$long_min) =
	    get_zipinfo($args->{"zip"});
	if ($opt_verbose > 2) {
	  DEBUG("zip=" . $args->{"zip"} . ",lat=$latitude,long=$longitude");
	}
	return ($latitude, $longitude, $city);
    } else {
	my($latitude,$longitude) = @{$Hebcal::CITY_LATLONG{$args->{"city"}}};
	if ($opt_verbose > 2) {
	    DEBUG("city=" . $args->{"city"} . ",lat=$latitude,long=$longitude");
	}
	return ($latitude, $longitude, $args->{"city"});
    }
}

sub by_timezone {
    my($lat_a,$long_a,$city_a) = get_latlong($a);
    my($lat_b,$long_b,$city_b) = get_latlong($b);
    if ($long_a == $long_b) {
	if ($lat_a == $lat_b) {
	    return $city_a cmp $city_b;
	} else {
	    return $lat_a <=> $lat_b;
	}
    } else {
	return $long_b <=> $long_a;
    }
}

sub mail_user
{
    my($to,$smtp) = @_;

    my $cfg = $SUBS{$to} or LOGCROAK "invalid user $to";

    my($cmd,$loc,$args) = @{$CONFIG{$to}};
    return 1 unless $cmd;

    DEBUG("to=$to   cmd=$cmd");

    my @events = Hebcal::invoke_hebcal("$cmd $sat_year","",undef);
    if ($sat_year != $year) {
	# Happens when Friday is Dec 31st and Sat is Jan 1st
	my @ev2 = Hebcal::invoke_hebcal("$cmd $year","",undef);
	@events = (@ev2, @events);
    }

    my $encoded = MIME::Base64::encode_base64($to);
    chomp($encoded);
    my $unsub_url = "http://www.hebcal.com/email/?" .
	"e=" . URI::Escape::uri_escape_utf8($encoded);

    my $html_body = "";

    my $loc_short = $loc;
    $loc_short =~ s/,.+$//;

    # for the last two weeks of Av and the last week or two of Elul
    my @today = Date::Calc::Today();
    my $hebdate = HebcalGPL::greg2hebrew($today[0], $today[1], $today[2]);
    if (($hebdate->{"mm"} == $HebcalGPL::AV && $hebdate->{"dd"} >= 15)
	|| ($hebdate->{"mm"} == $HebcalGPL::ELUL && $hebdate->{"dd"} >= 20)) {
	my $next_year = $hebdate->{"yy"} + 1;
	my $fridge_loc = defined $args->{"zip"} 
	    ? "zip=" . $args->{"zip"}
	    : "city=" . URI::Escape::uri_escape_utf8($args->{"city"});

	my $erev_rh = day_before_rosh_hashana($hebdate->{"yy"} + 1);
	my $dow = $Hebcal::DoW[Hebcal::get_dow($erev_rh->{"yy"},
					       $erev_rh->{"mm"},
					       $erev_rh->{"dd"})];
	my $when = sprintf("%s, %s %d",
			   $dow,
			   $Hebcal::MoY_long{$erev_rh->{"mm"}},
			   $erev_rh->{"dd"});

	$html_body .= qq{<div style="font-size:14px;font-family:arial,helvetica,sans-serif;padding:8px;color:#468847;background-color:#dff0d8;border-color:#d6e9c6;border-radius:4px">\n};
	$html_body .= qq{Rosh Hashana begins at sundown on $when. Print your }
	    . qq{<a style="color:#356635" href="http://www.hebcal.com/shabbat/fridge.cgi?$fridge_loc&amp;year=$next_year&amp;$UTM_PARAM">}
	    . qq{$loc_short virtual refrigerator magnet</a> for candle lighting times and }
	    . qq{Parashat haShavuah on a compact 5x7 page.\n</div>\n}
	    . qq{<div>&nbsp;</div>\n};
    }

    # begin the HTML for the events - main body
    $html_body .= qq{<div style="font-size:18px;font-family:georgia,'times new roman',times,serif;">\n};

    my($subject,$body,$html_body_events) =
	gen_subject_and_body(\@events,$loc_short);

    $html_body .= $html_body_events;

    $body .= qq{
These times are for $loc.

Shabbat Shalom,
hebcal.com

To modify your subscription or to unsubscribe completely, visit:
$unsub_url
};

    $html_body .= qq{<div style="font-size:16px">
<div>These times are for $loc.</div>
<div>&nbsp;</div>
<div>Shabbat Shalom!</div>
<div>&nbsp;</div>
</div>
</div>
<div style="font-size:11px;color:#999;font-family:arial,helvetica,sans-serif">
<div>This email was sent to $to by <a href="http://www.hebcal.com/?$UTM_PARAM">Hebcal.com</a></div>
<div>&nbsp;</div>
<div><a href="$unsub_url&amp;unsubscribe=1&amp;$UTM_PARAM">Unsubscribe</a> | <a href="$unsub_url&amp;modify=1&amp;$UTM_PARAM">Update Settings</a> | <a href="http://www.hebcal.com/home/about/privacy-policy?$UTM_PARAM">Privacy Policy</a></div>
</div>
};

    my $email_mangle = $to;
    $email_mangle =~ s/\@/=/g;
    my $return_path = sprintf('shabbat-return-%s@hebcal.com', $email_mangle);

    my $msgid = $args->{"id"} . "." . time();

    my %headers =
	(
	 "From" => "Hebcal <shabbat-owner\@hebcal.com>",
	 "To" => $to,
	 "Reply-To" => "no-reply\@hebcal.com",
	 "Subject" => $subject,
	 "List-Unsubscribe" => "<$unsub_url&unsubscribe=1>",
	 "List-Id" => "<shabbat.hebcal.com>",
	 "Errors-To" => $return_path,
#	 "Precedence" => "bulk",
	 "Message-ID" => "<$msgid\@hebcal.com>",
	 );

    return $STATUS_OK if $opt_dryrun;

    my $status = my_sendmail($smtp,$return_path,\%headers,$body,$html_body);
    if ($opt_log) {
	my $log_status = ($status == $STATUS_OK) ? 1 : 0;
	print LOG join(":", $msgid, $log_status, $to,
		       defined $args->{"zip"} 
		       ? $args->{"zip"} : $args->{"city"}), "\n";
    }

    $status;
}

sub day_before_rosh_hashana {
    my($hyear) = @_;

    my $abs = HebcalGPL::hebrew2abs({ yy => $hyear,
				      mm => $HebcalGPL::TISHREI,
				      dd => 1 });
    HebcalGPL::abs2greg($abs - 1);
}

sub gen_subject_and_body {
    my($events,$city_descr_short) = @_;

    my $body = "";
    my $html_body = "";
    my $first_candles;
    my $sedra;

    my %holiday_seen;
    foreach my $evt (@{$events}) {
	# holiday is at 12:00:01 am
	my $time = Hebcal::event_to_time($evt);
	next if $time < $midnight || $time > $endofweek;

	my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
	my $strtime = strftime("%A, %B %d", localtime($time));

	if ($subj eq "Candle lighting" || $subj =~ /Havdalah/)
	{
	    my $hour_min = Hebcal::format_evt_time($evt, "pm");
	    if (! defined $first_candles && $subj eq "Candle lighting") {
		$first_candles = $hour_min;
	    }

	    $body .= sprintf("%s is at %s on %s\n",
			     $subj, $hour_min, $strtime);
	    $html_body .= sprintf("<div>%s is at <strong>%s</strong> on %s.</div>\n<div>&nbsp;</div>\n",
				  $subj, $hour_min, $strtime);
	}
	elsif ($subj eq "No sunset today.")
	{
	    my $str = "No sunset on $strtime";
	    $body      .= qq{$str\n};
	    $html_body .= qq{<div>$str.</div>\n<div>&nbsp;</div>\n};
	}
	elsif ($subj =~ /^(Parshas|Parashat)\s+(.+)$/)
	{
	    $sedra = $2;
	    my $url = "http://www.hebcal.com"
		. Hebcal::get_holiday_anchor($subj,undef,undef);
	    $body .= "This week's Torah portion is $subj\n";
	    $body .= "  $url\n";
	    $html_body .= qq{<div>This week's Torah portion is <a href="$url?$UTM_PARAM">$subj</a>.</div>\n<div>&nbsp;</div>\n};
	}
	else
	{
	    my($year,$mon,$mday) = Hebcal::event_ymd($evt);
	    my $dow = Hebcal::get_dow($year,$mon,$mday);
	    if ($dow == 6) {
		my $subj_copy = $subj;
		$subj_copy =~ s/ \(CH\'\'M\)$//;
		$subj_copy =~ s/ \(Hoshana Raba\)$//;
		$subj_copy =~ s/ [IV]+$//;
		$subj_copy =~ s/ \d{4}$//; # Rosh Hashana
		if ($HebcalConst::YOMTOV{$subj_copy} && ! defined $sedra) {
		    # Pesach, Sukkot, Shavuot, Shmini Atz, Simchat Torah, RH, YK
		    $sedra = $subj_copy;
		}
	    }

	    $body .= "$subj occurs on $strtime\n";
	    my $hanchor = Hebcal::get_holiday_anchor($subj,undef,undef);
	    my $url = "http://www.hebcal.com" . $hanchor;
	    if ($hanchor && !$holiday_seen{$hanchor}) {
		$body .= "  $url\n";
		$holiday_seen{$hanchor} = 1;
	    }
	    $html_body .= qq{<div><a href="$url?$UTM_PARAM">$subj</a> occurs on $strtime.</div>\n<div>&nbsp;</div>\n};
	}
    }

    my $subject = "[shabbat]";
    $subject .= " $sedra -" if $sedra;
    $subject .= " $city_descr_short";
    $subject .= " candles $first_candles" if $first_candles;

    return ($subject,$body,$html_body);
}

sub load_subs
{
    my $dbhost = $Config->{_}->{"hebcal.mysql.host"};
    my $dbuser = $Config->{_}->{"hebcal.mysql.user"};
    my $dbpass = $Config->{_}->{"hebcal.mysql.password"};
    my $dbname = $Config->{_}->{"hebcal.mysql.dbname"};
    my $dsn = "DBI:mysql:database=$dbname;host=$dbhost";
    DEBUG("Connecting to $dsn");
    my $dbh = DBI->connect($dsn, $dbuser, $dbpass)
	or LOGDIE("DB Connection not made: $DBI::errstr");
    $dbh->{'mysql_enable_utf8'} = 1;

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

    INFO($sql);
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or LOGCROAK "can't execute the query: " . $sth->errstr;
    my $count = 0;
    while (my($email,$id,$zip,$city,$havdalah) = $sth->fetchrow_array) {
	my $cfg = "id=$id;m=$havdalah";
	if ($zip) {
	    $cfg .= ";zip=$zip";
	} elsif ($city) {
	    if (defined($Hebcal::CITIES_OLD{$city})) {
		$city = $Hebcal::CITIES_OLD{$city};
	    } elsif (! defined $Hebcal::CITY_LATLONG{$city}) {
		LOGCROAK "unknown city $city for id=$id;email=$email";
	    }
	    $cfg .= ";city=$city";
	}
	$SUBS{$email} = $cfg;
	$count++;
    }

    $dbh->disconnect;

    INFO("Loaded $count users");
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

    if ($opt_verbose > 3) {
	DEBUG("cfg=$config");
    }

    my %args;
    foreach my $kv (split(/;/, $config)) {
	my($key,$val) = split(/=/, $kv, 2);
	$args{$key} = $val;
    }

    my $city_descr;
    if (defined $args{"zip"}) {
	my($city,$state,$tzid,$latitude,$longitude,
	   $lat_deg,$lat_min,$long_deg,$long_min) = get_zipinfo($args{"zip"});
	unless (defined $state) {
	    WARN("unknown zipcode [$config]");
	    return undef;
	}
	$cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";

	$city_descr = "$city, $state " . $args{"zip"};
    } elsif (defined $args{"city"}) {
	my $city = $args{"city"};
	$city =~ s/\+/ /g;
	if ($city eq "Jerusalem" || $city eq "IL-Jerusalem") {
	    $cmd .= " -C 'Jerusalem'";
	} else {
	    if (! defined $Hebcal::CITY_LATLONG{$city}) {
		WARN("unknown city [$config]");
		return undef;
	    }
	    my($latitude,$longitude) = @{$Hebcal::CITY_LATLONG{$city}};
	    my($lat_deg,$lat_min,$long_deg,$long_min) =
		Hebcal::latlong_to_hebcal($latitude, $longitude);

	    my $tzid = $Hebcal::CITY_TZID{$city};
	    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min -z '$tzid'";
	}

	$cmd .= " -i" if $Hebcal::CITY_COUNTRY{$city} eq "IL";

	my $country = Hebcal::woe_country($city);
	$country = "USA" if $country eq "United States of America";
	$city_descr = Hebcal::woe_city($city) . ", $country";
    } else {
	ERROR("no geographic key in [$config]");
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

    LOGCROAK "server number $server_num too large"
	if $server_num >= $SMTP_NUM_CONNECTIONS;

    if (defined $SMTP[$server_num]) {
	$SMTP[$server_num]->quit();
	$SMTP[$server_num] = undef;
    }
    my $host = $SMTP_AUTH[$server_num]->[0];
    my $user = $SMTP_AUTH[$server_num]->[1];
    my $password = $SMTP_AUTH[$server_num]->[2];
    my $smtp = smtp_connect($host, $user, $password, $debug)
	or LOGCROAK "Can't connect to $host as $user";
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
		or WARN("Can't authenticate as $user\n" . $smtp->debug_txt());
	    return $smtp;
	} else {
	    my $sec = 5;
	    WARN("Could not connect to $s, retry in $sec seconds");
	    sleep($sec);
	}
    }
    
    undef;
}

sub my_sendmail
{
    my($smtp,$return_path,$headers,$body,$html_body) = @_;

    my $msg = MIME::Lite->new(Type => 'multipart/alternative');
    while (my($key,$val) = each %{$headers}) {
	while (chomp($val)) {}
	$msg->add($key => $val);
    }
    $msg->add("X-Sender" => "$LOGIN\@$HOSTNAME");
    $msg->replace("X-Mailer" => "hebcal mail");

    my $part = MIME::Lite->new(Top  => 0,
			       Type => "text/plain",
			       Data => $body);
    $part->attr("content-type.charset" => "UTF-8");
    $msg->attach($part);

    my $part2 = MIME::Lite->new(Top  => 0,
				Type => "text/html",
				Data => "<!DOCTYPE html><html><head><title>Hebcal Shabbat Times</title></head>\n" .
				qq{<body>$html_body</body></html>\n}
			       );
    $part2->attr("content-type.charset" => "UTF-8");
    $msg->attach($part2);


    my $to = $headers->{"To"};
    my $rv = $smtp->mail($return_path);
    unless ($rv) {
	WARN("smtp mail() failure for $to\n" . $smtp->debug_txt());
	return $STATUS_TRY_LATER;
    }

    $rv = $smtp->to($to);
    unless ($rv) {
	WARN("smtp to() failure for $to\n" . $smtp->debug_txt());
	return $STATUS_TRY_LATER;
    }

    $rv = $smtp->data();
    $rv = $smtp->datasend($msg->as_string);
    $rv = $smtp->dataend();
    unless ($rv) {
	my $debug_txt = $smtp->debug_txt();
	if ($debug_txt =~ /<<< 554 Message rejected: Address blacklisted/) {
	    INFO("$to 554 Message rejected: Address blacklisted\n");
	    return $STATUS_FAIL_AND_CONTINUE;
	}
	WARN("smtp dataend() failure for $to\n" . $debug_txt);
	return $STATUS_TRY_LATER;
    }

    $STATUS_OK;
}

sub usage {
    die "usage: $0 {-all | address ...}\n";
}
