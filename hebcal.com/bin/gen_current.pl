#!/usr/local/bin/perl -w

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use Hebcal;
use POSIX;
use strict;
use Date::Calc;

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
	    print OUT "href=\"$href\">$parsha</a></b><br>$stime";
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
my $line = `$HEBCAL -t | grep -v ' of '`;
chomp($line);
my $wrote_holiday = 0;
if ($line =~ m,^\d+/\d+/\d+\s+(.+)\s*$,) {
    my $holiday = $1;
    my $href = &Hebcal::get_holiday_anchor($holiday);
    if ($href) {
	my($stime) = strftime("%d %B %Y", localtime(time()));
	open(OUT,">$outfile") || die;
	$holiday =~ s/ /&nbsp;/g;
	print OUT "<br><br><span class=\"sm-grey\">&gt;</span>&nbsp;<b><a\n";
	print OUT "href=\"$href\">$holiday</a></b><br>$stime\n";
	close(OUT);
	$wrote_holiday = 1;
    }
}
unless ($wrote_holiday) {
    open(OUT,">$outfile") || die;
    close(OUT);
}

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
    @events = Hebcal::invoke_hebcal("./hebcal -C '$city' -m 0 -c -h -x $fmonth $fyear",
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
	    print OUT qq{<tr><td><a name="$acity" href="/shabbat?geo=city;city=$ucity">$city</a></td><td>$stime</td></tr>\n};
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
