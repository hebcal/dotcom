#!/usr/local/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
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

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use Time::Local ();
use Date::Calc ();
use Hebcal ();
use HebcalGPL ();
use HTML::CalendarMonthSimple ();
use Palm::DBA ();

my $http_expires = "Tue, 02 Jun 2037 20:00:00 GMT";
my $cookie_expires = "Tue, 02-Jun-2037 20:00:00 GMT";
my $content_type = "text/html; charset=UTF-8";

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

my $rcsrev = '$Revision$'; #'

my $latlong_url = "http://www.getty.edu/research/tools/vocabulary/tgn/";
my %long_candles_text =
    ("pos" => "latitude/longitude",
     "city" => "large cities",
     "zip" => "zip code",
     "none" => "none");

my $cmd  = "./hebcal";

# process form params
my $q = new CGI;

$q->delete(".s");		# we don't care about submit button

my $script_name = $q->script_name();
$script_name =~ s,/[^/]+$,/,;

my $cookies = Hebcal::get_cookies($q);
my $C_cookie = (defined $cookies->{"C"}) ? "C=" . $cookies->{"C"} : "";
if (! $q->param("v") && $C_cookie)
{
    Hebcal::process_cookie($q,$C_cookie);
}

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
foreach my $key ($q->param())
{
    my $val = $q->param($key);
    $val = "" unless defined $val;
    $val =~ s/[^\w\.\s-]//g;
    $val =~ s/^\s+//g;		# nuke leading
    $val =~ s/\s+$//g;		# and trailing whitespace
    $q->param($key,$val);
}

# decide whether this is a results page or a blank form
form("") unless $q->param("v");

if (defined $q->param("year") && $q->param("year") eq "now" &&
    defined $q->param("month") && 
    (($q->param("month") eq "now") || ($q->param("month") eq "x")))
{
    $q->param("year", $this_year);
    $q->param("month", $this_mon)
	if $q->param("month") eq "now";

    my $end_day = Date::Calc::Days_in_Month($this_year, $this_mon);
    my $end_of_month =
	Time::Local::timelocal(59,59,23,
			       $end_day,
			       $this_mon - 1,
			       $this_year - 1900);

    $http_expires = Hebcal::http_date($end_of_month);
}

form("Please specify a year.")
    if !defined $q->param("year") || $q->param("year") eq "";

form("Sorry, invalid year\n<b>" . $q->param("year") . "</b>.")
    if $q->param("year") !~ /^\d+$/ || $q->param("year") == 0;

form("Sorry, Hebrew year must be 3762 or later.")
    if $q->param("yt") && $q->param("yt") eq "H" && $q->param("year") < 3762;

form("Sorry, invalid Havdalah minutes\n<b>" . $q->param("m") . "</b>.")
    if defined $q->param("m") &&
    $q->param("m") ne "" && $q->param("m") !~ /^\d+$/;

$q->param("c","on")
    if (defined $q->param("zip") && $q->param("zip") =~ /^\d{5}$/);

form("Please select at least one event option.")
    if ((!defined $q->param("nh") || $q->param("nh") eq "off") &&
	(!defined $q->param("nx") || $q->param("nx") eq "off") &&
	(!defined $q->param("o") || $q->param("o") eq "off") &&
	(!defined $q->param("c") || $q->param("c") eq "off") &&
	(!defined $q->param("d") || $q->param("d") eq "off") &&
	(!defined $q->param("s") || $q->param("s") eq "off"));

my($cmd_extra,$cconfig) =
    get_candle_config($q);

$cmd .= $cmd_extra if $cmd_extra;

foreach (@Hebcal::opts)
{
    $cmd .= " -" . $_
	if defined $q->param($_) && $q->param($_) =~ /^on|1$/
}

$cmd .= " -a"
    if defined $q->param("lg") && $q->param("lg") =~ /^a/;
$cmd .= " -h" if !defined $q->param("nh") || $q->param("nh") eq "off";
$cmd .= " -x" if !defined $q->param("nx") || $q->param("nx") eq "off";

if (param_true("c"))
{
    $cmd .= " -m " . $q->param("m")
	if (defined $q->param("m") && $q->param("m") =~ /^\d+$/);

    $cmd .= " -z " . $q->param("tz")
	if (defined $q->param("tz") && $q->param("tz") ne "");

    $cmd .= " -Z " . $q->param("dst")
	if (defined $q->param("dst") && $q->param("dst") ne "");
}

if ($q->param("yt") && $q->param("yt") eq "H")
{
    $q->param("month", "x");
    $cmd .= " -H";
}

$q->param("month", "x")
    if (defined $q->param("cfg") && $q->param("cfg") eq "e");

my $g_month;

if (defined $q->param("month") && $q->param("month") =~ /^\d{1,2}$/ &&
    $q->param("month") >= 1 && $q->param("month") <= 12)
{
    my $m = $q->param("month");
    $m =~ s/^0//;
    $q->param("month", $m);
    $g_month = $m;
}
else
{
    $q->param("month", "x");
}

$cmd .= " " . $q->param("year");

my $g_date;
my $g_filename = "hebcal_" . $q->param("year");
$g_filename .= "H"
    if $q->param("yt") && $q->param("yt") eq "H";
if (defined $q->param("month") && defined $q->param("year") &&
    $q->param("month") =~ /^\d{1,2}$/ &&
    $q->param("month") >= 1 && $q->param("month") <= 12)
{
    $g_filename .= "_" . lc($Hebcal::MoY_short[$q->param("month")-1]);
    $g_date = sprintf("%s %04d", $Hebcal::MoY_long{$q->param("month")},
		    $q->param("year"));
}
else
{
    $g_date = sprintf("%s%04d",
		    ($q->param("yt") && $q->param("yt") eq "H") ?
		    "Hebrew Year " : "",
		    $q->param("year"));
}

my $pi = $q->path_info();

my $g_loc = (defined $cconfig->{"city"} && $cconfig->{"city"} ne "") ?
    "in " . $cconfig->{"city"} : "";
my $g_seph = (defined $q->param("i") && $q->param("i") =~ /^on|1$/) ? 1 : 0;
my $g_nmf = (defined $q->param("mf") && $q->param("mf") =~ /^on|1$/) ? 0 : 1;
my $g_nss = (defined $q->param("ss") && $q->param("ss") =~ /^on|1$/) ? 0 : 1;

if (! defined $pi)
{
#    my $cache = Hebcal::cache_begin($q);
    results_page($g_date, $g_filename);
#    Hebcal::cache_end() if $cache;
}
elsif ($pi =~ /[^\/]+\.csv$/)
{
    csv_display();
}
elsif ($pi =~ /[^\/]+\.dba$/)
{
    dba_display();
}
elsif ($pi =~ /[^\/]+\.tsv$/)
{
    macintosh_datebook_display();
}
elsif ($pi =~ /[^\/]+\.[vi]cs$/)
{
    vcalendar_display($g_date);
}
elsif (defined $q->param("cfg") && $q->param("cfg") eq "e")
{
    javascript_events(0);
}
elsif (defined $q->param("cfg") && $q->param("cfg") eq "e2")
{
    javascript_events(1);
}
elsif (defined $q->param("cfg") && $q->param("cfg") eq "json")
{
    json_events();
}
else
{
#    my $cache = Hebcal::cache_begin($q);
    results_page($g_date, $g_filename);
#    Hebcal::cache_end() if $cache;
}

close(STDOUT);
exit(0);

sub param_true
{
    my($k) = @_;
    my $v = $q->param($k);
    return ((defined $v) && ($v ne "off") && ($v ne "0") && ($v ne "")) ? 1 : 0;
}

sub json_events
{
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);
    my $items = Hebcal::events_to_dict(\@events,"json",$q,0,0);

    print STDOUT $q->header(-type => "text/json",
			    -charset => "UTF-8",
			    );

    Hebcal::items_to_json($items,$q,"Hebcal");
}

sub javascript_events
{
    my($v2) = @_;
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);
    my $cmd2 = $cmd;
    $cmd2 =~ s/(\d+)$/$1+1/e;
    my @ev2 = Hebcal::invoke_hebcal($cmd2, $g_loc, $g_seph, undef,
				    $g_nmf, $g_nss);
    push(@events, @ev2);

    my $time = defined $ENV{"SCRIPT_FILENAME"} ?
	(stat($ENV{"SCRIPT_FILENAME"}))[9] : time;

    print STDOUT $q->header(-type => "text/javascript",
			    -charset => "UTF-8",
			    -last_modified => Hebcal::http_date($time),
			    -expires => $http_expires,
			    );

    if ($v2) {
	print STDOUT <<EOJS;
if(typeof HEBCAL=="undefined"||!HEBCAL){var HEBCAL={};}
HEBCAL.eraw=[
EOJS
;
    }
    my $first = 1;
    for (my $i = 0; $i < @events; $i++)
    {
	my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];

	my $min = $events[$i]->[$Hebcal::EVT_IDX_MIN];
	my $hour = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $year = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	my $mon = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $mday = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

	my $img_url = "";
	my $img_w = 0;
	my $img_h = 0;

	if ($q->param("img"))
	{
	    if ($subj =~ /^Candle lighting/)
	    {
		$img_url = "http://www.hebcal.com/i/sm_candles.gif";
		$img_w = 40;
		$img_h = 69;
	    }
	    elsif ($subj =~ /Havdalah/)
	    {
		$img_url = "http://www.hebcal.com/i/havdalah.gif";
		$img_w = 46;
		$img_h = 59;
	    }
	}

	my($href,$hebrew,$memo) = Hebcal::get_holiday_anchor($subj,0,$q);

	$subj = translate_subject($q,$subj,$hebrew);

	if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    $subj = sprintf("<b>%d:%02dp</b> %s", $hour, $min, $subj);
	}

	if ($v2) {
	    print STDOUT "," unless $first;
	    $first = 0;
	    printf STDOUT "{d:%04d%02d%02d,s:\"%s\"",
	    $year, $mon, $mday, $subj;
	    if ($href) {
		my $href2 = $href;
		$href2 =~ s,^http://www.hebcal.com/,,;
		$href2 =~ s/\.html$//;
		print STDOUT ",a:\"$href2\"";
	    }
	    if ($img_url) {
		printf STDOUT ",is:\"%s\",iw:%d,ih:%d",
	    	$img_url, $img_w, $img_h;
	    }
	    print STDOUT "}";
	} else {
	    #DefineEvent(EventDate,EventDescription,EventLink,Image,Width,Height)
	    if ($href && $href =~ /\.html$/) {
		$href .= "?tag=js.cal";
	    }
	    printf("DefineEvent(%04d%02d%02d,\"%s\",\"%s\",\"%s\",%d,%d);\015\012",
		   $year, $mon, $mday, $subj, $href, $img_url, $img_w, $img_h);
	}
    }
    if ($v2) {
	print STDOUT <<EOJS;
];
HEBCAL.jec2events=[];
for (var i=0;i<HEBCAL.eraw.length;i++){
var e=HEBCAL.eraw[i],f={eventDate:e.d,eventDescription:e.s};
if(e.a){f.eventLink="http://www.hebcal.com/"+e.a+".html?tag=js.cal"}
HEBCAL.jec2events.push(f);}
EOJS
;
    }
}

sub translate_subject
{
    my($q,$subj,$hebrew) = @_;

    my $lang = $q->param("lg") || "s";
    if ($lang eq "s" || $lang eq "a" || !$hebrew) {
	return $subj;
    } elsif ($lang eq "h") {
	return hebrew_span($hebrew);
    } elsif ($lang eq "ah" || $lang eq "sh") {
	my $subj2 = $subj;
	$subj2 .= $q->param("vis") ? "\n<br>" : "\n/ ";
	$subj2 .= hebrew_span($hebrew);
	return $subj2;
    } else {
	die "unknown lang \"$lang\" for $subj";
    }
}

sub hebrew_span
{
    my($hebrew) = @_;
    return qq{<span dir="rtl" lang="he" class="hebrew">$hebrew</span>};
}

sub macintosh_datebook_display
{
    my @events = Hebcal::invoke_hebcal($cmd, "", $g_seph, $g_month,
				       $g_nmf, $g_nss);

    Hebcal::macintosh_datebook($q, \@events);
}

sub vcalendar_display
{
    my($date) = @_;

    my $title = $date;
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    if (defined $q->param("month") && $q->param("month") eq "x")
    {
	for (my $i = 1; $i < 5; $i++)
	{
	    my $cmd2 = $cmd;
	    $cmd2 =~ s/(\d+)$/$1+$i/e;
	    my @ev2 = Hebcal::invoke_hebcal($cmd2, $g_loc, $g_seph, undef,
					    $g_nmf, $g_nss);
	    push(@events, @ev2);
	}
	if ($date =~ /(\d+)/) {
	    my $plus4 = $1 + 4;
	    $title .= "-" . $plus4;
	}
    }

    my $tz = $q->param("tz");
    my $state;

    if (defined $q->param("geo") && $q->param("geo") eq "city" &&
	defined $q->param("city") && $q->param("city") ne "")
    {
	$tz = $Hebcal::city_tz{$q->param("city")};
    }
    elsif (defined $cconfig->{"state"})
    {
	$state = $cconfig->{"state"};
    }

    Hebcal::vcalendar_write_contents($q, \@events, $tz, $state, $title, $cconfig);
}

sub dba_display
{
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    my $dst = (defined($q->param("dst")) && $q->param("dst") eq "usa") ? 1 : 0;
    my $tz = $q->param("tz");

    if (defined $q->param("geo") && $q->param("geo") eq "city" &&
	defined $q->param("city") && $q->param("city") ne "")
    {
	$dst = $Hebcal::city_dst{$q->param("city")} eq "usa" ? 1 : 0;
	$tz = $Hebcal::city_tz{$q->param("city")};
    }

    Hebcal::export_http_header($q, "application/x-palm-dba");

    my $basename = $q->path_info();
    $basename =~ s,^.*/,,;
    Palm::DBA::write_header($basename);
    Palm::DBA::write_contents(\@events, $tz, $dst);
}

sub csv_display
{
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    my $euro = defined $q->param("euro") ? 1 : 0;
    Hebcal::csv_write_contents($q, \@events, $euro);
}

sub alt_candles_text
{
    my($q,$geo) = @_;

    my $text = $long_candles_text{$geo};
    my $c = ($geo eq "none") ? "off" : "on";
    $q->a({-href => $script_name . "?c=$c;geo=" . $geo,
	   -onClick => "return s1('" . $geo . "', '" . $c . "')" },
	  $text);
}

sub form
{
    my($message,$help) = @_;

    my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
    my $hyear = $hebdate->{"yy"};
    $hyear++ if $hebdate->{"mm"} == 6; # Elul

    print STDOUT $q->header(-type => $content_type);

    my $xtra_head = <<EOHTML;
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,sedrot,parsha">
<meta name="description" content="Personalized Jewish calendar for any year 0001-9999 includes Jewish holidays, candle lighting times, Torah readings. Export to Outlook, Apple iCal, Google, Palm, etc.">
<style type="text/css">
.entry-content fieldset {
border:1px solid #E7E7E7;
margin:0 0 12px;
padding:6px;
}
.entry-content input, .entry-content select {
margin:0;
}
form ol {
list-style:none inside none;
margin:0 0 12px 12px;
}
#hebcal-form-left { float:left; width:48%;}
#hebcal-form-right { float:right; width:48%;}
#hebcal-form-bottom { clear:both; }
</style>
EOHTML
;

    Hebcal::out_html(undef,
		     Hebcal::html_header("Custom Calendar",
					 $script_name,
					 "single single-post",
					 $xtra_head)
	);
    my $head_divs = <<EOHTML;
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">Custom Calendar</h1>
<div class="entry-content">
EOHTML
;
    Hebcal::out_html(undef, $head_divs);

    if ($message ne "")
    {
	$help = "" unless defined $help;
	$message = "<hr noshade size=\"1\"><p\nstyle=\"color: red\">" .
	    $message . "</p>" . $help . "<hr noshade size=\"1\">";
    }

    Hebcal::out_html(undef,
    $message, "\n",
    qq{<p>Select your calendar options and click the <b>Preview
Calendar</b> button at the bottom of the form. Once you have created
your custom calendar, you can export to Outlook, iCal, Google Calendar,
and other applications.</p>},
    "<div id=\"form\">",
    "<form id=\"f1\" name=\"f1\"\naction=\"",
    $script_name, "\">",
    qq{<div id="hebcal-form-left">\n},
    qq{<fieldset><legend>Jewish Holidays for</legend>\n},
    "<ol><li><label for=\"year\">Year:\n",
    $q->textfield(-name => "year",
		  -id => "year",
		  -default => $this_year,
		  -size => 4,
		  -maxlength => 4),
    "</label>\n",
    "<ol><li>",
    $q->radio_group(-name => "yt",
		    -values => ["G", "H"],
		    -default => "G",
		    -onClick => "s6(this.value)",
		    -labels =>
		    {"G" => " Gregorian (common era) ",
		     "H" => " Hebrew Year"}),
    "\n<li>", $q->small("Use all digits to specify a year.\nYou probably aren't",
			"interested in 08, but rather 2008.\n"),
    "</ol>",
    "</ol>\n",
    $q->hidden(-name => "month", -value => "x"),
    $q->hidden(-name => "v",-value => 1,-override => 1),
    qq{</fieldset>\n}
    );

    Hebcal::out_html(undef, qq{<fieldset><legend>Include events</legend>\n});
    Hebcal::out_html(undef,
    "<ol><li><label\nfor=\"nh\">",
    $q->checkbox(-name => "nh",
		 -id => "nh",
		 -checked => 1,
		 -label => "\nAll default Holidays"),
    "</label> <small>(<a\n",
    "href=\"/holidays/\">What\n",
    "are the default Holidays?</a>)</small>",
    "<li><label\nfor=\"nx\">",
    $q->checkbox(-name => "nx",
		 -id => "nx",
		 -checked => 1,
		 -label => "\nRosh Chodesh"),
    "</label>",
    "<li><label\nfor=\"mf\">",
    $q->checkbox(-name => "mf",
		 -id => "mf",
		 -checked => 1,
		 -label => "\nMinor Fasts"),
    "</label> <small>(Ta'anit Esther, Tzom Gedaliah, etc.)</small>",
    "<li><label\nfor=\"ss\">",
    $q->checkbox(-name => "ss",
		 -id => "ss",
		 -checked => 1,
		 -label => "\nSpecial Shabbatot"),
    "</label> <small>(Shabbat Shekalim, Shabbat Zachor, etc.)</small>",
    "<li><label\nfor=\"o\">",
    $q->checkbox(-name => "o",
		 -id => "o",
		 -label => "\nDays of the Omer"),
    "</label>",
    "<li><label\nfor=\"s\">",
    $q->checkbox(-name => "s",
		 -id => "s",
		 -label => "\nWeekly sedrot on Saturdays"),
    "</label>\n",
    "<ol><li>\n",
    $q->radio_group(-name => "i",
		    -values => ["off", "on"],
		    -default => "off",
		    -labels =>
		    {"off" => "\nDiaspora ",
		     "on" => "\nIsrael "}),
    "\n&nbsp;<small>(<a\n",
    "href=\"/home/51/what-is-the-differerence-between-the-diaspora-and-israeli-sedra-schemes\">What\n",
    "is the difference?</a>)</small></ol>");

    Hebcal::out_html(undef,
    "<li><label\nfor=\"lg\">Event titles: </label>\n",
    $q->popup_menu(-name => "lg",
		   -id => "lg",
		   -values => ["s", "sh", "a", "ah", "h"],
		   -default => "s",
		   -labels => \%Hebcal::lang_names));

    Hebcal::out_html(undef, qq{</ol></fieldset>\n});
    Hebcal::out_html(undef, qq{</div><!-- #hebcal-form-left -->\n});

    Hebcal::out_html(undef, qq{<div id="hebcal-form-right">\n});
    Hebcal::out_html(undef,
    "<fieldset><legend>Other options</legend>",
    "<ol><li><label\nfor=\"vis\">",
    $q->checkbox(-name => "vis",
		 -id => "vis",
		 -checked => 1,
		 -label => "\nDisplay visual calendar grid"),
    "</label>",
    "<li><label\nfor=\"Dsome\">",
    $q->checkbox(-name => "D",
		 -id => "Dsome",
		 -label => "\nShow Hebrew date for dates with some event"),
    "</label>",
    "<li><label\nfor=\"dentire\">",
    $q->checkbox(-name => "d",
		 -id => "dentire",
		 -label => "\nShow Hebrew date for entire date range"),
    "</label>",
    "</ol></fieldset>\n");

    Hebcal::out_html(undef, qq{<fieldset><legend>Candle lighting times</legend>\n});
    $q->param("c","off") unless defined $q->param("c");
    $q->param("geo","zip") unless defined $q->param("geo");

    Hebcal::out_html(undef,
    $q->hidden(-name => "c",
	       -id => "c"),
    $q->hidden(-name => "geo",
	       -default => "zip",
	       -id => "geo"),
    "\n");

    Hebcal::out_html(undef, "<ol><li>Specify by: <small>[\n");
    foreach my $type ("none", "zip", "city", "pos")
    {
	if ($type eq $q->param("geo")) {
	    Hebcal::out_html(undef, $long_candles_text{$type});
	} else {
	    Hebcal::out_html(undef, alt_candles_text($q, $type));
	}
	if ($type ne "pos") {
	    Hebcal::out_html(undef, "\n| ");
	}
    }
    Hebcal::out_html(undef, "\n]</small>\n");

    if ($q->param("geo") eq "city")
    {
	Hebcal::out_html(undef,
	"<li><label\nfor=\"city\">Large City:</label>\n",
	$q->popup_menu(-name => "city",
		       -id => "city",
		       -values => [sort keys %Hebcal::city_tz],
		       -default => "New York"));
    }
    elsif ($q->param("geo") eq "pos")
    {
	Hebcal::out_html(undef,
	"<li><label\nfor=\"ladeg\">",
	$q->textfield(-name => "ladeg",
		      -id => "ladeg",
		      -size => 3,
		      -maxlength => 2),
	"&nbsp;deg</label>&nbsp;&nbsp;\n",
	"<label for=\"lamin\">",
	$q->textfield(-name => "lamin",
		      -id => "lamin",
		      -size => 2,
		      -maxlength => 2),
	"&nbsp;min</label>&nbsp;\n",
	$q->popup_menu(-name => "ladir",
		       -id => "ladir",
		       -values => ["n","s"],
		       -default => "n",
		       -labels => {"n" => "North Latitude",
				   "s" => "South Latitude"}),
	"<li><label\nfor=\"lodeg\">",
	$q->textfield(-name => "lodeg",
		      -id => "lodeg",
		      -size => 3,
		      -maxlength => 3),
	"&nbsp;deg</label>&nbsp;&nbsp;\n",
	"<label for=\"lomin\">",
	$q->textfield(-name => "lomin",
		      -id => "lomin",
		      -size => 2,
		      -maxlength => 2),
	"&nbsp;min</label>&nbsp;\n",
	$q->popup_menu(-name => "lodir",
		       -id => "lodir",
		       -values => ["w","e"],
		       -default => "w",
		       -labels => {"e" => "East Longitude",
				   "w" => "West Longitude"}));
	Hebcal::out_html(undef,
	"<ol><li><small><a href=\"$latlong_url\">Search</a>\n",
	"for the exact location of your city.</small></ol>\n");
    }
    elsif ($q->param("geo") ne "none")
    {
	# default is Zip Code
	Hebcal::out_html(undef,
	"<li><label\nfor=\"zip\">Zip code:</label>\n",
	$q->textfield(-name => "zip",
		      -id => "zip",
		      -size => 5,
		      -maxlength => 5));
    }

    if ($q->param("geo") eq "pos" || $q->param("tz_override"))
    {
	Hebcal::out_html(undef,
	"<li><label for=\"tz\">Time zone:</label>\n",
	$q->popup_menu(-name => "tz",
		       -id => "tz",
		       -values =>
		       (defined $q->param("geo") && $q->param("geo") eq "pos")
		       ? [-5,-6,-7,-8,-9,-10,-11,-12,
			  12,11,10,9,8,7,6,5,4,3,2,1,0,
			  -1,-2,-3,-4]
		       : ["auto",-5,-6,-7,-8,-9,-10],
		       -default =>
		       (defined $q->param("geo") && $q->param("geo") eq "pos")
		       ? 0 : "auto",
		       -labels => \%Hebcal::tz_names),
	"<li><label for=\"dst\">Daylight Saving Time:</label>\n",
	$q->popup_menu(-name => "dst",
		       -id => "dst",
		       -values => ["usa","mx","eu","israel","aunz","none"],
		       -default => "none",
		       -labels => \%Hebcal::dst_names));
    }

    if ($q->param("geo") ne "none") {
	Hebcal::out_html(undef,
	"<li><label\nfor=\"m\">",
	"Havdalah minutes past sundown:</label>\n",
	$q->textfield(-name => "m",
		      -id => "m",
		      -size => 3,
		      -maxlength => 3,
		      -default => $Hebcal::havdalah_min),
	"<ol><li><small>(enter\n\"0\" to turn off Havdalah\n",
	"times)</small></ol>\n");

	Hebcal::out_html(undef, "<li><small><a\n",
			 "href=\"/home/94/how-accurate-are-candle-lighting-times\">How\n",
			 "accurate are these times?</a></small>");
    }

    Hebcal::out_html(undef, qq{</ol></fieldset>\n});
    Hebcal::out_html(undef, qq{</div><!-- #hebcal-form-right -->\n});
    Hebcal::out_html(undef, qq{<div id="hebcal-form-bottom">\n});
    Hebcal::out_html(undef,
    $q->hidden(-name => ".cgifields",
	       -values => ["nx", "nh", "mf", "ss"],
	       "-override"=>1),
    "\n",
    $q->submit(-name => ".s",-value => "Preview Calendar"),
    qq{</div><!-- #hebcal-form-bottom -->\n},
    qq{</form>\n},
    qq{</div><!-- #form -->\n});

    my $js=<<JSCRIPT_END;
<script type="text/javascript">
var d=document;
function s1(geo,c){d.f1.geo.value=geo;d.f1.c.value=c;d.f1.v.value='0';
d.f1.submit();return false;}
function s6(val){
if(val=='G'){d.f1.year.value=$this_year}
if(val=='H'){d.f1.year.value=$hyear}
return false;}
d.getElementById("nh").onclick=function(){if(this.checked==false){d.f1.nx.checked=false;}}
d.getElementById("nx").onclick=function(){if(this.checked==true){d.f1.nh.checked=true;}}
d.getElementById("mf").onclick=function(){if(this.checked==true){d.f1.nh.checked=true;}}
d.getElementById("ss").onclick=function(){if(this.checked==true){d.f1.nh.checked=true;}}
</script>
JSCRIPT_END
	;
    Hebcal::out_html(undef, $js);

    my $footer_divs=<<EOHTML;
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOHTML
;
    Hebcal::out_html(undef, $footer_divs);
    Hebcal::out_html(undef, Hebcal::html_footer_new($q,$rcsrev,1));
    Hebcal::out_html(undef, "</body></html>\n");
    Hebcal::out_html(undef, "<!-- generated ", scalar(localtime), " -->\n");

    exit(0);
    1;
}

sub my_set_cookie
{
    my($str) = @_;
    if ($str =~ /&/) {
	print STDOUT "Cache-Control: private\015\012Set-Cookie: ",
    	$str, "; expires=", $cookie_expires, "; path=/\015\012";
    }
}

sub results_page
{
    my($date,$filename) = @_;
    my($prev_url,$next_url,$prev_title,$next_title);

    if (param_true("c"))
    {
	if (defined $q->param("zip"))
	{
	    $filename .= "_" . $q->param("zip");
	}
	elsif (defined $q->param("city"))
	{
	    my $tmp = lc($q->param("city"));
	    $tmp =~ s/[^\w]/_/g;
	    $filename .= "_" . $tmp;
	}
    }

    my $set_cookie = param_true("set") || ! defined $q->param("set");
    if ($set_cookie) {
	my $newcookie = Hebcal::gen_cookie($q);
	if (! $C_cookie)
	{
	    my_set_cookie($newcookie);
	}
	else
	{
	    my $cmp1 = $newcookie;
	    my $cmp2 = $C_cookie;

	    $cmp1 =~ s/^C=t=\d+\&?//;
	    $cmp2 =~ s/^C=t=\d+\&?//;

	    my_set_cookie($newcookie)
		if $cmp1 ne $cmp2;
	}
    }

    # next and prev urls
    if ($q->param("month") =~ /^\d{1,2}$/ &&
	$q->param("month") >= 1 && $q->param("month") <= 12)
    {
	my($pm,$nm,$py,$ny);

	if ($q->param("month") == 1)
	{
	    $pm = 12;
	    $nm = 2;
	    $py = $q->param("year") - 1;
	    $ny = $q->param("year");
	}
	elsif ($q->param("month") == 12)
	{
	    $pm = 11;
	    $nm = 1;
	    $py = $q->param("year");
	    $ny = $q->param("year") + 1;
	}
	else
	{
	    $pm = $q->param("month") - 1;
	    $nm = $q->param("month") + 1;
	    $ny = $py = $q->param("year");
	}

	$prev_url = Hebcal::self_url($q, {"year" => $py, "month" => $pm});
	$prev_title = sprintf("%s %04d", $Hebcal::MoY_long{$pm}, $py);

	$next_url = Hebcal::self_url($q, {"year" => $ny, "month" => $nm});
	$next_title = sprintf("%s %04d", $Hebcal::MoY_long{$nm}, $ny);
    }
    else
    {
	$prev_url = Hebcal::self_url($q, {"year" => ($q->param("year") - 1)});
	$prev_title = sprintf("%04d", ($q->param("year") - 1));

	$next_url = Hebcal::self_url($q, {"year" => ($q->param("year") + 1)});
	$next_title = sprintf("%04d", ($q->param("year") + 1));
    }

    my $results_title = "Jewish Calendar $date";
    if (defined $cconfig->{"city"} && $cconfig->{"city"} ne "") {
	$results_title .= " "  . $cconfig->{"city"};
    }

    print STDOUT $q->header(-expires => $http_expires,
			    -type => $content_type);

    my $xtra_head = <<EOHTML;
<style type="text/css">
.pbba { page-break-before: always }
div.cal { margin-bottom: 18px }
#hebcal-results table.month h2 { margin: 0.2em; text-align: center }
</style>
EOHTML
;
    Hebcal::out_html(undef,
		     Hebcal::html_header($results_title,
					 $script_name,
					 "single single-post",
					 $xtra_head)
	);
    my $head_divs = <<EOHTML;
<div id="container" class="single-attachment">
<div id="content" role="main">
<div id="nav-above" class="navigation">
<div class="nav-previous"><a href="$prev_url" rel="prev"><span class="meta-nav">&larr;</span> Jewish Calendar $prev_title</a></div>
<div class="nav-next"><a href="$next_url" rel="next">Jewish Calendar $next_title <span class="meta-nav">&rarr;</span></a></div>
</div><!-- #nav-above -->
<div class="page type-page hentry">
<h1 class="entry-title">Jewish Calendar $date</h1>
<div class="entry-content">
<div id="hebcal-results-header">
EOHTML
;
    Hebcal::out_html(undef, $head_divs);

    my $cmd_pretty = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename
    Hebcal::out_html(undef, "<!-- $cmd_pretty -->\n");

    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    my $numEntries = scalar(@events);

    my($greg_year1,$greg_year2) = (0,0);
    if ($numEntries > 0)
    {
	$greg_year1 = $events[0]->[$Hebcal::EVT_IDX_YEAR];
	$greg_year2 = $events[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];

	Hebcal::out_html(undef, $Hebcal::gregorian_warning)
	    if ($greg_year1 <= 1752);

	if ($greg_year1 >= 3762
	    && (!defined $q->param("yt") || $q->param("yt") eq "G"))
	{
	    my $future_years = $greg_year1 - $this_year;
	    my $new_url = Hebcal::self_url($q, 
					   {"yt" => "H", "month" => "x"});
	    Hebcal::out_html(undef, "<p><span style=\"color: red\">NOTE:
You are viewing a calendar for <b>Gregorian</b> year $greg_year1, which
is $future_years years <em>in the future</em>.</span><br>
Did you really mean to do this? Perhaps you intended to get the calendar
for <a href=\"$new_url\">Hebrew year $greg_year1</a>?<br>
If you really intended to use Gregorian year $greg_year1, please
continue. Hebcal.com results this far in the future should be
accurate.</p>
");
	}
    }

    my $geographic_info = "";

    if (param_true("c"))
    {
	$geographic_info = "<h3>" . $cconfig->{"title"} . "</h3>\n";
	$geographic_info .= $cconfig->{"lat_descr"} . "<br>\n"
	    if $cconfig->{"lat_descr"};
	$geographic_info .= $cconfig->{"long_descr"} . "<br>\n"
	    if $cconfig->{"long_descr"};
	$geographic_info .= $cconfig->{"dst_tz_descr"} . "<br>\n"
	    if $cconfig->{"dst_tz_descr"};
    }

    Hebcal::out_html(undef, $geographic_info);

    Hebcal::out_html(undef, $Hebcal::indiana_warning)
	if (defined $cconfig->{"state"} && $cconfig->{"state"} eq "IN");

    Hebcal::out_html(undef, $Hebcal::usno_warning)
	if (defined $cconfig->{"lat_deg"} &&
	    ($cconfig->{"lat_deg"} >= 60.0 || $cconfig->{"lat_deg"} <= -60.0));

    # toggle month/full year and event list/calendar grid

    my $goto = "<small>change view: [ ";

    if ($q->param("vis"))
    {
	$goto .= "<a\nhref=\"" . Hebcal::self_url($q, {"vis" => "0"}) .
	    "\">event\nlist</a> | <b>calendar grid</b> ]";
    }
    else
    {
	$goto .= "<b>event list</b> | <a\nhref=\"" .
	    Hebcal::self_url($q, {"vis" => "on"}) . "\">calendar\ngrid</a> ]";
    }

    if ($q->param("yt") && $q->param("yt") eq "H")
    {
	$goto .= "\n";
    }
    else
    {
	$goto .= "\n&nbsp;&nbsp;&nbsp; [ ";

	if ($date !~ /^\d+$/)
	{
	    $goto .= "<b>month</b> | " .
		"<a\nhref=\"" . Hebcal::self_url($q, {"month" => "x"}) .
		"\">entire\nyear</a> ]";
	}
	else
	{
	    $goto .= "<a\nhref=\"" . Hebcal::self_url($q, {"month" => "1"}) .
		"\">month</a> |\n<b>entire year</b> ]";
	}
    }

    $goto .= "</small>\n";

    Hebcal::out_html(undef, "<p class=\"goto\">", $goto, "</p>\n");

    if ($numEntries > 0)
    {
	Hebcal::out_html(undef, qq{<div class="goto"><ul class="gtl goto">});

	if (defined $q->param("tag") && $q->param("tag") eq "fp.ql")
	{
	    Hebcal::out_html(undef,
	    "\n<li>",
	    "<a href=\"", Hebcal::self_url($q, {"v" => 0, "tag" => "cal.cust"}),
	    "\">Customize\ncalendar options</a>");
	}

	if (param_true("c") &&
	    $q->param("geo") && $q->param("geo") =~ /^city|zip$/)
	{
	    # Email
	    my $url = join("", "http://", $q->virtual_host(), "/email/",
			   "?geo=", $q->param("geo"), "&amp;");

	    if ($q->param("zip")) {
		$url .= "zip=" . $q->param("zip");
	    } else {
		$url .= "city=" . Hebcal::url_escape($q->param("city"));
	    }

	    $url .= "&amp;m=" . $q->param("m")
		if (defined $q->param("m") && $q->param("m") =~ /^\d+$/);
	    $url .= "&amp;tag=interactive";

	    Hebcal::out_html(undef,
	    "\n<li>",
	    "<a href=\"$url\">Subscribe\nto weekly candle lighting times via email</a>");

	    # Fridge
	    $url =
		join("", "http://", $q->virtual_host(), "/shabbat/fridge.cgi?");
	    if ($q->param("zip")) {
		$url .= "zip=" . $q->param("zip");
	    } else {
		$url .= "city=" . Hebcal::url_escape($q->param("city"));
	    }

	    my $hyear;
	    if ($q->param("yt") && $q->param("yt") eq "H") {
		$hyear = $q->param("year");
		$url .= ";year=" . $q->param("year");
	    } else {
		my $i = ($q->param("month") eq "x") ? 0 : $numEntries - 1;
		my $year = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
		my $mon = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
		my $mday = $events[$i]->[$Hebcal::EVT_IDX_MDAY];
		my $hebdate = HebcalGPL::greg2hebrew($year,$mon,$mday);
		$hyear = $hebdate->{"yy"};
		$url .= ";year=" . $hyear;
	    }

	    $url .= ";tag=interactive";

	    Hebcal::out_html(undef,
	    "\n<li>",
	    "<a href=\"$url\">Printable\npage of candle-lighting times for $hyear</a>");
#	    Hebcal::out_html(undef, "\n<span class=\"hl\"><b>NEW!</b></span>");
	}

	Hebcal::out_html(undef, qq{<li><a href="#export" onclick="return tvis('export')">Export to Outlook, Apple iCal, Google, Palm, etc.</a>});
	Hebcal::out_html(undef, "\n</ul></div>\n");
	Hebcal::out_html(undef, Hebcal::download_html($q, $filename, \@events, $date));
    }
    else
    {    
	Hebcal::out_html(undef,
	qq{<h3 style="color: red">No Hebrew Calendar events\n},
	qq{for $date</h3>});
    }

    Hebcal::out_html(undef, "</div><!-- #hebcal-results-header -->\n");

    my $header_ad = <<EOHTML;
<div id="hebcal-results-header-ad">
<script type="text/javascript"><!--
google_ad_client = "pub-7687563417622459";
/* 300x250, created 10/14/10 */
google_ad_slot = "1140358973";
google_ad_width = 300;
google_ad_height = 250;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>
</div><!-- #hebcal-results-header-ad -->
EOHTML
;
    # slow down Mediapartners-Google/2.1 so it doesn't crawl us so fast
    if (defined $ENV{"REMOTE_ADDR"} && $ENV{"REMOTE_ADDR"} =~ /^66\.249\./) {
	sleep(3);
    }
    Hebcal::out_html(undef, $header_ad);

    Hebcal::out_html(undef, "<div id=\"hebcal-results\">\n");

    my $cal;
    my $prev_mon = 0;

    my @html_cals;
    my @html_cal_ids;
    for (my $i = 0; $i < $numEntries; $i++)
    {
	my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];

	my $min = $events[$i]->[$Hebcal::EVT_IDX_MIN];
	my $hour = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $year = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	my $mon = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $mday = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($href,$hebrew,$memo) = Hebcal::get_holiday_anchor($subj,0,undef);

	$subj = translate_subject($q,$subj,$hebrew);

	if (defined $href && $href ne "")
	{
	    $subj = qq{<a href="$href">$subj</a>};
	}

	my $dow = $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)] . " ";

	if ($q->param("vis"))
	{
	    if ($prev_mon != $mon)
	    {
		# grotty hack to display empty months
		if ($prev_mon != 0 && ($prev_mon+1 != $mon))
		{
		    for (my $j = $prev_mon+1; $j < $mon; $j++)
		    {
			$cal = new_html_cal($year,$j,
					    $prev_title,$prev_url,
					    $next_title,$next_url);
			push(@html_cals, $cal);
			push(@html_cal_ids, sprintf("%04d-%02d", $year, $j));
		    }
		}

		$prev_mon = $mon;
		$cal = new_html_cal($year,$mon,
				    $prev_title,$prev_url,$next_title,$next_url);
		push(@html_cals, $cal);
		push(@html_cal_ids, sprintf("%04d-%02d", $year, $mon));
	    }

	    my $cal_subj = $subj;
	    $cal_subj = sprintf("<b>%d:%02dp</b> %s", $hour, $min, $subj)
		if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0);

	    $cal->setcontent($mday, "")
		if $cal->getcontent($mday) eq "&nbsp;";

	    $cal->addcontent($mday, "<br>\n")
		if $cal->getcontent($mday) ne "";

	    my $class = "evt";
	    if ($events[$i]->[$Hebcal::EVT_IDX_YOMTOV] == 1)
	    {
		$class .= " hl";
	    }
	    elsif (($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~
		    /^\d+\w+.+, \d{4,}$/) ||
		   ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~
		    /^\d+\w+ day of the Omer$/))
	    {
		$class .= " dim";
	    }

	    $cal->addcontent($mday, qq{<span class="$class">$cal_subj</span>});
	}
	else
	{
	    my $line = sprintf("<tt>%s%02d-%s-%04d</tt> &nbsp;%s",
			       $dow, $mday, $Hebcal::MoY_short[$mon-1],
			       $year, $subj);
	    $line .= sprintf(": %d:%02dpm", $hour, $min)
		if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0);
	    $line .= "<br>\n";

	    Hebcal::out_html(undef, $line);
	}
    }

    if (@html_cals) {
	for (my $i = 0; $i < @html_cals; $i++) {
	    write_html_cal($q, \@html_cals, \@html_cal_ids, $i);
	}
    }

    Hebcal::out_html(undef, "</p>") unless $q->param("vis");
    Hebcal::out_html(undef, "</div><!-- #hebcal-results -->\n");
    Hebcal::out_html(undef, "<p class=\"goto\">", $goto, "</p>\n");
    my $footer_divs=<<EOHTML;
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOHTML
;
    Hebcal::out_html(undef, $footer_divs);
    Hebcal::out_html(undef, Hebcal::html_footer_new($q,$rcsrev,1));
    Hebcal::out_html(undef, "</body></html>\n");
    Hebcal::out_html(undef, "<!-- generated ", scalar(localtime), " -->\n");

    1;
}

sub write_html_cal
{
    my($q,$cals,$cal_ids,$i) = @_;
    my $lang = $q->param("lg");
    my $dir = "";
    if ($lang && $lang eq "h") {
	$dir = qq{ dir="rtl"};
    }
    my $cal = $cals->[$i];
    my $id = $cal_ids->[$i];
    my $class = "cal";
    if ($i != 0) {
	$class .= " pbba";
    }
    if ($id eq sprintf("%04d-%02d", $this_year, $this_mon)) {
	Hebcal::out_html(undef, qq{<div id="cal-current"></div>\n});
    }
    Hebcal::out_html(undef,
		     qq{<div id="cal-$id" align="center" class="$class"$dir>\n},
		     $cal->as_HTML(), 
		     qq{</div><!-- #cal-$id -->\n});
}

sub new_html_cal
{
    my($year,$month,$prev_title,$prev_url,$next_title,$next_url) = @_;

    my $cal = new HTML::CalendarMonthSimple("year" => $year,
					    "month" => $month);
    $cal->border(1);
    $cal->tableclass("month");
    $cal->header(sprintf("<h2>%s %04d</h2>", $Hebcal::MoY_long{$month}, $year));

    my $end_day = Date::Calc::Days_in_Month($year, $month);
    for (my $mday = 1; $mday <= $end_day ; $mday++)
    {
	$cal->setcontent($mday, "&nbsp;");
    }

    $cal;
}


sub get_candle_config
{
    my($q) = @_;

    my $cmd_extra;
    my %config;

    if (param_true("c") && defined $q->param("city"))
    {
	form("Sorry, invalid city\n<b>" . $q->param("city") . "</b>.")
	    unless defined($Hebcal::city_tz{$q->param("city")});

	$q->param("geo","city");
#	$q->param("tz",$Hebcal::city_tz{$q->param("city")});
	$q->delete("tz");
	$q->delete("dst");
	$q->delete("zip");
	$q->delete("lodeg");
	$q->delete("lomin");
	$q->delete("ladeg");
	$q->delete("lamin");
	$q->delete("lodir");
	$q->delete("ladir");

	my $city = $q->param("city");
	$config{"title"} = "Large City: $city";
	$config{"city"} = $city;
	$cmd_extra = " -C '$city'";

	if ($Hebcal::city_dst{$city} eq "israel")
	{
	    $q->param("i","on");
	}
    }
    elsif (defined $q->param("lodeg") && defined $q->param("lomin") &&
	   defined $q->param("ladeg") && defined $q->param("lamin") &&
	   defined $q->param("lodir") && defined $q->param("ladir"))
    {
	if (($q->param("lodeg") eq "") &&
	    ($q->param("lomin") eq "") &&
	    ($q->param("ladeg") eq "") &&
	    ($q->param("lamin") eq ""))
	{
	    $q->param("c","off");
	    $q->delete("zip");
	    $q->delete("city");
	    $q->param("geo","pos");
	    $q->delete("lodeg");
	    $q->delete("lomin");
	    $q->delete("ladeg");
	    $q->delete("lamin");
	    $q->delete("lodir");
	    $q->delete("ladir");
	    $q->delete("dst");
	    $q->delete("tz");
	    $q->delete("m");

	    return (undef,\%config);
	}

	form("Sorry, all latitude/longitude\narguments must be numeric.")
	    if (($q->param("lodeg") !~ /^\d+$/) ||
		($q->param("lomin") !~ /^\d+$/) ||
		($q->param("ladeg") !~ /^\d+$/) ||
		($q->param("lamin") !~ /^\d+$/));

	$q->param("lodir","w") unless ($q->param("lodir") eq "e");
	$q->param("ladir","n") unless ($q->param("ladir") eq "s");

	form("Sorry, longitude degrees\n" .
	     "<b>" . $q->param("lodeg") . "</b> out of valid range 0-180.")
	    if ($q->param("lodeg") > 180);

	form("Sorry, latitude degrees\n" .
	     "<b>" . $q->param("ladeg") . "</b> out of valid range 0-90.")
	    if ($q->param("ladeg") > 90);

	form("Sorry, longitude minutes\n" .
	     "<b>" . $q->param("lomin") . "</b> out of valid range 0-60.")
	    if ($q->param("lomin") > 60);

	form("Sorry, latitude minutes\n" .
	     "<b>" . $q->param("lamin") . "</b> out of valid range 0-60.")
	    if ($q->param("lamin") > 60);

	my($long_deg,$long_min,$lat_deg,$lat_min) =
	    ($q->param("lodeg"),$q->param("lomin"),
	     $q->param("ladeg"),$q->param("lamin"));

	$q->param("dst","none")
	    unless $q->param("dst");
	$q->param("tz","0")
	    unless $q->param("tz");
	$q->param("geo","pos");

	$config{"title"} = "Geographic Position";
	$config{"lat_descr"} = "${lat_deg}d${lat_min}' " .
	    uc($q->param("ladir")) . " latitude";
	$config{"long_descr"} = "${long_deg}d${long_min}' " .
	    uc($q->param("lodir")) . " longitude";
	my $dst_text = ($q->param("dst") eq "none") ? "none" :
	    "automatic for " . $Hebcal::dst_names{$q->param("dst")};
	$config{"dst_tz_descr"} =
	    "Time zone: " . $Hebcal::tz_names{$q->param("tz")} .
	    "\n<br>Daylight Saving Time: $dst_text";

	# don't multiply minutes by -1 since hebcal does it internally
	$long_deg *= -1  if ($q->param("lodir") eq "e");
	$lat_deg  *= -1  if ($q->param("ladir") eq "s");

	$cmd_extra = " -L $long_deg,$long_min -l $lat_deg,$lat_min";

	$config{"long_deg"} = $long_deg;
	$config{"long_min"} = $long_min;
	$config{"lat_deg"} = $lat_deg;
	$config{"lat_min"} = $lat_min;
    }
    elsif (param_true("c") &&
	   defined $q->param("zip") && $q->param("zip") ne "")
    {
	$q->param("geo","zip");

	form("Sorry, <b>" . $q->param("zip") . "</b> does\n" .
	     "not appear to be a 5-digit zip code.")
	    unless $q->param("zip") =~ /^\d\d\d\d\d$/;

	my $DB = Hebcal::zipcode_open_db();
	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    Hebcal::zipcode_get_zip_fields($DB, $q->param("zip"));
	Hebcal::zipcode_close_db($DB);
	undef($DB);

	form("Sorry, can't find\n".  "<b>" . $q->param("zip") .
	     "</b> in the zip code database.\n",
	     "<ul><li>Please try a nearby zip code or select candle\n" .
	     "lighting times by\n" .
	     "<a href=\"" . $script_name .
	     "?c=on;geo=city\">city</a> or\n" .
	     "<a href=\"" . $script_name .
	     "?c=on;geo=pos\">latitude/longitude</a></li></ul>")
	    unless defined $state;

	# allow CGI args to override
	$tz = $q->param("tz")
	    if (defined $q->param("tz") && $q->param("tz") =~ /^-?\d+$/);

	$config{"title"} = "$city, $state &nbsp;" . $q->param("zip");
	$config{"city"} = $city;
	$config{"state"} = $state;
	$config{"zip"} = $q->param("zip");

	if ($tz eq "?")
	{
	    $q->param("tz_override", "1");

	    form("Sorry, can't auto-detect\n" .
		 "timezone for <b>" . $config{"title"} . "</b>\n",
		 "<ul><li>Please select your time zone below.</li></ul>");
	}

	$q->param("tz", $tz);

	# allow CGI args to override
	if (defined $q->param("dst"))
	{
	    $dst = 0 if $q->param("dst") eq "none";
	    $dst = 1 if $q->param("dst") eq "usa";
	}

	if ($dst eq "1")
	{
	    $q->param("dst","usa");
	}
	else
	{
	    $q->param("dst","none");
	}

#	$config{"lat_descr"} = "${lat_deg}d${lat_min}' N latitude";
#	$config{"long_descr"} = "${long_deg}d${long_min}' W longitude";
	my $dst_text = ($q->param("dst") eq "none") ? "none" :
	    "automatic for " . $Hebcal::dst_names{$q->param("dst")};
	$config{"dst_tz_descr"} =
	    "Time zone: " . $Hebcal::tz_names{$q->param("tz")} .
	    "\n<br>Daylight Saving Time: $dst_text";

	$cmd_extra = " -L $long_deg,$long_min -l $lat_deg,$lat_min";

	$config{"long_deg"} = $long_deg;
	$config{"long_min"} = $long_min;
	$config{"lat_deg"} = $lat_deg;
	$config{"lat_min"} = $lat_min;
    }
    else
    {
	$q->param("c","off");
	$q->delete("zip");
	$q->delete("city");
#	$q->param("geo", "none");
	$q->delete("lodeg");
	$q->delete("lomin");
	$q->delete("ladeg");
	$q->delete("lamin");
	$q->delete("lodir");
	$q->delete("ladir");
	$q->delete("dst");
	$q->delete("tz");
	$q->delete("m");

	$cmd_extra = undef;
    }

    return ($cmd_extra,\%config);
}

# local variables:
# mode: perl
# end:
