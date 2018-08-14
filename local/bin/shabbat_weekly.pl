#!/usr/bin/perl -w

########################################################################
#
# Copyright (c) 2018  Michael J. Radwin.
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
use utf8;
use Hebcal ();
use POSIX qw(strftime);
use MIME::Base64 ();
use Time::Local ();
use DBI ();
use Getopt::Long ();
use Carp;
use Log::Log4perl qw(:easy);
use Config::Tiny;
use MIME::Lite;
use Encode qw/encode decode/;
use Date::Calc;
use HebcalGPL ();
use URI::Escape;
use Time::HiRes qw(usleep);
use Fcntl qw(:flock);

my $opt_all = 0;
my $opt_dryrun = 0;
my $opt_help;
my $opt_verbose = 0;
my $opt_sleeptime = 300_000;    # 300 milliseconds
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
my $UTM_PARAM = sprintf("utm_source=newsletter&amp;utm_medium=email&amp;utm_campaign=shabbat-%04d-%02d-%02d",
                        $year, $mon+1, $mday);

my $HOME = "/home/hebcal";
INFO("Opening ZIP code database");
my $ZIPS_DBH = Hebcal::zipcode_open_db();
INFO("Opening Geonames database");
my $GEONAME_SQLITE_FILE = "$Hebcal::WEBDIR/hebcal/geonames.sqlite3";
my $GEONAME_DBH = Hebcal::zipcode_open_db($GEONAME_SQLITE_FILE);
$GEONAME_DBH->{sqlite_unicode} = 1;

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

my %ZIP_CACHE;

# default config for MIME::Lite
MIME::Lite->send("smtp", "localhost", Timeout=>10);

mail_all();

close(LOG) if $opt_log;

flock($lockfile, LOCK_UN);              # ignore failures

Hebcal::zipcode_close_db($ZIPS_DBH);
Hebcal::zipcode_close_db($GEONAME_DBH);

INFO("Success!");
exit(0);

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
        my $status = parse_config($to,$cfg);
        delete $SUBS{$to} unless $status;
    }
}

sub mail_all {
    my $MAX_FAILURES = 100;
    my $failures = 0;
    for (my $attempts = 0; $attempts < 3; $attempts++) {
        my @addrs = keys %SUBS;
        my $count =  scalar(@addrs);
        last if $count == 0;
        # sort the addresses by timezone so we mail eastern users first
        INFO("Sorting $count users by lat/long");
        @addrs = sort by_timezone @addrs;
        INFO("About to mail $count users");
        for (my $i = 0; $i < $count; $i++) {
            my $to = $addrs[$i];
            if (($i % 200 == 0) || ($i + 1 == $count)) {
                my $cfg = $SUBS{$to};
                my $loc = $cfg->{loc};
                INFO("Sending mail #" . ($i + 1) . "/$count ($loc)");
            }
            my $status = mail_user($to);
            if ($status == $STATUS_FAIL_AND_CONTINUE) {
                # count this as a real failure but don't try the address again
                WARN("Failure on mail #$i/$count ($to), won't try this address again");
                delete $SUBS{$to};
                ++$failures;
            } elsif ($status == $STATUS_OK) {
                delete $SUBS{$to};
            } else {
                WARN("Failure on mail #$i/$count ($to)");
                if (++$failures >= $MAX_FAILURES) {
                    ERROR("Got $failures failures, giving up");
                    return;
                }
            }
            usleep($opt_sleeptime) unless $opt_sleeptime == 0 || $i == ($count - 1);
        }
        INFO("Sent $count messages, $failures failures");
    }
}

sub get_latlong {
    my($to) = @_;
    my $cfg = $SUBS{$to} or LOGCROAK "invalid user $to";
    my $latitude = $cfg->{latitude};
    my $longitude = $cfg->{longitude};
    my $loc = $cfg->{loc};
    if ($opt_verbose > 2) {
        DEBUG("to=$to,loc=$loc,lat=$latitude,long=$longitude");
    }
    ($latitude,$longitude,$loc);
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

sub special_note {
    my($cfg) = @_;

    my $special_message = "";

    # for the last two weeks of Av and the last week or two of Elul
    my @today = Date::Calc::Today();
    my $hebdate = HebcalGPL::greg2hebrew($today[0], $today[1], $today[2]);
    if (($hebdate->{"mm"} == $HebcalGPL::AV && $hebdate->{"dd"} >= 15)
        || ($hebdate->{"mm"} == $HebcalGPL::ELUL && $hebdate->{"dd"} >= 16)) {

        my $loc = $cfg->{loc};
        my $loc_short = $loc;
        $loc_short =~ s/,.+$//;

        my $next_year = $hebdate->{"yy"} + 1;
        my $fridge_loc = defined $cfg->{zip} ? "zip=" . $cfg->{zip}
            : defined $cfg->{geonameid} ? "geonameid=" . $cfg->{geonameid}
            : "city=" . URI::Escape::uri_escape_utf8($cfg->{"city"});

        my $erev_rh = day_before_rosh_hashana($hebdate->{"yy"} + 1);
        my $dow = $Hebcal::DoW[Hebcal::get_dow($erev_rh->{"yy"},
                                               $erev_rh->{"mm"},
                                               $erev_rh->{"dd"})];
        my $when = sprintf("%s, %s %d",
                           $dow,
                           $Hebcal::MoY_long{$erev_rh->{"mm"}},
                           $erev_rh->{"dd"});

        my $url = "http://www.hebcal.com/shabbat/fridge.cgi?$fridge_loc&amp;year=$next_year";
        $url .= "&amp;m=" . $cfg->{m}
            if defined $cfg->{m} && $cfg->{m} =~ /^\d+$/;
        $url .= "&amp;$UTM_PARAM";

        $special_message = qq{Rosh Hashana begins at sundown on $when. Print your }
            . qq{<a style="color:#356635" href="$url">}
            . qq{$loc_short virtual refrigerator magnet</a> for candle lighting times and }
            . qq{Parashat haShavuah on a compact 5x7 page.};
    } elsif ($hebdate->{"mm"} == $HebcalGPL::NISAN &&
             $hebdate->{"dd"} >= 4 &&
             $hebdate->{"dd"} <= 13) {
        $special_message = qq{Chag Pesach Sameach! Count the Omer this year with }
            . qq{<a style="color:#356635" href="https://www.hebcal.com/home/1380/hebcal-voice-amazon-echo-alexa?$UTM_PARAM">}
            . qq{Hebcal by voice on the Amazon Echo/Alexa</a>. Enable the Hebcal skill in your Alexa app }
            . qq{and then say, "Alexa, ask Hebcal for the Omer count."};
    }

    if ($special_message) {
        my $html_begin = qq{<div style="font-size:14px;font-family:arial,helvetica,sans-serif;padding:8px;color:#468847;background-color:#dff0d8;border-color:#d6e9c6;border-radius:4px">\n};
        my $html_end   = qq{\n</div>\n<div>&nbsp;</div>\n};
        $special_message = $html_begin . $special_message . $html_end;
    }

    return $special_message;
}

sub mail_user
{
    my($to) = @_;

    my $cfg = $SUBS{$to} or LOGCROAK "invalid user $to";

    my $cmd = $cfg->{cmd};
    my $loc = $cfg->{loc};
    return 1 unless $cmd;

    DEBUG("to=$to   cmd=$cmd");

    my @events = Hebcal::invoke_hebcal_v2("$cmd $sat_year","",undef);
    if ($sat_year != $year) {
        # Happens when Friday is Dec 31st and Sat is Jan 1st
        my @ev2 = Hebcal::invoke_hebcal_v2("$cmd $year","",undef);
        @events = (@ev2, @events);
    }

    my $encoded = MIME::Base64::encode_base64($to);
    chomp($encoded);
    my $unsub_url = "https://www.hebcal.com/email/?" .
        "e=" . URI::Escape::uri_escape_utf8($encoded);

    my $html_body = "";

    my $loc_short = $loc;
    $loc_short =~ s/,.+$//;

    $html_body .= special_note($cfg);

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

    my $return_path = Hebcal::shabbat_return_path($to);

    my $msgid = $cfg->{"id"} . "." . time();
    my $unsub_addr = "shabbat-unsubscribe+" . $cfg->{"id"} . "\@hebcal.com";

    my $subj_mime = $subject eq utf8::decode($subject)
        ? $subject : encode('MIME-Q', $subject);
    my %headers =
        (
         "From" => "Hebcal <shabbat-owner\@hebcal.com>",
         "To" => $to,
         "Reply-To" => "no-reply\@hebcal.com",
         "Subject" => $subj_mime,
         "List-Unsubscribe" => "<mailto:$unsub_addr>",
         "List-Id" => "<shabbat.hebcal.com>",
         "Errors-To" => $return_path,
#        "Precedence" => "bulk",
         "Message-ID" => "<$msgid\@hebcal.com>",
         );

    return $STATUS_OK if $opt_dryrun;

    my $status = my_sendmail($return_path,\%headers,$body,$html_body);
    if ($opt_log) {
        my $log_status = ($status == $STATUS_OK) ? 1 : 0;
        my $log_loc = $cfg->{zip} || $cfg->{geonameid} || $cfg->{city};
        print LOG join(":", $msgid, $log_status, $to, $log_loc), "\n";
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
        next if $time < $midnight;
        last if $time > $endofweek;

        my $subj = $evt->{subj};
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
            my $url = $evt->{href};
            $body .= "This week's Torah portion is $subj\n";
            $body .= "  $url\n";
            $html_body .= qq{<div>This week's Torah portion is <a href="$url?$UTM_PARAM">$subj</a>.</div>\n<div>&nbsp;</div>\n};
        }
        else
        {
            my($year,$mon,$mday) = Hebcal::event_ymd($evt);
            my $dow = Hebcal::get_dow($year,$mon,$mday);
            if ($dow == 6 && ! defined $sedra && $subj !~ /^Erev /) {
                my $subj_copy = Hebcal::get_holiday_basename($subj);
                if ($HebcalConst::YOMTOV{$subj_copy}) {
                    # Pesach, Sukkot, Shavuot, Shmini Atz, Simchat Torah, RH, YK
                    $sedra = $subj_copy;
                }
            }

            $body .= "$subj occurs on $strtime\n";
            my $url = $evt->{href};
            if ($url && !$holiday_seen{$url}) {
                $body .= "  $url\n";
                $holiday_seen{$url} = 1;
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
       email_candles_geonameid,
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
    while (my($email,$id,$zip,$city,$geonameid,$havdalah) = $sth->fetchrow_array) {
        my $cfg = {
            id => $id,
            m => $havdalah,
        };
        if ($zip) {
            $cfg->{zip} = $zip;
        } elsif ($geonameid) {
            $cfg->{geonameid} = $geonameid;
        } elsif ($city) {
            $city =~ s/\+/ /g;
            $city = Hebcal::validate_city($city);
            my $geonameid2 = $HebcalConst::CITIES2{$city};
            if (! defined $geonameid2) {
                WARN("unknown city $city for id=$id;email=$email");
            }
            $cfg->{geonameid} = $geonameid2;
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
        my @f = Hebcal::zipcode_get_v2_zip($ZIPS_DBH, $zip);
        $ZIP_CACHE{$zip} = \@f;
        return @f;
    }
}

sub parse_config {
    my($to,$cfg) = @_;

    my $city_descr;
    my $is_jerusalem = 0;
    my $is_israel = 0;
    my($latitude,$longitude,$tzid);
    if (defined $cfg->{zip}) {
        my($CityMixedCase,$State,$Latitude,$Longitude,$TimeZone,$DayLightSaving) = get_zipinfo($cfg->{zip});
        unless (defined $State) {
            WARN("unknown zipcode=$cfg->{zip} for to=$to, id=$cfg->{id}");
            return undef;
        }
        $latitude = $Latitude;
        $longitude = $Longitude;
        $tzid = Hebcal::get_usa_tzid($State,$TimeZone,$DayLightSaving);
        $city_descr = "$CityMixedCase, $State " . $cfg->{zip};
    } elsif (defined $cfg->{geonameid}) {
        my $sql = qq{
SELECT g.name, g.asciiname, c.country, a.name, g.latitude, g.longitude, g.timezone
FROM geoname g
LEFT JOIN country c on g.country = c.iso
LEFT JOIN admin1 a on g.country||'.'||g.admin1 = a.key
WHERE g.geonameid = ?
};
        my $sth = $GEONAME_DBH->prepare($sql)
            or die $GEONAME_DBH->errstr;
        $sth->execute($cfg->{geonameid})
            or die $GEONAME_DBH->errstr;
        my($name,$asciiname,$country,$admin1);
        ($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) = $sth->fetchrow_array;
        $sth->finish;
        unless (defined $asciiname) {
            WARN("unknown geonameid=$cfg->{geonameid} for to=$to, id=$cfg->{id}");
            return undef;
        }
        $city_descr = Hebcal::geoname_city_descr($asciiname,$admin1,$country);
        $is_israel = 1 if $country eq "Israel";
        $is_jerusalem = 1 if $is_israel && $admin1 && (index($admin1, "Jerusalem") == 0 || index($name, "Jerusalem") == 0);
    } else {
        ERROR("no geographic key in config for to=$to, id=$cfg->{id}");
        return undef;
    }

    if (! defined $latitude || ! defined $longitude || $latitude eq "" || $longitude eq "") {
        WARN("Undefined lat/long for to=$to, id=$cfg->{id}");
        return undef;
    } elsif ($latitude eq "0" && $longitude eq "0") {
        WARN("Suspicious zero lat/long for to=$to, id=$cfg->{id}");
        return undef;
    }
    WARN("Unknown tzid for to=$to, id=$cfg->{id}")
        unless defined $tzid;

    my $cmd = $Hebcal::HEBCAL_BIN;
    $cmd .= Hebcal::cmd_latlong($latitude,$longitude,$tzid);
    $cmd .= " -b 40" if $is_jerusalem;

    $cmd .= " -i" if $is_israel;

    $cmd .= " -m " . $cfg->{m}
        if (defined $cfg->{m} && $cfg->{m} =~ /^\d+$/);

    $cmd .= " -s -c";

    $cfg->{latitude} = $latitude;
    $cfg->{longitude} = $longitude;
    $cfg->{cmd} = $cmd;
    $cfg->{loc} = $city_descr;

    1;
}

sub my_sendmail
{
    my($return_path,$headers,$body,$html_body) = @_;

    my $msg = MIME::Lite->new(Type => 'multipart/alternative');
    while (my($key,$val) = each %{$headers}) {
        while (chomp($val)) {}
        $msg->add($key => $val);
    }
    $msg->replace("X-Mailer" => "hebcal mail");
    $msg->replace("Return-Path" => $return_path);

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

    eval { $msg->send; };
    if ($@) {
        WARN($@);
        return $STATUS_TRY_LATER;
    } else {
        return $STATUS_OK;
    }
}

sub usage {
    die "usage: $0 {-all | address ...}\n";
}
