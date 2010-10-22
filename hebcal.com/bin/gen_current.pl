#!/usr/local/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2010  Michael J. Radwin.
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

require 5.008_001;

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use open ":utf8";
use Hebcal ();
use Date::Calc ();
use Time::Local ();
use POSIX qw(strftime);

my $WEBDIR = '/home/hebcal/web/hebcal.com';
my $HEBCAL = "$WEBDIR/bin/hebcal";

my($syear,$smonth,$sday) = upcoming_dow(6); # saturday

my $outfile = "$WEBDIR/current.inc";
my $wrote_parasha = 0;

my @events = Hebcal::invoke_hebcal("$HEBCAL -s -h -x $syear", "", 0, $smonth);
my $parasha = '';
for (my $i = 0; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_MDAY] == $sday)
    {
	$parasha = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $href = Hebcal::get_holiday_anchor($parasha,undef,undef);
	if ($href)
	{
	    my $stime = sprintf("%02d %s %d",
				$sday, Date::Calc::Month_to_Text($smonth), $syear);
	    open(OUT,">$outfile") || die;
	    my $parasha2 = $parasha;
	    $parasha2 =~ s/ /&nbsp;/g;
	    print OUT "\n<br><br><li><b><a\n";
	    print OUT "href=\"$href?tag=fp.ql\">$parasha2</a></b><br>$stime";
	    close(OUT);
	    $wrote_parasha = 1;

	    my $pubDate = strftime("%a, %d %b %Y %H:%M:%S GMT",
				   gmtime(time()));

	    my $dow = $Hebcal::DoW[Hebcal::get_dow($syear, $smonth, $sday)];
	    my $parasha_pubDate = sprintf("%s, %02d %s %d 12:00:00 GMT",
					 $dow,
					 $sday,
					 $Hebcal::MoY_short[$smonth - 1],
					 $syear);

	    open(RSS,">$WEBDIR/sedrot/index.xml") || die;
	    print RSS qq{<?xml version="1.0" ?>
<rss version="2.0">
<channel>
<title>Hebcal Parsahat ha-Shavua</title>
<link>http://www.hebcal.com/sedrot/</link>
<description>Torah reading of the week from Hebcal.com</description>
<language>en-us</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$parasha</title>
<link>http://www.hebcal.com$href?tag=rss</link>
<description>$stime</description>
<pubDate>$parasha_pubDate</pubDate>
</item>
</channel>
</rss>
};
	    close(RSS);
	}

	last;
    }
}

unless ($wrote_parasha) {
    # no parasha this week, so create empty include file
    open(OUT,">$outfile") || die;
    close(OUT);
}

my $hdate = `$HEBCAL -T -x -h | grep -v Omer`;
chomp($hdate);

$outfile = "$WEBDIR/today.inc";
open(OUT,">$outfile") || die;
print OUT "$hdate\n";
close(OUT);

if ($hdate =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
{
    my($hm,$hd,$hy) = ($2,$1,$3);
    my $hebrew = Hebcal::build_hebrew_date($hm,$hd,$hy);

    $outfile = "$WEBDIR/etc/hdate-en.js";
    open(OUT,">$outfile") || die;
    print OUT "document.write(\"$hdate\");\n";
    close(OUT);

    $outfile = "$WEBDIR/etc/hdate-he.js";
    open(OUT,">$outfile") || die;
    print OUT "document.write(\"$hebrew\");\n";
    close(OUT);

    my $pubDate = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time()));

    $hm =~ s/[^A-Za-z]+//g;

    open(RSS,">$WEBDIR/etc/hdate-en.xml") || die;
    print RSS qq{<?xml version="1.0" ?>
<rss version="2.0">
<channel>
<title>Hebrew Date</title>
<link>http://www.hebcal.com/converter/</link>
<description>Today\'s Hebrew Date from Hebcal.com</description>
<language>en-us</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$hdate</title>
<link>http://www.hebcal.com/converter/?hd=$hd&amp;hm=$hm&amp;hy=$hy&amp;h2g=1&amp;tag=rss</link>
<description>$hdate</description>
<pubDate>$pubDate</pubDate>
</item>
</channel>
</rss>
};
    close(RSS);

    open(RSS,">$WEBDIR/etc/hdate-he.xml") || die;
    print RSS qq{<?xml version="1.0" ?>
<rss version="2.0">
<channel>
<title>Hebrew Date</title>
<link>http://www.hebcal.com/converter/</link>
<description>Today\'s Hebrew Date from Hebcal.com</description>
<language>he</language>
<copyright>Copyright (c) $syear Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$pubDate</lastBuildDate>
<item>
<title>$hebrew</title>
<link>http://www.hebcal.com/converter/?hd=$hd&amp;hm=$hm&amp;hy=$hy&amp;h2g=1&amp;heb=on&amp;tag=rss</link>
<description>$hebrew</description>
<pubDate>$pubDate</pubDate>
</item>
</channel>
</rss>
};
    close(RSS);
}

$outfile = "$WEBDIR/holiday.inc";
open(OUT,">$outfile") || die;
@events = Hebcal::invoke_hebcal($HEBCAL, '', 0);

my($midnight,$nextweek);
{
    my $now = time;
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($now);
    $year += 1900;

    $midnight = Time::Local::timelocal
	(0,0,0,$mday,$mon,$year,$wday,$yday,$isdst);
#    $saturday = $now + ((6 - $wday) * 60 * 60 * 24);
    $nextweek = $midnight + (5 * 60 * 60 * 24);
}

my %seen;
for (my $i = 0; $i < @events; $i++)
{
    # holiday is at 12:00:01 am
    my $time = Time::Local::timelocal
	(1,0,0,
	 $events[$i]->[$Hebcal::EVT_IDX_MDAY],
	 $events[$i]->[$Hebcal::EVT_IDX_MON],
	 $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
	 "","","");

    if ($time >= $midnight && $time <= $nextweek) {
	my $holiday = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $href = Hebcal::get_holiday_anchor($holiday,undef,undef);
	if ($href) {
	    next if $seen{$href};
	    my $month = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	    my $stime = sprintf("%02d %s %04d",
				$events[$i]->[$Hebcal::EVT_IDX_MDAY],
				$Hebcal::MoY_long{$month},
				$events[$i]->[$Hebcal::EVT_IDX_YEAR]);
	    $holiday =~ s/ /&nbsp;/g;
	    print OUT "\n<br><br><li><b><a\n";
	    print OUT "href=\"$href?tag=fp.ql\">$holiday</a></b><br>$stime\n";
	    $seen{$href} = 1;
	}
    }
}
close(OUT);

sub upcoming_dow
{
    my($searching_dow) = @_;
    my @today = Date::Calc::Today();
    my $current_dow = Date::Calc::Day_of_Week(@today);

    if ($searching_dow == $current_dow)
    {
	return @today;
    }
    elsif ($searching_dow > $current_dow)
    {
	return Date::Calc::Add_Delta_Days(@today,
					  $searching_dow - $current_dow);
    }
    else
    {
	my @prev = Date::Calc::Add_Delta_Days(@today,
				  $searching_dow - $current_dow);
	return Date::Calc::Add_Delta_Days(@prev,+7);
    }
}
