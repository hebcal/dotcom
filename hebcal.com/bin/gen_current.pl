#!/usr/local/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2005  Michael J. Radwin.
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

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use strict;
use Hebcal ();
use Date::Calc ();

my $WEBDIR = '/home/mradwin/web/hebcal.com';
my $HEBCAL = "$WEBDIR/bin/hebcal";

my($syear,$smonth,$sday) = upcoming_dow(6); # saturday

my $outfile = "$WEBDIR/current.inc";
my $wrote_parsha = 0;

my(@events) = Hebcal::invoke_hebcal("$HEBCAL -s -h -x $smonth $syear", '', 0);
my $parsha = '';
for (my $i = 0; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_MDAY] == $sday)
    {
	$parsha = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $href = Hebcal::get_holiday_anchor($parsha,undef,undef);
	if ($href)
	{
	    my $stime = sprintf("%02d %s %d",
				$sday, Date::Calc::Month_to_Text($smonth), $syear);
	    open(OUT,">$outfile") || die;
	    $parsha =~ s/ /&nbsp;/g;
	    print OUT "<br><br><span class=\"sm-grey\">&gt;</span>&nbsp;<b><a\n";
	    print OUT "href=\"$href?tag=fp.ql\">$parsha</a></b><br>$stime";
	    close(OUT);
	    $wrote_parsha = 1;
	}

	last;
    }
}

unless ($wrote_parsha) {
    # no parsha this week, so create empty include file
    open(OUT,">$outfile") || die;
    close(OUT);
}

my $hdate = `$HEBCAL -T -x -h | grep -v Omer`;
chomp($hdate);

$outfile = "$WEBDIR/today.inc";
open(OUT,">$outfile") || die;
print OUT "$hdate\n";
close(OUT);

my $omer = `$HEBCAL -T | grep Omer`;
chomp($omer);

$outfile = "$WEBDIR/omer.inc";
open(OUT,">$outfile") || die;
print OUT "$omer\n";
close(OUT);

$outfile = "$WEBDIR/etc/hdate-en.js";
open(OUT,">$outfile") || die;
print OUT "document.write(\"$hdate\");\n";
close(OUT);

if ($hdate =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
{
    my($hm,$hd,$hy) = ($2,$1,$3);
    my $hebrew = Hebcal::build_hebrew_date($hm,$hd,$hy);

    $outfile = "$WEBDIR/etc/hdate-he.js";
    open(OUT,">$outfile") || die;
    print OUT "document.write(\"$hebrew\");\n";
    close(OUT);
}

$outfile = "$WEBDIR/holiday.inc";
open(OUT,">$outfile") || die;
@events = Hebcal::invoke_hebcal("$HEBCAL -t", '', 0);
for (my $i = 0; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] !~ / of /) {
	my $holiday = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $href = Hebcal::get_holiday_anchor($holiday,undef,undef);
	if ($href) {
	    my $month = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	    my $stime = sprintf("%02d %s %04d",
				$events[$i]->[$Hebcal::EVT_IDX_MDAY],
				$Hebcal::MoY_long{$month},
				$events[$i]->[$Hebcal::EVT_IDX_YEAR]);
	    $holiday =~ s/ /&nbsp;/g;
	    print OUT "<br><br><span class=\"sm-grey\">&gt;</span>&nbsp;<b><a\n";
	    print OUT "href=\"$href?tag=fp.ql\">$holiday</a></b><br>$stime\n";
	}
    }
}
close(OUT);

my($fyear,$fmonth,$fday) = upcoming_dow(5); # friday
$outfile = "$WEBDIR/shabbat/cities.html";
open(OUT,">$outfile") || die;
my $fmonth_text = Date::Calc::Month_to_Text($fmonth);
print OUT <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head>
<title>Candle lighting times for world cities - $fday $fmonth_text $fyear</title>
<base href="http://www.hebcal.com/shabbat/cities.html" target="_top">
<link rel="stylesheet" href="/style.css" type="text/css">
</head>
<body>
<!--htdig_noindex-->
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a> <tt>-&gt;</tt>
World Cities
</small></td>
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>
<!--/htdig_noindex-->
<h1>Candle lighting times for world cities</h1>
<h3>$parsha<br>$fday $fmonth_text $fyear</h3>
<h4>United States</h4>
<p>
<form action="/shabbat/">
<label for="zip">Enter Zip code:</label>
<input type="text" name="zip" size="5" maxlength="5"
id="zip">&nbsp;<input type="submit" value="Go">
<input type="hidden" name="geo" value="zip">
</form>
</p>
<h4>International Cities</h4>
<br>
<table border="1" cellpadding="3">
<tr><th>City</th><th>Candle lighting</th></tr>
EOHTML
;

foreach my $city (sort keys %Hebcal::city_tz)
{
    @events = Hebcal::invoke_hebcal("$HEBCAL -C '$city' -m 0 -c -h -x $fmonth $fyear",
				    '', 0);
    for (my $i = 0; $i < @events; $i++)
    {
	if ($events[$i]->[$Hebcal::EVT_IDX_MDAY] == $fday &&
	    $events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Candle lighting')
	{
	    my $min = $events[$i]->[$Hebcal::EVT_IDX_MIN];
	    my $hour = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
	    $hour -= 12 if $hour > 12;
	    my $stime = sprintf("%d:%02dpm", $hour, $min);

	    my $ucity = $city;
	    $ucity =~ s/ /+/g;
	    my $acity = lc($city);
	    $acity =~ s/ /_/g;
	    print OUT qq{<tr><td><a name="$acity" href="/shabbat/?geo=city;city=$ucity;tag=wc">$city</a></td><td>$stime</td></tr>\n};
	}
    }
}

my $copyright = Hebcal::html_copyright2('',0,undef);
print OUT <<EOHTML;
</table>
<p>
<hr noshade size="1">
<span class="tiny">$copyright
</span>
</body></html>
EOHTML
;

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
