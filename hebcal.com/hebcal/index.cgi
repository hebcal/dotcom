#!/usr/local/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting times
# are calculated from your latitude and longitude (which can be
# determined by your zip code or closest city).
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

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;
use Hebcal;
use HTML::CalendarMonthSimple;

my($author) = 'webmaster@hebcal.com';
my($expires_date) = 'Thu, 15 Apr 2010 20:00:00 GMT';

my($this_mon,$this_year) = (localtime)[4,5];
$this_year += 1900;
$this_mon++;

my($rcsrev) = '$Revision$'; #'

my($latlong_url) = 'http://www.getty.edu/research/tools/vocabulary/tgn/';

my($cmd)  = './hebcal';

# process form params
my($q) = new CGI;

$q->delete('.s');		# we don't care about submit button

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;

my($set_checked) = 'checked';
my($cookies) = &Hebcal::get_cookies($q);
my($C_cookie) = (defined $cookies->{'C'}) ? 'C=' . $cookies->{'C'} : '';
if (! $q->param('v') && $C_cookie)
{
    if ($C_cookie eq 'C=opt_out')
    {
	$set_checked = '';
    }
    else
    {
	&Hebcal::process_cookie($q,$C_cookie);
    }
}

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
foreach my $key ($q->param())
{
    my($val) = $q->param($key);
    $val = '' unless defined $val;
    $val =~ s/[^\w\.\s-]//g;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

# decide whether this is a results page or a blank form
&form('') unless $q->param('v');

&form("Please specify a year.")
    if !defined $q->param('year') || $q->param('year') eq '';

&form("Sorry, invalid year\n<b>" . $q->param('year') . "</b>.")
    if $q->param('year') !~ /^\d+$/ || $q->param('year') == 0;

&form("Sorry, Hebrew year must be 3762 or later.")
    if $q->param('yt') && $q->param('yt') eq 'H' && $q->param('year') < 3762;

&form("Sorry, invalid Havdalah minutes\n<b>" . $q->param('m') . "</b>.")
    if defined $q->param('m') &&
    $q->param('m') ne '' && $q->param('m') !~ /^\d+$/;

$q->param('c','on')
    if (defined $q->param('zip') && $q->param('zip') =~ /^\d{5}$/);

&form("Please select at least one event option.")
    if ((!defined $q->param('nh') || $q->param('nh') eq 'off') &&
	(!defined $q->param('nx') || $q->param('nx') eq 'off') &&
	(!defined $q->param('o') || $q->param('o') eq 'off') &&
	(!defined $q->param('c') || $q->param('c') eq 'off') &&
	(!defined $q->param('d') || $q->param('d') eq 'off') &&
	(!defined $q->param('s') || $q->param('s') eq 'off'));

my($cmd_extra,$city_descr,$lat_descr,$long_descr,$dst_tz_descr) =
    &get_candle_config($q);

$cmd .= $cmd_extra if $cmd_extra;

foreach (@Hebcal::opts)
{
    $cmd .= ' -' . $_
	if defined $q->param($_) && $q->param($_) =~ /^on|1$/
}

$cmd .= ' -h' if !defined $q->param('nh') || $q->param('nh') eq 'off';
$cmd .= ' -x' if !defined $q->param('nx') || $q->param('nx') eq 'off';

if ($q->param('c') && $q->param('c') ne 'off')
{
    $cmd .= " -m " . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    $cmd .= " -z " . $q->param('tz')
	if (defined $q->param('tz') && $q->param('tz') ne '');

    $cmd .= " -Z " . $q->param('dst')
	if (defined $q->param('dst') && $q->param('dst') ne '');
}

if ($q->param('yt') && $q->param('yt') eq 'H')
{
    $q->param('month', 'x');
    $cmd .= ' -H';
}

$cmd .= " " . $q->param('month')
    if (defined $q->param('month') && $q->param('month') =~ /^\d+$/ &&
	$q->param('month') >= 1 && $q->param('month') <= 12);

$cmd .= " " . $q->param('year');


if (! defined $q->path_info())
{
    &results_page();
}
elsif ($q->path_info() =~ /[^\/]+.csv$/)
{
    &csv_display();
}
elsif ($q->path_info() =~ /[^\/]+.dba$/)
{
    &dba_display();
}
elsif (defined $q->param('cfg') && $q->param('cfg') eq 'e')
{
    &javascript_events();
}
else
{
    &results_page();
}

close(STDOUT);
exit(0);

sub javascript_events() {
    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    my(@events) = &Hebcal::invoke_hebcal($cmd, $loc,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);
    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    print $q->header(-type => "application/x-javascript",
		     -last_modified => &Hebcal::http_date($time));

    for (my $i = 0; $i < @events; $i++)
    {
	my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];

	my($min) = $events[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

	#DefineEvent(EventDate,EventDescription,EventLink,Image,Width,Height)
	$subj .= sprintf(": %d:%02d", $hour, $min)
	    if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0);
	printf("DefineEvent(%04d%02d%02d, \"%s\", '', '', 0, 0);\015\012",
	       $year, $mon, $mday, $subj);
    }
}


sub dba_display() {
    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    my(@events) = &Hebcal::invoke_hebcal($cmd, $loc,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);
    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;
    print $q->header(-type =>
		     "application/x-palm-dba; filename=\"$path_info\"",
		     -content_disposition =>
		     "inline; filename=$path_info",
		     -last_modified => &Hebcal::http_date($time));

    my($dst) = 0;

    if (defined $q->param('geo') && $q->param('geo') eq 'city' &&
	defined $q->param('city') && $q->param('city') ne '')
    {
	$dst = defined $Hebcal::city_nodst{$q->param('city')} ?
	    0 : 1;
    }
    elsif (defined($q->param('dst')) && $q->param('dst') eq 'usa')
    {
	$dst = 1;
    }

    &Hebcal::dba_write_header($path_info);
    &Hebcal::dba_write_contents(\@events, $q->param('tz'), $dst);
}

sub csv_display() {
    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    my(@events) = &Hebcal::invoke_hebcal($cmd, $loc,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);
    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;
    print $q->header(-type => "text/x-csv; filename=\"$path_info\"",
		     -content_disposition =>
		     "inline; filename=$path_info",
		     -last_modified => &Hebcal::http_date($time));

    my($endl) = "\012";			# default Netscape and others
    if (defined $q->user_agent() && $q->user_agent() !~ /^\s*$/)
    {
	$endl = "\015\012"
	    if $q->user_agent() =~ /Microsoft Internet Explorer/;
	$endl = "\015\012" if $q->user_agent() =~ /MSP?IM?E/;
    }

    &Hebcal::csv_write_contents(\@events, $endl);
}

sub form($$)
{
    my($message,$help) = @_;
    my($key,$val,$JSCRIPT);

    $JSCRIPT=<<JSCRIPT_END;
function s1(geo) {
document.f1.geo.value=geo;
document.f1.c.value='on';
document.f1.v.value='0';
document.f1.submit();
return false;
}
function s2() {
if (document.f1.nh.checked == false) {
document.f1.nx.checked = false;
}
return false;
}
function s3() {
if (document.f1.i.checked == true) {
document.f1.s.checked = true;
}
return false;
}
function s4() {
if (document.f1.s.checked == false) {
document.f1.i.checked = false;
}
return false;
}
function s5() {
if (document.f1.nx.checked == true) {
document.f1.nh.checked = true;
}
return false;
}
JSCRIPT_END

    print STDOUT $q->header(-type => "text/html; charset=UTF-8"),
    &Hebcal::start_html($q, "Hebcal Interactive Jewish Calendar",
			[
			 qq{<script language="JavaScript" type="text/javascript"><!--\n$JSCRIPT// --></script>},
			 qq{<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">},
			 $q->Link({-rel => 'SCHEMA.dc',
				   -href => 'http://purl.org/metadata/dublin_core_elements'}),
			 ],
			{
		       'description' =>
		       'Generates a list of Jewish holidays and candle lighting times customized to your zip code, city, or latitude/longitude',

		       'keywords' =>
		       'hebcal, Jewish calendar, Hebrew calendar, candle lighting, Shabbat, Havdalah, sedrot, Sadinoff',

		       'DC.Title' => 'Hebcal Interactive Jewish Calendar',
		       'DC.Creator.PersonalName' => 'Radwin, Michael',
		       'DC.Creator.PersonalName.Address' => $author,
		       'DC.Subject' => 'Jewish calendar, Hebrew calendar, hebcal',
		       'DC.Type' => 'Text.Form',
		       'DC.Language' => 'en',
		       'DC.Date.X-MetadataLastModified' => '2001-04-22',
		       },
		   ),
    &Hebcal::navbar2($q, 'Interactive Calendar', 1, undef, undef),
    "<h1>Hebcal\nInteractive Jewish Calendar</h1>";

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">";
    }

    print STDOUT $message, "\n",
    "<form id=\"f1\" name=\"f1\"\naction=\"",
    $script_name, "\">",
    "<strong>Jewish Holidays for:</strong>&nbsp;&nbsp;&nbsp;\n",
    "<label for=\"year\">Year:\n",
    $q->textfield(-name => 'year',
		  -id => 'year',
		  -default => $this_year,
		  -size => 4,
		  -maxlength => 4),
    "</label>\n",
    $q->hidden(-name => 'v',-value => 1,-override => 1),
    "\n&nbsp;&nbsp;&nbsp;\n",
    "<label for=\"month\">Month:\n",
    $q->popup_menu(-name => 'month',
		   -id => 'month',
		   -values => ['x',1..12],
		   -default => $this_mon,
		   -labels => \%Hebcal::MoY_long),
    "</label>\n",
    "<br>Year type:\n",
    $q->radio_group(-name => 'yt',
		    -values => ['G', 'H'],
		    -default => 'G',
		    -labels =>
		    {'G' => "\nGregorian (common era) ",
		     'H' => "\nHebrew Year "}),
    "<br>",
    $q->small("Use all digits to specify a year.\nYou probably aren't",
	      "interested in 93, but rather 1993.\n");

    print STDOUT "<p><strong>Include events:</strong>",
    "<br><label\nfor=\"nh\">",
    $q->checkbox(-name => 'nh',
		 -id => 'nh',
		 -checked => 'checked',
		 -onClick => "s2()",
		 -label => "\nAll default Holidays"),
    "</label> <small>(<a\n",
    "href=\"/help/holidays.html\">What\n",
    "are the default Holidays?</a>)</small>",
    "<br><label\nfor=\"nx\">",
    $q->checkbox(-name => 'nx',
		 -id => 'nx',
		 -checked => 'checked',
		 -onClick => "s5()",
		 -label => "\nRosh Chodesh"),
    "</label>",
    "<br><label\nfor=\"o\">",
    $q->checkbox(-name => 'o',
		 -id => 'o',
		 -label => "\nDays of the Omer"),
    "</label>",
    "<br><label\nfor=\"s\">",
    $q->checkbox(-name => 's',
		 -id => 's',
		 -onClick => "s4()",
		 -label => "\nWeekly sedrot on Saturday"),
    "</label>\n(<label\nfor=\"i\">",
    $q->checkbox(-name => 'i',
		 -id => 'i',
		 -onClick => "s3()",
		 -label => "\nUse Israeli sedra scheme"),
    "</label>)";

    $q->param('c','off') unless defined $q->param('c');

    my($type) = 'zip code';
    my($after_type) = '';
    if (defined $q->param('geo'))
    {
	if ($q->param('geo') eq 'city')
	{
	    $type = "closest city";
	}
	elsif ($q->param('geo') eq 'pos')
	{
	    $type = "latitude/longitude";
	    $after_type = "<small>(<a\n" . 
		"href=\"$latlong_url\">search\n" .
		"latitude/longitude</a>)</small>\n";
	}
    }

    print STDOUT $q->hidden(-name => 'c',
			    -id => 'c'),
    "<br>Candle lighting times for $type:\n",
    $after_type,
    "<br><small>(or select by\n";

    if (defined $q->param('geo') && $q->param('geo') eq 'city')
    {
	print STDOUT
	    $q->a({-href => $script_name . "?c=on;geo=zip",
		   -onClick => "return s1('zip')",
	           },
		  "zip code"), " or\n",
	    $q->a({-href => $script_name . "?c=on;geo=pos",
		   -onClick => "return s1('pos')",
	           },
		  "latitude/longitude");
    }
    elsif (defined $q->param('geo') && $q->param('geo') eq 'pos')
    {
	print STDOUT
	    $q->a({-href => $script_name . "?c=on;geo=zip",
		   -onClick => "return s1('zip')",
	           },
		  "zip code"), " or\n",
	    $q->a({-href => $script_name . "?c=on;geo=city",
		   -onClick => "return s1('city')",
	           },
		  "closest city");
    }
    else
    {
	print STDOUT
	    $q->a({-href => $script_name . "?c=on;geo=city",
		   -onClick => "return s1('city')",
	           },
		  "closest city"), " or\n",
	    $q->a({-href => $script_name . "?c=on;geo=pos",
		   -onClick => "return s1('pos')",
	           },
		  "latitude/longitude");
    }
    print STDOUT ")</small><br>";

    if (defined $q->param('geo') && $q->param('geo') eq 'city')
    {
	print STDOUT $q->hidden(-name => 'geo',
				-value => 'city',
				-id => 'geo'),
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"city\">",
	"Closest City:\n",
	$q->popup_menu(-name => 'city',
		       -id => 'city',
		       -values => [sort keys %Hebcal::city_tz],
		       -default => 'Jerusalem'),
	"</label><br>";
    }
    elsif (defined $q->param('geo') && $q->param('geo') eq 'pos')
    {
	print STDOUT $q->hidden(-name => 'geo',
				-value => 'pos',
				-id => 'geo'),
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"ladeg\">",
	$q->textfield(-name => 'ladeg',
		      -id => 'ladeg',
		      -size => 3,
		      -maxlength => 2),
	"&nbsp;deg</label>&nbsp;&nbsp;\n",
	"<label for=\"lamin\">",
	$q->textfield(-name => 'lamin',
		      -id => 'lamin',
		      -size => 2,
		      -maxlength => 2),
	"&nbsp;min</label>&nbsp;\n",
	$q->popup_menu(-name => 'ladir',
		       -id => 'ladir',
		       -values => ['n','s'],
		       -default => 'n',
		       -labels => {'n' => 'North Latitude',
				   's' => 'South Latitude'}),
	"<br>",
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"lodeg\">",
	$q->textfield(-name => 'lodeg',
		      -id => 'lodeg',
		      -size => 3,
		      -maxlength => 3),
	"&nbsp;deg</label>&nbsp;&nbsp;\n",
	"<label for=\"lomin\">",
	$q->textfield(-name => 'lomin',
		      -id => 'lomin',
		      -size => 2,
		      -maxlength => 2),
	"&nbsp;min</label>&nbsp;\n",
	$q->popup_menu(-name => 'lodir',
		       -id => 'lodir',
		       -values => ['w','e'],
		       -default => 'w',
		       -labels => {'e' => 'East Longitude',
				   'w' => 'West Longitude'}),
	"<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n";
    }
    else
    {
	print STDOUT $q->hidden(-name => 'geo',
				-value => 'zip',
				-id => 'geo'),
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"zip\">\n",
	"Zip code:\n",
	$q->textfield(-name => 'zip',
		      -id => 'zip',
		      -size => 5,
		      -maxlength => 5),
	"</label>&nbsp;&nbsp;&nbsp;\n";
    }

    if (!defined $q->param('geo') || $q->param('geo') ne 'city')
    {
	print STDOUT "<label for=\"tz\">Time zone:\n",
	$q->popup_menu(-name => 'tz',
		       -id => 'tz',
		       -values =>
		       (defined $q->param('geo') && $q->param('geo') eq 'pos')
		       ? [-5,-6,-7,-8,-9,-10,-11,-12,
			  12,11,10,9,8,7,6,5,4,3,2,1,0,
			  -1,-2,-3,-4]
		       : ['auto',-5,-6,-7,-8,-9,-10],
		       -default =>
		       (defined $q->param('geo') && $q->param('geo') eq 'pos')
		       ? 0 : 'auto',
		       -labels => \%Hebcal::tz_names),
	"</label><br>",
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Daylight Saving Time:\n",
	$q->radio_group(-name => 'dst',
			-values =>
			(defined $q->param('geo') && $q->param('geo') eq 'pos')
			? ['usa','israel','none']
			: ['usa','none'],
			-default =>
			(defined $q->param('geo') && $q->param('geo') eq 'pos')
			? 'none' : 'usa',
			-labels =>
			{'usa' => "\nUSA (except AZ, HI, and IN) ",
			 'israel' => "\nIsrael ",
			 'none' => "\nnone ", }),
	"<br>";
    }

    print STDOUT "<label\nfor=\"m\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
    "Havdalah minutes past sundown:\n",
    $q->textfield(-name => 'm',
		  -id => 'm',
		  -size => 3,
		  -maxlength => 3,
		  -default => 72),
    "</label></p>\n";

    print STDOUT "<p><strong>Other options:</strong>",
    "<br><label\nfor=\"vis\">",
    $q->checkbox(-name => 'vis',
		 -id => 'vis',
		 -checked => 'checked',
		 -label => "\nDisplay visual calendar grid"),
    "</label>",
    "<br><label\nfor=\"a\">",
    $q->checkbox(-name => 'a',
		 -id => 'a',
		 -label => "\nUse Ashkenazis Hebrew transliterations"),
    "</label>",
    "<br><label\nfor=\"Dsome\">",
    $q->checkbox(-name => 'D',
		 -id => 'Dsome',
		 -label => "\nShow Hebrew date for dates with some event"),
    "</label>",
    "<br><label\nfor=\"dentire\">",
    $q->checkbox(-name => 'd',
		 -id => 'dentire',
		 -label => "\nShow Hebrew date for entire date range"),
    "</label>",
    "<br><label\nfor=\"set\">",
    $q->checkbox(-name => 'set',
		 -id => 'set',
		 -checked => $set_checked,
		 -label => "\nSave my preferences in a cookie"),
    "</label> <small>(<a\n",
    "href=\"/help/#cookie\">What's\n",
    "a cookie?</a> - <a\n",
    "href=\"del_cookie?", time(), "\">Delete\n",
    "my cookie</a>)</small>",
    "<br><label\nfor=\"heb\">",
    $q->checkbox(-name => 'heb',
		 -id => 'heb',
		 -label => "\nShow Hebrew event names"),
    "</label>",
    "</p>\n",
#    $q->hidden(-name => '.rand', -value => time(), -override => 1),
    $q->submit(-name => '.s',-value => 'Get Calendar'),
    $q->hidden(-name => '.cgifields',
	       -values => ['nx', 'nh', 'set'],
	       '-override'=>1),
    "</form>";

    print STDOUT &Hebcal::html_footer($q,$rcsrev);

    exit(0);
    1;
}

sub results_page()
{
    my($date);
    my($filename) = 'hebcal_' . $q->param('year');
    $filename .= 'H'
	if $q->param('yt') && $q->param('yt') eq 'H';
    my($prev_url,$next_url,$prev_title,$next_title);

    if ($q->param('month') =~ /^\d+$/ &&
	$q->param('month') >= 1 && $q->param('month') <= 12)
    {
	$filename .= '_' . lc($Hebcal::MoY_short[$q->param('month')-1]);
	$date = sprintf("%s %04d", $Hebcal::MoY_long{$q->param('month')},
			$q->param('year'));
    }
    else
    {
	$date = sprintf("%s%04d",
			($q->param('yt') && $q->param('yt') eq 'H') ?
			'Hebrew Year ' : '',
			$q->param('year'));
    }

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	if (defined $q->param('zip'))
	{
	    $filename .= '_' . $q->param('zip');
	}
	elsif (defined $q->param('city'))
	{
	    my($tmp) = lc($q->param('city'));
	    $tmp =~ s/[^\w]/_/g;
	    $filename .= '_' . $tmp;
	}
    }

    # process cookie, delete before we generate next/prev URLS
    if ($q->param('set')) {
	my($newcookie) = &Hebcal::gen_cookie($q);
	if (! $C_cookie)
	{
	    print STDOUT "Set-Cookie: ", $newcookie, "; expires=",
	    $expires_date, "; path=/\015\012"
		if $newcookie =~ /&/;
	}
	else
	{
	    my($cmp1) = $newcookie;
	    my($cmp2) = $C_cookie;

	    $cmp1 =~ s/^C=t=\d+\&?//;
	    $cmp2 =~ s/^C=t=\d+\&?//;

	    print STDOUT "Set-Cookie: ", $newcookie, "; expires=",
	    $expires_date, "; path=/\015\012"
		if $cmp1 ne $cmp2;
	}

	$q->delete('set');
    }

    # next and prev urls
    if ($q->param('month') =~ /^\d+$/ &&
	$q->param('month') >= 1 && $q->param('month') <= 12)
    {
	my($pm,$nm,$py,$ny);

	if ($q->param('month') == 1)
	{
	    $pm = 12;
	    $nm = 2;
	    $py = $q->param('year') - 1;
	    $ny = $q->param('year');
	}
	elsif ($q->param('month') == 12)
	{
	    $pm = 11;
	    $nm = 1;
	    $py = $q->param('year');
	    $ny = $q->param('year') + 1;
	}
	else
	{
	    $pm = $q->param('month') - 1;
	    $nm = $q->param('month') + 1;
	    $ny = $py = $q->param('year');
	}

	$prev_url = &self_url($q, {'year' => $py, 'month' => $pm});
	$prev_title = $Hebcal::MoY_short[$pm-1] . " " . $py;

	$next_url = &self_url($q, {'year' => $ny, 'month' => $nm});
	$next_title = $Hebcal::MoY_short[$nm-1] . " " . $ny;
    }
    else
    {
	$prev_url = &self_url($q, {'year' => ($q->param('year') - 1)});
	$prev_title = ($q->param('year') - 1);

	$next_url = &self_url($q, {'year' => ($q->param('year') + 1)});
	$next_title = ($q->param('year') + 1);
    }

    my($goto_prefix) = "<p class=\"goto\"><b>" .
	"<a\nhref=\"$prev_url\">&lt;&lt;</a>\n" .
	$date . "\n" .
	"<a\nhref=\"$next_url\">&gt;&gt;</a></b>";

    print STDOUT $q->header(-expires => $expires_date,
			    -type => "text/html; charset=UTF-8"),
    &Hebcal::start_html($q, "Hebcal: Jewish Calendar $date",
			[
			 qq{<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">},
			 $q->Link({-rel => 'prev',
				   -href => $prev_url,
				   -title => $prev_title}),
			 $q->Link({-rel => 'next',
				   -href => $next_url,
				   -title => $next_title}),
			 $q->Link({-rel => 'start',
				   -href => $script_name,
				   -title => 'Hebcal Interactive Jewish Calendar'})
			 ],
			undef
			),
    &Hebcal::navbar2($q, $date, 1,
		     "Interactive\nCalendar", &self_url($q, {'v' => '0'}));

    print STDOUT "<h1>Jewish\nCalendar $date</h1>\n"
	unless ($q->param('vis'));

    my($loc2) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc2 =~ s/\s*&nbsp;\s*/ /g;

    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename
    print STDOUT "<!-- $cmd_pretty -->\n";

    my(@events) = &Hebcal::invoke_hebcal($cmd, $loc2,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);
    my($numEntries) = scalar(@events);

    my($greg_year1,$greg_year2) = (0,0);
    if ($numEntries > 0)
    {
	$greg_year1 = $events[0]->[$Hebcal::EVT_IDX_YEAR];
	$greg_year2 = $events[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];

	print STDOUT $Hebcal::gregorian_warning
	    if ($greg_year1 <= 1752);
    }

    my($geographic_info) = '';

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	$geographic_info = "<dl>\n<dt><big>" . $city_descr . "</big>\n";
	$geographic_info .= "<dd>" . $lat_descr . "\n"
	    if $lat_descr ne '';
	$geographic_info .= "<dd>" . $long_descr . "\n"
	    if $long_descr ne '';
	$geographic_info .= "<dd>" . $dst_tz_descr . "\n"
	    if $dst_tz_descr ne '';
	$geographic_info .= "</dl>\n";

    }

    print STDOUT $geographic_info;

    print STDOUT $Hebcal::indiana_warning
	if ($city_descr =~ / IN &nbsp;/);

    # toggle month/full year and event list/calendar grid
    $goto_prefix .= "\n&nbsp;&nbsp;&nbsp; ";

    # download links
    my($download) = "";

    $download .= qq{<p class="goto">Advanced options:\n<small>[ <a href="} .
	$script_name;
    $download .= "index.html" if $q->script_name() =~ m,/index.html$,;
    $download .= "/$filename.csv?dl=1";

    foreach my $key ($q->param())
    {
	my($val) = $q->param($key);
	$download .= ";$key=" . &Hebcal::url_escape($val);
    }
    $download .= ";filename=$filename.csv";
    $download .= "\">Download&nbsp;Outlook&nbsp;CSV&nbsp;file</a>";

    # only offer DBA export when we know timegm() will work
    if ($greg_year1 > 1969 && $greg_year2 < 2038 &&
	(!defined($q->param('dst')) || $q->param('dst') ne 'israel'))
    {
	$download .= "\n- <a href=\"" . $script_name;
	$download .= "index.html" if $q->script_name() =~ m,/index.html$,;
	$download .= "/$filename.dba?dl=1";

	foreach my $key ($q->param())
	{
	    my($val) = $q->param($key);
	    $download .= ";$key=" . &Hebcal::url_escape($val);
	}
	$download .= ";filename=$filename.dba";
	$download .= "\">Download&nbsp;Palm&nbsp;Date&nbsp;Book&nbsp;Archive&nbsp;(.DBA)</a>";
    }

    $download .= "\n]</small></p>\n";

    my($goto) = "<small>change view: [ ";

    if ($q->param('vis'))
    {
	$goto .= "<a\nhref=\"" . &self_url($q, {'vis' => '0'}) .
	    "\">event\nlist</a> | <b>calendar grid</b> ]";
    }
    else
    {
	$goto .= "<b>event list</b> | <a\nhref=\"" .
	    &self_url($q, {'vis' => 'on'}) . "\">calendar\ngrid</a> ]";
    }

    $goto .= "\n&nbsp;&nbsp;&nbsp; [ ";

    if ($date !~ /^\d+$/ && $date !~ /^Hebrew Year \d+$/)
    {
	$goto .= "<b>month</b> | " .
	    "<a\nhref=\"" . &self_url($q, {'month' => 'x'}) .
	    "\">entire\nyear</a> ]";
    }
    else
    {
	$goto .= "<a\nhref=\"" . &self_url($q, {'month' => '1'}) .
	    "\">month</a> |\n<b>entire year</b> ]";
    }

    $goto .= "</small>\n";

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	if (defined $q->param('zip') && $q->param('zip') =~ /^\d{5}$/)
	{
	    $goto .= join('',
		qq{<br>For weekly candle lighting times, bookmark\n},
		qq{<a href="/shabbat/?zip=}, $q->param('zip'),
		qq{;dst=}, $q->param('dst'),
		qq{;tz=}, $q->param('tz'),
		qq{;m=}, $q->param('m'),
		qq{;.from=interactive},
		qq{">1-Click Shabbat for $city_descr</a>.\n},
		);
	}
	elsif (defined $q->param('city') && $q->param('city') !~ /^\s*$/)
	{
	    $goto .= join('',
		qq{<br>For weekly candle lighting times, bookmark\n},
		qq{<a href="/shabbat/?city=},
 		&Hebcal::url_escape($q->param('city')),
		qq{;m=}, $q->param('m'),
		qq{;.from=interactive},
		qq{">1-Click Shabbat for }, $q->param('city'),
		qq{</a>.\n},
		);
	}
    }

    print STDOUT $goto_prefix, $goto, "</p>"
	unless $q->param('vis');

    if ($numEntries > 0)
    {
	print STDOUT $download;
    }
    else
    {
	print STDOUT qq{<h3 style="color: red">No Hebrew Calendar events\n},
		qq{for $date</h3>};
    }

    print STDOUT "<p>";

    my($cal);
    my($prev_mon) = 0;

    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];

	my($min) = $events[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($href,$hebrew,$memo,$torah_href,$haftarah_href,$drash_href)
	    = &Hebcal::get_holiday_anchor($subj,0,undef);
	if ($hebrew ne '' && defined $q->param('heb') &&
	    $q->param('heb') =~ /^on|1$/)
	{
	    $subj .= "\n/ " . &Hebcal::display_hebrew($q, "hebrew", $hebrew);
	}

	if ($q->param('vis'))
	{
	    if (defined $href && $href ne '')
	    {
		$subj = qq{<a href="$href">$subj</a>};
	    }
	}
	else
	{
	    if (defined $torah_href && $torah_href ne '')
	    {
		$subj .= qq{ <span class="goto">} . 
		qq{(<a href="$drash_href">Drash</a>\n} .
		qq{- <a href="$torah_href">Torah</a>\n} .
		qq{- <a href="$haftarah_href">Haftarah</a>)</span>};
	    }
	    elsif ($href ne '')
	    {
		$subj = qq{<a href="$href">$subj</a>};
	    }
	}

	my($dow) = $Hebcal::DoW[&Hebcal::get_dow($year, $mon, $mday)] . ' ';

	if ($q->param('vis'))
	{
	    if ($prev_mon != $mon)
	    {
		my($style) = ($q->param('month') eq 'x' && $prev_mon > 1) ?
		    ' style="page-break-before: always"' : '';
		print STDOUT "<center$style>", $cal->as_HTML(), 
		"</center><br><br>"
		    if defined $cal;
		$prev_mon = $mon;
		$cal = new HTML::CalendarMonthSimple('year' => $year,
						     'month' => $mon);
		$cal->width('94%');
		$cal->border(1);
		$cal->bgcolor('white');
		$cal->bordercolor('');
		$cal->contentcolor('black');
		$cal->todaybordercolor('red');

		$cal->header("<h2 align=\"center\"><a class=\"goto\"\n" .
			     "href=\"$prev_url\">&lt;&lt;</a>\n" .
			     $Hebcal::MoY_long{$mon} . ' ' .
			     $year . "\n" .
			     "<a class=\"goto\"\n" .
			     "href=\"$next_url\">&gt;&gt;</a></h2>" .
			     '<div align="center" class="goto">' . $goto . '</div>');
	    }

	    my($cal_subj) = $subj;
	    $cal_subj = sprintf("<b>%d:%02dp</b> %s", $hour, $min, $subj)
		if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0);

	    $cal->addcontent($mday, "<br>\n")
		if $cal->getcontent($mday) ne '';

	    my($class) = '';
	    if ($events[$i]->[$Hebcal::EVT_IDX_YOMTOV] == 1)
	    {
		$class = ' class="hl"';
	    }
	    elsif (($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~
		    /^\d+\w+.+, \d{4,}$/) ||
		   ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~
		    /^\d+\w+ day of the Omer$/))
	    {
		$class = ' class="dim"';
	    }

	    $cal->addcontent($mday, "<small$class>$cal_subj</small>");
	}
	else
	{
	    my($line);
	    $line = sprintf("<tt>%s%02d-%s-%04d</tt> &nbsp;%s",
			 $dow, $mday, $Hebcal::MoY_short[$mon-1],
			 $year, $subj);
	    $line .= sprintf(": %d:%02dpm", $hour, $min)
		if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0);
	    $line .= "<br>\n";

	    print STDOUT $line;
	}
    }

    if ($q->param('vis') && defined $cal)
    {
	my($style) = ($q->param('month') eq 'x' && $prev_mon > 1) ?
	    ' style="page-break-before: always"' : '';
	print STDOUT "<center$style>", $cal->as_HTML(), 
	    "</center></body></html>\n";

#	return 1;
    }

    print STDOUT "</p>" unless $q->param('vis');
    print STDOUT $goto_prefix, $goto, "</p>";
    print STDOUT $download if ($numEntries > 0);
    print STDOUT &Hebcal::html_footer($q,$rcsrev);

    1;
}

sub self_url($$)
{
    my($q,$override) = @_;
    my($url) = $script_name;
    my($sep) = '?';

    foreach my $key ($q->param())
    {
	my($val) = defined $override->{$key} ?
	    $override->{$key} : $q->param($key);
	$url .= "$sep$key=" . &Hebcal::url_escape($val);
	$sep = ';' if $sep eq '?';
    }

    foreach my $key (keys %{$override})
    {
	unless (defined $q->param($key))
	{
	    $url .= "$sep$key=" . &Hebcal::url_escape($override->{$key});
	    $sep = ';' if $sep eq '?';
	}
    }

    $url;
}

sub get_candle_config($)
{
    my($q) = @_;

    my($city_descr,$lat_descr,$long_descr,$dst_tz_descr) = ('','','','');
    my($cmd_extra);

    if ($q->param('c') && $q->param('c') ne 'off' &&
	defined $q->param('city'))
    {
	&form("Sorry, invalid city\n<b>" . $q->param('city') . "</b>.")
	    unless defined($Hebcal::city_tz{$q->param('city')});

	$q->param('geo','city');
	$q->param('tz',$Hebcal::city_tz{$q->param('city')});
	$q->delete('dst');

	$city_descr = "Closest City: " . $q->param('city');
	$cmd_extra = " -C '" . $q->param('city') . "'";
    }
    elsif (defined $q->param('lodeg') && defined $q->param('lomin') &&
	   defined $q->param('ladeg') && defined $q->param('lamin') &&
	   defined $q->param('lodir') && defined $q->param('ladir'))
    {
	if (($q->param('lodeg') eq '') &&
	    ($q->param('lomin') eq '') &&
	    ($q->param('ladeg') eq '') &&
	    ($q->param('lamin') eq ''))
	{
	    $q->delete('c');
	    $q->delete('zip');
	    $q->delete('city');
	    $q->delete('geo');
	    $q->delete('lodeg');
	    $q->delete('lomin');
	    $q->delete('ladeg');
	    $q->delete('lamin');
	    $q->delete('lodir');
	    $q->delete('ladir');
	    $q->delete('dst');
	    $q->delete('tz');
	    $q->delete('m');

	    return (undef,$city_descr,$lat_descr,$long_descr,$dst_tz_descr);
	}

	&form("Sorry, all latitude/longitude\narguments must be numeric.")
	    if (($q->param('lodeg') !~ /^\d+$/) ||
		($q->param('lomin') !~ /^\d+$/) ||
		($q->param('ladeg') !~ /^\d+$/) ||
		($q->param('lamin') !~ /^\d+$/));

	$q->param('lodir','w') unless ($q->param('lodir') eq 'e');
	$q->param('ladir','n') unless ($q->param('ladir') eq 's');

	&form("Sorry, longitude degrees\n" .
	      "<b>" . $q->param('lodeg') . "</b> out of valid range 0-180.")
	    if ($q->param('lodeg') > 180);

	&form("Sorry, latitude degrees\n" .
	      "<b>" . $q->param('ladeg') . "</b> out of valid range 0-90.")
	    if ($q->param('ladeg') > 90);

	&form("Sorry, longitude minutes\n" .
	      "<b>" . $q->param('lomin') . "</b> out of valid range 0-60.")
	    if ($q->param('lomin') > 60);

	&form("Sorry, latitude minutes\n" .
	      "<b>" . $q->param('lamin') . "</b> out of valid range 0-60.")
	    if ($q->param('lamin') > 60);

	my($long_deg,$long_min,$lat_deg,$lat_min) =
	    ($q->param('lodeg'),$q->param('lomin'),
	     $q->param('ladeg'),$q->param('lamin'));

	$q->param('dst','none')
	    unless $q->param('dst');
	$q->param('tz','0')
	    unless $q->param('tz');
	$q->param('geo','pos');

	$city_descr = "Geographic Position";
	$lat_descr  = "${lat_deg}d${lat_min}' " .
	    uc($q->param('ladir')) . " latitude";
	$long_descr = "${long_deg}d${long_min}' " .
	    uc($q->param('lodir')) . " longitude";
	$dst_tz_descr = "Daylight Saving Time: " .
	    $q->param('dst') . "\n<dd>Time zone: " .
		$Hebcal::tz_names{$q->param('tz')};

	# don't multiply minutes by -1 since hebcal does it internally
	$long_deg *= -1  if ($q->param('lodir') eq 'e');
	$lat_deg  *= -1  if ($q->param('ladir') eq 's');

	$cmd_extra = " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    }
    elsif ($q->param('c') && $q->param('c') ne 'off' &&
	   defined $q->param('zip') && $q->param('zip') ne '')
    {
	$q->param('dst','usa')
	    unless $q->param('dst');
	$q->param('tz','auto')
	    unless $q->param('tz');
	$q->param('geo','zip');

	&form("Sorry, <b>" . $q->param('zip') . "</b> does\n" .
	      "not appear to be a 5-digit zip code.")
	    unless $q->param('zip') =~ /^\d\d\d\d\d$/;

	my($dbmfile) = 'zips.db';
	my(%DB);
	tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	    || die "Can't tie $dbmfile: $!\n";

	my($val) = $DB{$q->param('zip')};
	untie(%DB);

	&form("Sorry, can't find\n".  "<b>" . $q->param('zip') .
	      "</b> in the zip code database.\n",
	      "<ul><li>Please try a nearby zip code or select candle\n" .
	      "lighting times by\n" .
	      "<a href=\"" . $script_name .
	      "?c=on;geo=city\">city</a> or\n" .
	      "<a href=\"" . $script_name .
	      "?c=on;geo=pos\">latitude/longitude</a></li></ul>")
	    unless defined $val;

	my($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
	my($city,$state) = split(/\0/, substr($val,6));

	if (($state eq 'HI' || $state eq 'AZ') && $q->param('dst') eq 'usa')
	{
	    $q->param('dst','none');
	}

	my(@city) = split(/([- ])/, $city);
	$city = '';
	foreach (@city)
	{
	    $_ = lc($_);
	    $_ = "\u$_";		# inital cap
	    $city .= $_;
	}

	$city_descr = "$city, $state &nbsp;" . $q->param('zip');

	my($tz) = &Hebcal::guess_timezone($q->param('tz'),
					  $q->param('zip'),$state);

	unless (defined $tz)
	{
	    &form("Sorry, can't auto-detect\n" .
		  "timezone for <b>" . $city_descr . "</b>\n".
		  "(state <b>" . $state . "</b> spans multiple time zones).",
		  "<ul><li>Please select your time zone below.</li></ul>");
	}

	$q->param('tz', $tz);

#	$lat_descr  = "${lat_deg}d${lat_min}' N latitude";
#	$long_descr = "${long_deg}d${long_min}' W longitude";
	$dst_tz_descr = "Daylight Saving Time: " .
	    $q->param('dst') . "\n<dd>Time zone: " .
		$Hebcal::tz_names{$q->param('tz')};

	$cmd_extra = " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    }
    else
    {
	$q->delete('c');
	$q->delete('zip');
	$q->delete('city');
	$q->delete('geo');
	$q->delete('lodeg');
	$q->delete('lomin');
	$q->delete('ladeg');
	$q->delete('lamin');
	$q->delete('lodir');
	$q->delete('ladir');
	$q->delete('dst');
	$q->delete('tz');
	$q->delete('m');

	$cmd_extra = undef;
    }

    return ($cmd_extra,$city_descr,$lat_descr,$long_descr,$dst_tz_descr);
}

# local variables:
# mode: perl
# end:
