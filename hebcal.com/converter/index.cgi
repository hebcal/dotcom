#!/usr/local/bin/perl -w

########################################################################
# Convert between hebrew and gregorian calendar dates.
#
# Copyright (c) 2002  Michael J. Radwin.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
########################################################################

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use Time::Local;
use Hebcal;
use Unicode::String;
use Date::Calc;
use strict;

my(%num2heb) =
(
1 => 'א',
2 => 'ב',
3 => 'ג',
4 => 'ד',
5 => 'ה',
6 => 'ו',
7 => 'ז',
8 => 'ח',
9 => 'ט',
10 => 'י',
20 => 'כ',
30 => 'ל',
40 => 'מ',
50 => 'נ',
60 => 'ס',
70 => 'ע',
80 => 'פ',
90 => 'צ',
100 => 'ק',
200 => 'ר',
300 => 'ש',
400 => 'ת',
);

my(@hebrew_months) =
    ('Nisan', 'Iyyar', 'Sivan', 'Tamuz', 'Av', 'Elul', 'Tishrei',
     'Cheshvan', 'Kislev', 'Tevet', 'Shvat', 'Adar1', 'Adar2');

my(%monthnames) =
(
'Nisan'	=> 'נִיסָן',
'Iyyar'	=> 'אִיָיר',
'Sivan'	=> 'סִיוָן',
'Tamuz'	=> 'תָּמוּז',
'Av'	=> 'אָב',
'Elul'	=> 'אֱלוּל',
'Tishrei'	=> 'תִּשְׁרֵי',
'Cheshvan'	=> 'חֶשְׁוָן',
'Kislev'	=> 'כִּסְלֵו',
'Tevet'	=> 'טֵבֵת',
"Sh'vat"	=> 'שְׁבָט',
'Adar'	=> 'אַדָר',
'Adar I'	=> 'אַדָר א׳',
'Adar II'	=> 'אַדָר ב׳',
);

my($rcsrev) = '$Revision$'; #'

# process form params
my($q) = new CGI;

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
my($key);
foreach $key ($q->param())
{
    my($val) = $q->param($key);
    $val = '' unless defined $val;
    $val =~ s/[^\w\s\.-]//g;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

my($cmd)  = './hebcal -S -x -h';
my($type) = 'g2h';

if ($q->param('h2g') && $q->param('hm') && $q->param('hd') &&
    $q->param('hy'))
{
    &form(1,'Hebrew day must be numeric','')
	if ($q->param('hd') !~ /^\d+$/);

    &form(1,'Hebrew year must be numeric','')
	if ($q->param('hy') !~ /^\d+$/);

    my($hm) = $q->param('hm');
    &form(1,'Unrecognized hebrew month','')
	unless (grep(/^$hm$/, @hebrew_months));

    &form(1,'Hebrew year must be in the common era (3761 and above).','')
	if ($q->param('hy') <= 3760);

    &form(1,'Hebrew day out of valid range 1-30.','')
	if ($q->param('hd') > 30 || $q->param('hd') < 1);

    $cmd .= sprintf(' -H "%s" %d %d',
		    $q->param('hm'), $q->param('hd'), $q->param('hy'));
    $type = 'h2g';
}
else
{
    if ($q->param('gm') && $q->param('gd') && $q->param('gy'))
    {
	&form(1,'Gregorian day must be numeric','')
	    if ($q->param('gd') !~ /^\d+$/);

	&form(1,'Gregorian month must be numeric','')
	    if ($q->param('gm') !~ /^\d+$/);

	&form(1,'Gregorian year must be numeric','')
	    if ($q->param('gy') !~ /^\d+$/);

	&form(1,'Gregorian day out of valid range 1-31.','')
	    if ($q->param('gd') > 31 || $q->param('gd') < 1);

	&form(1,'Gregorian month out of valid range 1-12.','')
	    if ($q->param('gm') > 12 || $q->param('gm') < 1);

	&form(1,'Gregorian year out of valid range 0001-9999','')
	    if ($q->param('gy') > 9999 || $q->param('gy') < 1);

	# after sunset?
	if ($q->param('gs'))
	{
	    my $gm = $q->param('gm');
	    my $gd = $q->param('gd');
	    my $gy = $q->param('gy');

	    ($gy,$gm,$gd) = Date::Calc::Add_Delta_Days($gy,$gm,$gd,1);

	    $q->param('gm', $gm);
	    $q->param('gd', $gd);
	    $q->param('gy', $gy);
	}
    }
    else
    {
	my($now) = time;
	$now = $q->param('t')
	    if (defined $q->param('t') && $q->param('t') =~ /^\d+$/);

	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($now);
	$year += 1900;

	$q->param('gm', $mon + 1);
	$q->param('gd', $mday);
	$q->param('gy', $year);
    }

    $cmd .= sprintf(' %d %d %d',
		    $q->param('gm'), $q->param('gd'), $q->param('gy'));
}

&my_header();

my($cmd_pretty) = $cmd;
$cmd_pretty =~ s,.*/,,; # basename
print STDOUT "<!-- $cmd_pretty -->\n";

my(@events) = &Hebcal::invoke_hebcal($cmd, '');

if (defined $events[0])
{
    my($subj) = $events[0]->[$Hebcal::EVT_IDX_SUBJ];
    my($year) = $events[0]->[$Hebcal::EVT_IDX_YEAR];
    my($mon) = $events[0]->[$Hebcal::EVT_IDX_MON] + 1;
    my($mday) = $events[0]->[$Hebcal::EVT_IDX_MDAY];

    my $parsha;
    if (defined $events[1])
    {
	$parsha = $events[1]->[$Hebcal::EVT_IDX_SUBJ];
    }

    my($dow) = $Hebcal::DoW[&Hebcal::get_dow($year, $mon, $mday)];;

    my($first,$second);
    if ($type eq 'h2g')
    {
	$first = &Hebcal::html_entify($subj);
	$second = sprintf("%s, %d %s %04d",
			  $dow, $mday, $Hebcal::MoY_long{$mon}, $year);
    }
    else
    {
	$first = sprintf("%s, %d %s %04d",
			  $dow, $mday, $Hebcal::MoY_long{$mon}, $year);
	$second = &Hebcal::html_entify($subj);
    }


    print STDOUT $Hebcal::gregorian_warning
	if ($year <= 1752);

    print STDOUT qq{<p align="center"><span\n},
    qq{style="font-size: large">$first =\n<b>$second</b></span>};

    $q->param('gm', $mon);
    $q->param('gd', $mday);
    $q->param('gy', sprintf("%04d", $year));

    if ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
    {
	my($hm,$hd,$hy) = ($2,$1,$3);

	print STDOUT qq{\n<br>},
	&Hebcal::display_hebrew($q, "hebrew-big",
			&hebnum_to_string($hd),
			"  בְּ",
			$monthnames{$hm},
			"  ",
			&hebnum_to_string($hy))
	    if ($q->param('heb') && $q->param('heb') =~ /^on|1$/);

	$hm = "Shvat" if $hm eq "Sh'vat";
	$hm = "Adar1" if $hm eq "Adar";
	$hm = "Adar1" if $hm eq "Adar I";
	$hm = "Adar2" if $hm eq "Adar II";

	$q->param('hm', $hm);
	$q->param('hd', $hd);
	$q->param('hy', $hy);
    }

    if ($parsha) {
        my $href = &Hebcal::get_holiday_anchor($parsha,0,$q);
	print STDOUT qq{\n<br><a href="$href">$parsha</a>};
    }

    print STDOUT qq{</p>\n};
}

&form(0,'','');

sub form($$$)
{
    my($head,$message,$help) = @_;

    my(%months) = %Hebcal::MoY_long;
    my(%hebrew_months) =
	(
	 "Nisan" => "Nisan",
	 "Iyyar" => "Iyyar",
	 "Sivan" => "Sivan",
	 "Tamuz" => "Tamuz",
	 "Av" => "Av",
	 "Elul" => "Elul",
	 "Tishrei" => "Tishrei",
	 "Cheshvan" => "Cheshvan",
	 "Kislev" => "Kislev",
	 "Tevet" => "Tevet",
	 "Shvat" => "Sh'vat",
	 "Adar1" => "Adar I",
	 "Adar2" => "Adar II",
	 );

    &my_header() if $head;

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">\n";
    }

    print STDOUT qq{$message<form name="f1" id="f1"\naction="$script_name">
<center><table cellpadding="4">
<tr align="center"><td class="box"><table>
<tr><td colspan="3">Gregorian to Hebrew</td></tr>
<tr><td>Day</td><td>Month</td><td>Year</td></tr>
<tr><td>},
    $q->textfield(-name => "gd",
		  -id => "gd",
		  -maxlength => 2,
		  -size => 2),
    qq{</td>\n<td>},
    $q->popup_menu(-name => "gm",
		   -id => "gm",
		   -values => [1..12],
		   -labels => \%months),
    qq{</td>\n<td>},
    $q->textfield(-name => "gy",
		  -id => "gy",
		  -maxlength => 4,
		  -size => 4),
    qq{</td></tr>\n<tr><td colspan="3"><label for="gs">},
    $q->checkbox(-name => 'gs',
		 -id => 'gs',
		 -checked => '',
		 -override => 1,
		 -label => "\nAfter sunset"),
    qq{</label>
<br><input name="g2h"
type="submit" value="Compute Hebrew Date"></td></tr>
</table></td>
<td>&nbsp;&nbsp;&nbsp</td>
<td class="box"><table>
<tr><td colspan="3">Hebrew to Gregorian</td></tr>
<tr><td>Day</td><td>Month</td><td>Year</td></tr>\n},
    qq{<tr><td>},
    $q->textfield(-name => "hd",
		  -id => "hd",
		  -maxlength => 2,
		  -size => 2),
    qq{</td>\n<td>},
    $q->popup_menu(-name => "hm",
		   -id => "hm",
		   -values => [@hebrew_months],
		   -labels => \%hebrew_months),
    qq{</td>\n<td>},
    $q->textfield(-name => "hy",
		  -id => "hy",
		  -maxlength => 4,
		  -size => 4),
    qq{</td></tr>
<tr><td colspan="3"><input name="h2g"
type="submit" value="Compute Gregorian Date"></td>
</tr></table>
</td></tr>
</table>
<label for="heb">
},
    $q->checkbox(-name => 'heb',
		 -id => 'heb',
		 -label => "\nShow date in Hebrew font"),
    qq{</label><br><small>(requires minimum of IE 4 or Netscape 6)</small>\n</center></form>};

    print STDOUT <<EOHTML
<p>Reference: <em><a
href="http://www.amazon.com/exec/obidos/ASIN/0521777526/hebcal-20">Calendrical
Calculations</a></em>, Edward M. Reingold, Nachum Dershowitz,
Cambridge University Press, 2001.</p>
EOHTML
;

    print STDOUT &Hebcal::html_footer($q,$rcsrev);

    exit(0);
}

sub hebnum_to_string($) {
    my($num) = @_;

    my(@array) = &hebnum_to_array($num);
    my($result);

    if (scalar(@array) == 1)
    {
	$result = $num2heb{$array[0]} . '׳'; # geresh
    }
    else
    {
	$result = '';
	for (my $i = 0; $i < @array; $i++)
	{
	    $result .= '״' if (($i + 1) == @array); # gershayim
	    $result .= $num2heb{$array[$i]};
	}
    }

    $result;
}

sub hebnum_to_array($) {
    my($num) = @_;
    my(@result) = ();

    $num = $num % 1000;

    while ($num > 0)
    {
	my($incr) = 100;

	if ($num == 15 || $num == 16)
	{
	    push(@result, 9, $num - 9);
	    last;
	}

	my($i);
	for ($i = 400; $i > $num; $i -= $incr)
	{
	    if ($i == $incr)
	    {
		$incr = int($incr / 10);
	    }
	}

	push(@result, $i);

	$num -= $i;
    }

    @result;
}


sub my_header
{
    my($charset) = ($q->param('heb') && $q->param('heb') =~ /^on|1$/)
	? '; charset=UTF-8' : '';

    print STDOUT $q->header(-type => "text/html${charset}"),
    &Hebcal::start_html($q, 'Hebcal Hebrew Date Converter',
			[
			 qq{<meta http-equiv="Content-Type" content="text/html${charset}">},
			],
			undef),
    &Hebcal::navbar2($q, "Hebrew Date\nConverter", 1, undef, undef),
    "<h1>Hebrew\nDate Converter</h1>\n";

    1;
}

# local variables:
# mode: perl
# end:
