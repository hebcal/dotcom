#!/usr/bin/perl -w

########################################################################
#
# Copyright (c) 2016  Michael J. Radwin.
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
use open ":utf8";
use Hebcal ();
use Date::Calc ();
use POSIX qw(strftime);
use DBI;
use Getopt::Long ();
use Log::Log4perl qw(:easy);
use File::Basename;

my $HOSTNAME = "www.hebcal.com";
my $opt_help;
my $opt_verbose = 0;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "verbose|v+" => \$opt_verbose)) {
    usage();
}

$opt_help && usage();

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

my($syear,$smonth,$sday) = Hebcal::upcoming_dow(6); # saturday
DEBUG("Shabbat is $syear-$smonth-$sday");

rss_parasha($syear,$smonth,$sday,"index",1,"en-us");
rss_parasha($syear,$smonth,$sday,"israel",0,"en-us");
rss_parasha($syear,$smonth,$sday,"israel-he",0,"he");

my $hdate = `$Hebcal::HEBCAL_BIN -T -x -h | grep -v Omer`;
chomp($hdate);
DEBUG("Today is $hdate");

if ($hdate =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
{
    my($hm,$hd,$hy) = ($2,$1,$3);
    my $hebrew = Hebcal::build_hebrew_date($hm,$hd,$hy);

    my $outfile = "$Hebcal::WEBDIR/etc/hdate-en.js";
    DEBUG("Creating $outfile");
    open(OUT,">$outfile.$$") || LOGDIE "$outfile.$$: $!";
    print OUT "document.write(\"$hdate\");\n";
    close(OUT);
    rename("$outfile.$$", $outfile) || LOGDIE "$outfile: $!\n";

    $outfile = "$Hebcal::WEBDIR/etc/hdate-he.js";
    DEBUG("Creating $outfile");
    open(OUT,">$outfile.$$") || LOGDIE "$outfile.$$: $!";
    print OUT "document.write(\"$hebrew\");\n";
    close(OUT);
    rename("$outfile.$$", $outfile) || LOGDIE "$outfile: $!\n";

    my $pubDate = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time()));

    my $hmonth = $hm;
    if ($hmonth eq "Adar I") {
	$hmonth = "Adar1";
    } elsif ($hmonth eq "Adar II") {
	$hmonth = "Adar2";
    } elsif ($hmonth eq "Adar") {
	$hmonth = "Adar1";
    }

    $hmonth =~ s/[^A-Za-z0-9]+//g;

    my $url = "https://$HOSTNAME/converter?hd=$hd&amp;hm=$hmonth&amp;hy=$hy&amp;h2g=1&amp;utm_medium=rss";
    $outfile = "$Hebcal::WEBDIR/etc/hdate-en.xml";
    DEBUG("Creating $outfile");
    open(RSS,">$outfile.$$") || LOGDIE "$outfile.$$: $!";
    print RSS rss_hebdate("en-us",
	 $hdate,
         "$url&amp;utm_source=rss-hdate-en",
	 $hdate,
	 $pubDate);
    close(RSS);
    rename("$outfile.$$", $outfile) || LOGDIE "$outfile: $!\n";

    $outfile = "$Hebcal::WEBDIR/etc/hdate-he.xml";
    DEBUG("Creating $outfile");
    open(RSS,">$outfile.$$") || LOGDIE "$outfile.$$: $!";
    print RSS rss_hebdate("he",
	 $hebrew,
         "$url&amp;utm_source=rss-hdate-he",
	 $hebrew,
	 $pubDate);
    close(RSS);
    rename("$outfile.$$", $outfile) || LOGDIE "$outfile: $!\n";
}
exit(0);

sub rss_parasha {
    my($syear,$smonth,$sday,$basename,$diaspora,$lang) = @_;

    my $cmd = "$Hebcal::HEBCAL_BIN -s -h -x";
    $cmd .= " -i" unless $diaspora;
    $cmd .= " $syear";

    my $title = "Hebcal Parashat ha-Shavua";
    my $description = "Torah reading of the week from Hebcal.com";
    if ($diaspora) {
	$title .= " (Diaspora)";
	$description .= " (Diaspora)";
    } else {
	$title .= " (Israel)";
	$description .= " (Israel)";
    }

    if ($lang eq "he") {
        $title = "פרשת השבוע בישראל";
    }

    DEBUG("Invoking $cmd");
    my @events = Hebcal::invoke_hebcal_v2($cmd, "", 0, $smonth);
    my $parasha = find_parasha_hashavuah(\@events, $sday);
    if ($parasha) {
	DEBUG("This week's Torah Portion is $parasha");
	my $outfile = "$Hebcal::WEBDIR/sedrot/$basename.xml";
        my($dbh,$sth) = open_leyning_db($diaspora);
        rss_parasha_inner($parasha,$syear,$smonth,$sday,
                $outfile,$title,$description,$lang,$dbh,$sth);
        undef $sth;
        $dbh->disconnect();
    }
}

sub find_parasha_hashavuah {
    my($events,$sday) = @_;
    foreach my $evt (@{$events}) {
        if ($evt->{mday} == $sday) {
            return $evt->{subj};
        }
    }
    return undef;
}

sub open_leyning_db {
    my($diaspora) = @_;
    my $dsn = "dbi:SQLite:dbname=$Hebcal::LUACH_SQLITE_FILE";
    DEBUG("Connecting to $dsn");
    my $dbh = DBI->connect($dsn, "", "")
        or LOGDIE("$dsn: $DBI::errstr");
    my $table = $diaspora ? "leyning" : "leyning_israel";
    my $sth = $dbh->prepare("SELECT num,reading FROM $table WHERE dt = ?");
    return ($dbh,$sth);
}

sub rss_parasha_inner {
    my($parasha,$syear,$smonth,$sday,$outfile,$title,$description,$lang,$dbh,$sth) = @_;
    my($href,$hebrew,undef) = Hebcal::get_holiday_anchor($parasha,undef,undef);
    return 0 unless $href;

    my $month_text = Date::Calc::Month_to_Text($smonth);

    if ($lang eq "he") {
        $parasha = $hebrew;
        my %Hebrew_MoY = (
            "January" => "יָנוּאָר",
            "February" => "פֶבְּרוּאָר",
            "March" => "מֶרְץ",
            "April" => "אַפְּרִיל",
            "May" => "מַאי",
            "June" => "יוּנִי",
            "July" => "יוּלִי",
            "August" => "אוֹגוּסְט",
            "September" => "סֶפְּטֶמְבֶּר",
            "October" => "אוֹקְטוֹבֶּר",
            "November" => "נוֹבֶמְבֶּר",
            "December" => "דֶּצֶמְבֶּר",
            );
        $month_text = $Hebrew_MoY{$month_text};
    }

    my $stime = sprintf("%02d %s %d", $sday, $month_text, $syear);

    my $pubDate = strftime("%a, %d %b %Y %H:%M:%S GMT",
			   gmtime(time()));

    my $dow = $Hebcal::DoW[Hebcal::get_dow($syear, $smonth, $sday)];
    my $parasha_pubDate = sprintf("%s, %02d %s %d 12:00:00 GMT",
				  $dow,
				  $sday,
				  $Hebcal::MoY_short[$smonth - 1],
				  $syear);
    my $dt = sprintf("%d%02d%02d", $syear, $smonth, $sday);
    DEBUG("Creating $outfile");
    open(RSS,">$outfile.$$") || LOGDIE "$outfile: $!";
    my $link = "https://$HOSTNAME$href?utm_medium=rss&amp;utm_source=rss-parasha";
    my $channel_link = "https://$HOSTNAME/sedrot/";
    my $memo = Hebcal::torah_calendar_memo($dbh, $sth, $syear, $smonth, $sday);
    $memo =~ s/\\n/<\/p>\n<p>/g;
    $memo = "<![CDATA[<p>" . $memo . "</p>]]>";
    my $basename = basename($outfile);
    print RSS qq{<?xml version="1.0" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<title>$title</title>
<link>$channel_link</link>
<atom:link href="${channel_link}${basename}" rel="self" type="application/rss+xml" />
<description>$description</description>
<language>$lang</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$parasha - $stime</title>
<link>$link</link>
<description>$memo</description>
<pubDate>$parasha_pubDate</pubDate>
<guid isPermaLink="false">$link&amp;dt=$dt</guid>
</item>
</channel>
</rss>
};
    close(RSS);
    rename("$outfile.$$", $outfile) || LOGDIE "$outfile: $!\n";
    1;
}

sub rss_hebdate {
    my($language,$title,$link,$description,$pubDate) = @_;

    return qq{<?xml version="1.0" ?>
<rss version="2.0">
<channel>
<title>Hebrew Date</title>
<link>https://$HOSTNAME/converter</link>
<description>Today\'s Hebrew Date from Hebcal.com</description>
<language>$language</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$title</title>
<link>$link</link>
<description>$description</description>
<pubDate>$pubDate</pubDate>
</item>
</channel>
</rss>
};
}

sub usage {
    die "usage: $0 [-help] [-verbose]\n";
}
