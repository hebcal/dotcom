#!/usr/local/bin/perl5 -w

########################################################################
# Convert between hebrew and gregorian calendar dates.
#
# Copyright (c) 2001  Michael J. Radwin.  All rights reserved.
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

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Time::Local;
use Hebcal;
use HTML::Entities ();
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
"Sh'vat"	=> 'שְׁבָת',
'Adar'	=> 'אַדָר',
'Adar I'	=> 'אַדָר א׳',
'Adar II'	=> 'אַדָר ב׳',
);

my($author) = 'webmaster@hebcal.com';

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($hhmts) = "<!-- hhmts start -->
Last modified: Sun Apr 22 15:59:43 PDT 2001
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated:\n/g;

my($html_footer) = "<hr
noshade size=\"1\"><font size=-2 face=Arial>Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href=\"/privacy/\">Privacy Policy</a> -
<a href=\"/help/\">Help</a>
<br>$hhmts ($rcsrev)
</font></body></html>
";

# process form params
my($q) = new CGI;

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;
my($server_name) = $q->virtual_host();
$server_name =~ s/^www\.//;

$q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		"\t\"http://www.w3.org/TR/html4/loose.dtd");

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

my($cmd)  = './hebcal -x -h';
my($type) = 'g2h';

if ($q->param('h2g') && $q->param('hm') && $q->param('hd') &&
    $q->param('hy') && $q->param('hy') > 3760)
{
    $cmd .= sprintf(' -H "%s" %d %d',
		    $q->param('hm'), $q->param('hd'), $q->param('hy'));
    $type = 'h2g';
}
else
{
    unless ($q->param('gm') && $q->param('gd') && $q->param('gy'))
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

print STDOUT $q->header(-type => "text/html; charset=UTF-8"),
    $q->start_html(-title => 'Hebcal Hebrew Date Converter',
		   -target => '_top',
		   -head => [
			     "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true for \"http://www.$server_name\" r (n 0 s 0 v 0 l 0))'>",
			     $q->Link({-rel => 'stylesheet',
				       -href => '/style.css',
				       -type => 'text/css'}),
			     $q->Link({-rel => 'p3pv1',
				       -href => "http://www.$server_name/w3c/p3p.xml"}),
			     ],
		   ),
    &Hebcal::navbar($server_name, "Hebrew\nDate Converter"),
    "<h1>Hebrew\nDate Converter</h1>\n";

my(@events) = &Hebcal::invoke_hebcal($cmd, '');

if (defined $events[0])
{
    my($subj) = $events[0]->[$Hebcal::EVT_IDX_SUBJ];
    my($year) = $events[0]->[$Hebcal::EVT_IDX_YEAR];
    my($mon) = $events[0]->[$Hebcal::EVT_IDX_MON] + 1;
    my($mday) = $events[0]->[$Hebcal::EVT_IDX_MDAY];

    my($first,$second);
    if ($type eq 'h2g')
    {
	$first = &HTML::Entities::encode($subj);
	$second = sprintf("%d %s %04d",
			  $mday, $Hebcal::MoY_long{$mon}, $year);
    }
    else
    {
	$first = sprintf("%d %s %04d",
			  $mday, $Hebcal::MoY_long{$mon}, $year);
	$second = &HTML::Entities::encode($subj);
    }

    print STDOUT qq{<p align="center"><span\n},
    qq{style="font-size: large">$first =\n<b>$second</b></span>};

    $q->param('gm', $mon);
    $q->param('gd', $mday);
    $q->param('gy', sprintf("%04d", $year));

    if ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
    {
	my($hm,$hd,$hy) = ($2,$1,$3);

	print STDOUT qq{\n<br><span dir="rtl" lang="he"\n},
	qq{style="font-size: xx-large">}, &hebnum_to_string($hd),
	"&nbsp;&nbsp;בְּ", $monthnames{$hm},
	"&nbsp;&nbsp;", &hebnum_to_string($hy),
	qq{</span>};

	$hm = "Shvat" if $hm eq "Sh'vat";
	$hm = "Adar1" if $hm eq "Adar";
	$hm = "Adar1" if $hm eq "Adar I";
	$hm = "Adar2" if $hm eq "Adar II";

	$q->param('hm', $hm);
	$q->param('hd', $hd);
	$q->param('hy', $hy);
    }

    print STDOUT qq{</p>\n};
}

&form(0,'','');

sub form
{
    my($head,$message,$help) = @_;

    my(%months) = %Hebcal::MoY_long;
    my(@hebrew_months) =
	("Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
	 "Cheshvan", "Kislev", "Tevet", "Shvat", "Adar1", "Adar2");
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


    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">\n";
    }

    print STDOUT qq{$message<form action="$script_name">
<center><table cellpadding="4">
<tr align="center"><td colspan="3">Gregorian to Hebrew</td>
<td>&nbsp;</td>
<td colspan="3">Hebrew to Gregorian</td></tr>
<tr><td>Day</td><td>Month</td><td>Year</td>
<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
<td>Day</td><td>Month</td><td>Year</td></tr>
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
    qq{</td>\n<td>},
    qq{&nbsp;},
    qq{</td>\n<td>},
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
<tr><td colspan="3"><input name="g2h"
type="submit" value="Compute Hebrew Date"></td>
<td>&nbsp;</td>
<td colspan="3"><input name="h2g"
type="submit" value="Compute Gregorian Date"></td>
</tr></table></center></form>
};

    print STDOUT $html_footer;

    exit(0);
}

sub hebnum_to_string {
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

sub hebnum_to_array {
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
