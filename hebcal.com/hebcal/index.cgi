#!/usr/local/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
#
# Copyright (c) 2004  Michael J. Radwin.
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
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;
use Date::Calc;
use Hebcal;
use HTML::CalendarMonthSimple;
use Palm::DBA;

my($expires_future) = 'Thu, 15 Apr 2010 20:00:00 GMT';
my($expires_date) = $expires_future;

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

my($rcsrev) = '$Revision$'; #'

my($latlong_url) = 'http://www.getty.edu/research/tools/vocabulary/tgn/';
my %long_candles_text =
    ('pos' => 'latitude/longitude',
     'city' => 'large cities',
     'zip' => 'zip code',
     'none' => 'none');

my($cmd)  = './hebcal';

# process form params
my($q) = new CGI;

$q->delete('.s');		# we don't care about submit button

my($script_name) = $q->script_name();
$script_name =~ s,/index.cgi$,/,;

my($cookies) = Hebcal::get_cookies($q);
my($C_cookie) = (defined $cookies->{'C'}) ? 'C=' . $cookies->{'C'} : '';
if (! $q->param('v') && $C_cookie)
{
    Hebcal::process_cookie($q,$C_cookie);
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

if (defined $q->param('year') && $q->param('year') eq 'now' &&
    defined $q->param('month') && 
    (($q->param('month') eq 'now') || ($q->param('month') eq 'x')))
{
    $q->param('year', $this_year);
    $q->param('month', $this_mon)
	if $q->param('month') eq 'now';

    my($end_day) = &Date::Calc::Days_in_Month($this_year, $this_mon);
    my($end_of_month) =
	&Time::Local::timelocal(59,59,23,
				$end_day,
				$this_mon - 1,
				$this_year - 1900);

    $expires_date = Hebcal::http_date($end_of_month);
}

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

my $g_date;
my $g_filename = 'hebcal_' . $q->param('year');
$g_filename .= 'H'
    if $q->param('yt') && $q->param('yt') eq 'H';
if ($q->param('month') =~ /^\d+$/ &&
    $q->param('month') >= 1 && $q->param('month') <= 12)
{
    $g_filename .= '_' . lc($Hebcal::MoY_short[$q->param('month')-1]);
    $g_date = sprintf("%s %04d", $Hebcal::MoY_long{$q->param('month')},
		    $q->param('year'));
}
else
{
    $g_date = sprintf("%s%04d",
		    ($q->param('yt') && $q->param('yt') eq 'H') ?
		    'Hebrew Year ' : '',
		    $q->param('year'));
}

if (! defined $q->path_info())
{
    results_page($g_date, $g_filename);
}
elsif ($q->path_info() =~ /[^\/]+\.csv$/)
{
    &csv_display();
}
elsif ($q->path_info() =~ /[^\/]+\.dba$/)
{
    &dba_display();
}
elsif ($q->path_info() =~ /[^\/]+\.tsv$/)
{
    &macintosh_datebook_display();
}
elsif ($q->path_info() =~ /[^\/]+\.[vi]cs$/)
{
    # text/x-vCalendar
    vcalendar_display($g_date);
}
elsif (defined $q->param('cfg') && $q->param('cfg') eq 'e')
{
    &javascript_events();
}
else
{
    results_page($g_date, $g_filename);
}

close(STDOUT);
exit(0);

sub javascript_events() {
    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    my(@events) = Hebcal::invoke_hebcal($cmd, $loc,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);
    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    print $q->header(-type => "application/x-javascript",
		     -last_modified => Hebcal::http_date($time),
		     -expires => $expires_date,
		     );

    for (my $i = 0; $i < @events; $i++)
    {
	my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];

	my($min) = $events[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

	my $img_url = '';
	my $img_w = 0;
	my $img_h = 0;

	if ($q->param('img'))
	{
	    if ($subj =~ /^Candle lighting/)
	    {
		$img_url = 'http://www.hebcal.com/i/sm_candles.gif';
		$img_w = 40;
		$img_h = 69;
	    }
	    elsif ($subj =~ /Havdalah/)
	    {
		$img_url = 'http://www.hebcal.com/i/havdalah.gif';
		$img_w = 46;
		$img_h = 59;
	    }
	}

	my $href = Hebcal::get_holiday_anchor($subj,0,$q);

	#DefineEvent(EventDate,EventDescription,EventLink,Image,Width,Height)
	if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    $subj = sprintf("<b>%d:%02dp</b> %s", $hour, $min, $subj);
	}

	printf("DefineEvent(%04d%02d%02d, \"%s\", \"%s\", \"%s\", %d, %d);\015\012",
	       $year, $mon, $mday, $subj, $href, $img_url, $img_w, $img_h);
    }
}

sub macintosh_datebook_display {

    my(@events) = Hebcal::invoke_hebcal($cmd, '',
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);

    Hebcal::macintosh_datebook($q, \@events);
}

sub vcalendar_display {
    my($date) = @_;
    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    my(@events) = Hebcal::invoke_hebcal($cmd, $loc,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);

    my($tz) = $q->param('tz');
    my $state;

    if ($city_descr =~ /^Large City: (.+)$/)
    {
	$tz = $Hebcal::city_tz{$q->param('city')};
    }
    elsif ($city_descr =~ /^.+, (\w\w) &nbsp;\d{5}$/)
    {
	$state = $1;
    }

    Hebcal::vcalendar_write_contents($q, \@events, $tz, $state, $date);
}

sub dba_display() {
    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    my(@events) = Hebcal::invoke_hebcal($cmd, $loc,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);

    my($dst) = (defined($q->param('dst')) && $q->param('dst') eq 'usa') ?
	1 : 0;
    my($tz) = $q->param('tz');

    if (defined $q->param('geo') && $q->param('geo') eq 'city' &&
	defined $q->param('city') && $q->param('city') ne '')
    {
	$dst = $Hebcal::city_dst{$q->param('city')} eq 'none' ?
	    0 : 1;
	$tz = $Hebcal::city_tz{$q->param('city')};
    }

    Hebcal::export_http_header($q, 'application/x-palm-dba');

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;
    &Palm::DBA::write_header($path_info);
    &Palm::DBA::write_contents(\@events, $tz, $dst);
}

sub csv_display() {
    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    my(@events) = Hebcal::invoke_hebcal($cmd, $loc,
	 defined $q->param('i') && $q->param('i') =~ /^on|1$/);

    my $euro = defined $q->param('euro') ? 1 : 0;
    Hebcal::csv_write_contents($q, \@events, $euro);
}

sub alt_candles_text($$)
{
    my($q,$geo) = @_;

    my $text = $long_candles_text{$geo};
    my $c = ($geo eq 'none') ? 'off' : 'on';
    $q->a({-href => $script_name . "?c=$c;geo=" . $geo,
	   -onClick => "return s1('" . $geo . "', '" . $c . "')" },
	  $text);
}

sub form($$)
{
    my($message,$help) = @_;
    my($key,$val,$JSCRIPT);

    my $hebdate = Hebcal::greg2hebrew($this_year,$this_mon,$this_day);
    my $hyear = $hebdate->{'yy'};

    $JSCRIPT=<<JSCRIPT_END;
function s1(geo,c) {
document.f1.geo.value=geo;
document.f1.c.value=c;
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
function s5() {
if (document.f1.nx.checked == true) {
document.f1.nh.checked = true;
}
return false;
}
function s6(val) {
if (val=='G') {
document.f1.year.value=$this_year;
document.f1.month.value=$this_mon;
}
if (val=='H') {
document.f1.year.value=$hyear;
document.f1.month.value='x';
}
return false;
}
JSCRIPT_END

    my($charset) = ($q->param('heb') && $q->param('heb') =~ /^on|1$/)
	? '; charset=UTF-8' : '';

    my @head = (qq{<script language="JavaScript" type="text/javascript"><!--\n} .
		$JSCRIPT . qq{// --></script>});
    if ($charset) {
	push(@head, qq{<meta http-equiv="Content-Type" content="text/html${charset}">});
    }

    print STDOUT $q->header(-type => "text/html${charset}"),
    Hebcal::start_html($q, "Hebcal Interactive Jewish Calendar",
		       \@head,
			{
		       'description' =>
		       'Generates a list of Jewish holidays and candle lighting times customized to your zip code, city, or latitude/longitude',

		       'keywords' =>
		       'hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,sedrot,Sadinoff',
		       },
		       undef
		   ),
    Hebcal::navbar2($q, 'Interactive Calendar', 1, undef, undef),
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
    "<b>Jewish Holidays for:</b>&nbsp;&nbsp;&nbsp;\n",
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
    "<br>",
    $q->small("Use all digits to specify a year.\nYou probably aren't",
	      "interested in 93, but rather 1993.\n"),
    "<br>Year type:\n",
    $q->radio_group(-name => 'yt',
		    -values => ['G', 'H'],
		    -default => 'G',
		    -onClick => "s6(this.value)",
		    -labels =>
		    {'G' => "\nGregorian (common era) ",
		     'H' => "\nHebrew Year "});

    print STDOUT "<p><table border=\"0\" cellpadding=\"0\"\n",
    "cellspacing=\"0\" style=\"margin-bottom: 10px\"><tr valign=\"top\"><td>\n";

    print STDOUT "<b>Include events</b>",
    "<br><label\nfor=\"nh\">",
    $q->checkbox(-name => 'nh',
		 -id => 'nh',
		 -checked => 'checked',
		 -onClick => "s2()",
		 -label => "\nAll default Holidays"),
    "</label> <small>(<a\n",
    "href=\"/holidays/\">What\n",
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
		 -label => "\nWeekly sedrot on Saturdays"),
    "</label>\n",
    "<br>&nbsp;&nbsp;&nbsp;&nbsp;\n",
    $q->radio_group(-name => 'i',
		    -values => ['off', 'on'],
		    -default => 'off',
		    -labels =>
		    {'off' => "\nDiaspora ",
		     'on' => "\nIsrael "}),
    "\n&nbsp;<small>(<a\n",
    "href=\"/help/sedra.html#scheme\">What\n",
    "is the difference?</a>)</small>";

    print STDOUT "<p><b>Other options</b>",
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
    $q->hidden(-name => 'set', -value => 'on'),
    "<br><label\nfor=\"heb\">",
    $q->checkbox(-name => 'heb',
		 -id => 'heb',
		 -label => "\nShow Hebrew event names"),
    "</label>",
    "\n";

    $q->param('c','off') unless defined $q->param('c');
    $q->param('geo','zip') unless defined $q->param('geo');

    print STDOUT "</td><td><img src=\"/i/black-1x1.gif\"\n",
    "width=\"1\" height=\"250\" hspace=\"10\" alt=\"\"></td><td>\n";
    print STDOUT $q->hidden(-name => 'c',
			    -id => 'c'),
    $q->hidden(-name => 'geo',
	       -default => 'zip',
	       -id => 'geo'),
    "<b>Candle lighting times</b>\n";

    print STDOUT "<br><small>[\n";
    foreach my $type ('none', 'zip', 'city', 'pos')
    {
	if ($type eq $q->param('geo')) {
	    print STDOUT $long_candles_text{$type};
	} else {
	    print STDOUT alt_candles_text($q, $type);
	}
	if ($type ne 'pos') {
	    print STDOUT "\n| ";
	}
    }
    print STDOUT "\n]</small><br><br>\n";

    if ($q->param('geo') eq 'city')
    {
	print STDOUT
	"<label\nfor=\"city\">Large City:</label>\n",
	$q->popup_menu(-name => 'city',
		       -id => 'city',
		       -values => [sort keys %Hebcal::city_tz],
		       -default => 'New York');
    }
    elsif ($q->param('geo') eq 'pos')
    {
	print STDOUT "<small><a href=\"$latlong_url\">Search</a>\n",
	"for the exact location of your city.</small><br><br>\n";

	print STDOUT
	"<label\nfor=\"ladeg\">",
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
	"<label\nfor=\"lodeg\">",
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
				   'w' => 'West Longitude'});
    }
    elsif ($q->param('geo') ne 'none')
    {
	# default is Zip Code

	print STDOUT "<label\nfor=\"zip\">Zip code:</label>\n",
	$q->textfield(-name => 'zip',
		      -id => 'zip',
		      -size => 5,
		      -maxlength => 5);
#	print STDOUT "\n&nbsp;<small>(leave blank to turn off)</small>\n";
    }

    if ($q->param('geo') eq 'pos' || $q->param('tz_override'))
    {
	print STDOUT "<br><label for=\"tz\">Time zone:</label>\n",
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
	"<br><label for=\"dst\">Daylight Saving Time:</label>\n",
	$q->popup_menu(-name => 'dst',
		       -id => 'dst',
		       -values => ['usa','eu','israel','none'],
		       -default => 'none',
		       -labels => \%Hebcal::dst_names);
    }

    if ($q->param('geo') ne 'none') {
    print STDOUT "<br><label\nfor=\"m\">",
    "Havdalah minutes past sundown:</label>\n",
    $q->textfield(-name => 'm',
		  -id => 'm',
		  -size => 3,
		  -maxlength => 3,
		  -default => $Hebcal::havdalah_min),
    "\n<br>&nbsp;&nbsp;<small>(enter \"0\" to turn off Havdalah times)</small>\n",
    "\n";
    }

    print STDOUT "</td></tr></table>\n",
    $q->submit(-name => '.s',-value => 'Get Calendar'),
    $q->hidden(-name => '.cgifields',
	       -values => ['nx', 'nh', 'set'],
	       '-override'=>1),
    "</form>\n";

    print STDOUT Hebcal::html_footer($q,$rcsrev);

    exit(0);
    1;
}


sub results_page
{
    my($date,$filename) = @_;
    my($prev_url,$next_url,$prev_title,$next_title);

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
	my($newcookie) = Hebcal::gen_cookie($q);
	if (! $C_cookie)
	{
	    print STDOUT "Cache-Control: private\015\012",
	    "Set-Cookie: ", $newcookie, "; expires=",
	    $expires_future, "; path=/\015\012"
		if $newcookie =~ /&/;
	}
	else
	{
	    my($cmp1) = $newcookie;
	    my($cmp2) = $C_cookie;

	    $cmp1 =~ s/^C=t=\d+\&?//;
	    $cmp2 =~ s/^C=t=\d+\&?//;

	    print STDOUT "Cache-Control: private\015\012",
	    "Set-Cookie: ", $newcookie, "; expires=",
	    $expires_future, "; path=/\015\012"
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

	$prev_url = Hebcal::self_url($q, {'year' => $py, 'month' => $pm});
	$prev_title = sprintf("%s %04d", $Hebcal::MoY_long{$pm}, $py);

	$next_url = Hebcal::self_url($q, {'year' => $ny, 'month' => $nm});
	$next_title = sprintf("%s %04d", $Hebcal::MoY_long{$nm}, $ny);
    }
    else
    {
	$prev_url = Hebcal::self_url($q, {'year' => ($q->param('year') - 1)});
	$prev_title = sprintf("%04d", ($q->param('year') - 1));

	$next_url = Hebcal::self_url($q, {'year' => ($q->param('year') + 1)});
	$next_title = sprintf("%04d", ($q->param('year') + 1));
    }

    my($goto_prefix) = "<p class=\"goto\"><b>" .
	"<a title=\"$prev_title\"\nhref=\"$prev_url\">&lt;&lt;</a>\n" .
	$date . "\n" .
	"<a title=\"$next_title\"\nhref=\"$next_url\">&gt;&gt;</a></b>";

    my($charset) = ($q->param('heb') && $q->param('heb') =~ /^on|1$/)
	? '; charset=UTF-8' : '';

    my @head = (
		$q->Link({-rel => 'prev',
			  -href => $prev_url,
			  -title => $prev_title}),
		$q->Link({-rel => 'next',
			  -href => $next_url,
			  -title => $next_title}),
		$q->Link({-rel => 'start',
			  -href => $script_name,
			  -title => 'Hebcal Interactive Jewish Calendar'}),
		);

    if ($charset) {
	push(@head, qq{<meta http-equiv="Content-Type" content="text/html${charset}">});
    }

    print STDOUT $q->header(-expires => $expires_date,
			    -type => "text/html${charset}"),
    Hebcal::start_html($q, "Hebcal: Jewish Calendar $date",
		       \@head,
		       undef,
		       undef
			),
    Hebcal::navbar2($q, $date, 1,
		     "Interactive\nCalendar", Hebcal::self_url($q, {'v' => '0'}));

    print STDOUT "<h1>Jewish\nCalendar $date</h1>\n"
	unless ($q->param('vis'));

    my($loc2) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc2 =~ s/\s*&nbsp;\s*/ /g;

    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename
    print STDOUT "<!-- $cmd_pretty -->\n";

    my(@events) = Hebcal::invoke_hebcal($cmd, $loc2,
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
	$geographic_info = "<h3>" . $city_descr . "</h3>\n";
	$geographic_info .= $lat_descr . "<br>\n"
	    if $lat_descr ne '';
	$geographic_info .= $long_descr . "<br>\n"
	    if $long_descr ne '';
	$geographic_info .= $dst_tz_descr . "<br>\n"
	    if $dst_tz_descr ne '';
    }

    print STDOUT $geographic_info;

    print STDOUT $Hebcal::indiana_warning
	if ($city_descr =~ / IN &nbsp;/);

    # toggle month/full year and event list/calendar grid
    $goto_prefix .= "\n&nbsp;&nbsp;&nbsp; ";

    my($goto) = "<small>change view: [ ";

    if ($q->param('vis'))
    {
	$goto .= "<a\nhref=\"" . Hebcal::self_url($q, {'vis' => '0'}) .
	    "\">event\nlist</a> | <b>calendar grid</b> ]";
    }
    else
    {
	$goto .= "<b>event list</b> | <a\nhref=\"" .
	    Hebcal::self_url($q, {'vis' => 'on'}) . "\">calendar\ngrid</a> ]";
    }

    if ($q->param('yt') && $q->param('yt') eq 'H')
    {
	$goto .= "\n";
    }
    else
    {
    $goto .= "\n&nbsp;&nbsp;&nbsp; [ ";

    if ($date !~ /^\d+$/)
    {
	$goto .= "<b>month</b> | " .
	    "<a\nhref=\"" . Hebcal::self_url($q, {'month' => 'x'}) .
	    "\">entire\nyear</a> ]";
    }
    else
    {
	$goto .= "<a\nhref=\"" . Hebcal::self_url($q, {'month' => '1'}) .
	    "\">month</a> |\n<b>entire year</b> ]";
    }
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
 		Hebcal::url_escape($q->param('city')),
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
	print STDOUT qq{<p class="goto"><span class="sm-grey">&gt;</span>
<a href="#export">Export calendar to Palm, Outlook, iCal, etc.</a></p>\n};
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
	    = Hebcal::get_holiday_anchor($subj,0,undef);
	if ($hebrew ne '' && defined $q->param('heb') &&
	    $q->param('heb') =~ /^on|1$/)
	{
	    $subj .= qq{\n/ <span dir="rtl" lang="he" class="hebrew">$hebrew</span>};
	}

	if (defined $href && $href ne '')
	{
	    $subj = qq{<a href="$href">$subj</a>};
	}

	my($dow) = $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)] . ' ';

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
		$cal->width('97%');
		$cal->border(1);
		$cal->bgcolor('white');
		$cal->bordercolor('');
		$cal->contentcolor('black');
		$cal->todaybordercolor('red');

		$cal->header("<h2 align=\"center\"><a class=\"goto\" title=\"$prev_title\"\n" .
			     "href=\"$prev_url\">&lt;&lt;</a>\n" .
			     sprintf("%s %04d\n",
 				     $Hebcal::MoY_long{$mon}, $year) .
			     "<a class=\"goto\" title=\"$next_title\"\n" .
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
	    "</center>\n";
    }

    print STDOUT "</p>" unless $q->param('vis');
    print STDOUT $goto_prefix, $goto, "</p>";
    if ($numEntries > 0) {
	print STDOUT Hebcal::download_html($q, $filename, \@events, $date);
    }
    print STDOUT Hebcal::html_footer($q,$rcsrev);

    1;
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
#	$q->param('tz',$Hebcal::city_tz{$q->param('city')});
	$q->delete('tz');
	$q->delete('dst');
	$q->delete('zip');
	$q->delete('lodeg');
	$q->delete('lomin');
	$q->delete('ladeg');
	$q->delete('lamin');
	$q->delete('lodir');
	$q->delete('ladir');

	$city_descr = "Large City: " . $q->param('city');
	$cmd_extra = " -C '" . $q->param('city') . "'";

	if ($Hebcal::city_dst{$q->param('city')} eq 'israel')
	{
	    $q->param('i','on');
	}
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
	    $q->param('c','off');
	    $q->delete('zip');
	    $q->delete('city');
	    $q->param('geo','pos');
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
	my $dst_text = ($q->param('dst') eq 'none') ? 'none' :
	    'automatic for ' . $Hebcal::dst_names{$q->param('dst')};
	$dst_tz_descr = "Time zone: " . $Hebcal::tz_names{$q->param('tz')} .
	    "\n<br>Daylight Saving Time: $dst_text";

	# don't multiply minutes by -1 since hebcal does it internally
	$long_deg *= -1  if ($q->param('lodir') eq 'e');
	$lat_deg  *= -1  if ($q->param('ladir') eq 's');

	$cmd_extra = " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    }
    elsif ($q->param('c') && $q->param('c') ne 'off' &&
	   defined $q->param('zip') && $q->param('zip') ne '')
    {
	$q->param('geo','zip');

	&form("Sorry, <b>" . $q->param('zip') . "</b> does\n" .
	      "not appear to be a 5-digit zip code.")
	    unless $q->param('zip') =~ /^\d\d\d\d\d$/;

	my $DB = Hebcal::zipcode_open_db();
	my($val) = $DB->{$q->param('zip')};
	Hebcal::zipcode_close_db($DB);
	undef($DB);

	&form("Sorry, can't find\n".  "<b>" . $q->param('zip') .
	      "</b> in the zip code database.\n",
	      "<ul><li>Please try a nearby zip code or select candle\n" .
	      "lighting times by\n" .
	      "<a href=\"" . $script_name .
	      "?c=on;geo=city\">city</a> or\n" .
	      "<a href=\"" . $script_name .
	      "?c=on;geo=pos\">latitude/longitude</a></li></ul>")
	    unless defined $val;

	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    	Hebcal::zipcode_fields($val);

	# allow CGI args to override
	$tz = $q->param('tz')
	    if (defined $q->param('tz') && $q->param('tz') =~ /^-?\d+$/);

	$city_descr = "$city, $state &nbsp;" . $q->param('zip');

	if ($tz eq '?')
	{
	    $q->param('tz_override', '1');

	    &form("Sorry, can't auto-detect\n" .
		  "timezone for <b>" . $city_descr . "</b>\n",
		  "<ul><li>Please select your time zone below.</li></ul>");
	}

	$q->param('tz', $tz);

	# allow CGI args to override
	if (defined $q->param('dst'))
	{
	    $dst = 0 if $q->param('dst') eq 'none';
	    $dst = 1 if $q->param('dst') eq 'usa';
	}

	if ($dst eq '1')
	{
	    $q->param('dst','usa');
	}
	else
	{
	    $q->param('dst','none');
	}

#	$lat_descr  = "${lat_deg}d${lat_min}' N latitude";
#	$long_descr = "${long_deg}d${long_min}' W longitude";
	my $dst_text = ($q->param('dst') eq 'none') ? 'none' :
	    'automatic for ' . $Hebcal::dst_names{$q->param('dst')};
	$dst_tz_descr = "Time zone: " . $Hebcal::tz_names{$q->param('tz')} .
	    "\n<br>Daylight Saving Time: $dst_text";

	$cmd_extra = " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    }
    else
    {
	$q->param('c','off');
	$q->delete('zip');
	$q->delete('city');
#	$q->param('geo', 'none');
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
