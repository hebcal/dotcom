#!/usr/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your ZIP code or closest city).
#
# Copyright (c) 2013  Michael J. Radwin.
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
use CGI qw(-no_xhtml);
use Encode qw(decode_utf8);
use CGI::Carp qw(fatalsToBrowser);
use Time::Local ();
use Date::Calc ();
use URI::Escape;
use Hebcal ();
use HebcalHtml ();
use HTML::CalendarMonthSimple ();

my $http_expires = "Tue, 02 Jun 2037 20:00:00 GMT";
my $cookie_expires = "Tue, 02-Jun-2037 20:00:00 GMT";

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

my $latlong_url = "http://www.getty.edu/research/tools/vocabulary/tgn/";
my %long_candles_text =
    ("pos" => "latitude/longitude",
     "city" => "large cities",
     "zip" => "zip code",
     "none" => "none");

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

foreach my $key ($q->param()) {
    my $val = $q->param($key);
    if (defined $val) {
	my $orig = $val;
	if ($key eq "city") {
	    $val = decode_utf8($val);
	} elsif ($key eq "tzid") {
	    $val =~ s/[^\/\w\.\s-]//g; # allow forward-slash in tzid
	} else {
	    # sanitize input to prevent people from trying to hack the site.
	    # remove anthing other than word chars, white space, or hyphens.
	    $val =~ s/[^\w\.\s-]//g;
	}
	$val =~ s/^\s+//g;		# nuke leading
	$val =~ s/\s+$//g;		# and trailing whitespace
	$q->param($key, $val) if $val ne $orig;
    }
}

my $content_type = "text/html";
my $cfg;
my $pi = $q->path_info();
if (! defined $pi) {
    $cfg = "html";
} elsif ($pi =~ /[^\/]+\.csv$/) {
    $cfg = "csv";
    $content_type = "text/x-csv";
} elsif ($pi =~ /[^\/]+\.dba$/) {
    $cfg = "dba";
    $content_type = "application/x-palm-dba";
} elsif ($pi =~ /[^\/]+\.pdf$/) {
    $cfg = "pdf";
    $content_type = "application/pdf";
} elsif ($pi =~ /[^\/]+\.[vi]cs$/) {
    $cfg = "ics";
    $content_type = "text/calendar";
} elsif (defined $q->param("cfg") && $q->param("cfg") =~ /^(e|e2|json)$/) {
    $cfg = $q->param("cfg");
    $content_type = $q->param("cfg") eq "json"
	? "application/json" : "text/javascript";
} else {
    $cfg = "html";
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

form("Sorry, invalid year\n<strong>" . $q->param("year") . "</strong>.")
    if $q->param("year") !~ /^\d+$/ || $q->param("year") == 0;

form("Sorry, Hebrew year must be 3762 or later.")
    if $q->param("yt") && $q->param("yt") eq "H" && $q->param("year") < 3762;

form("Sorry, invalid Havdalah minutes\n<strong>" . $q->param("m") . "</strong>.")
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


my %cconfig;
my $cmd = "./hebcal";

if (param_true("c")) {
    my @status = Hebcal::process_args_common($q, 0, 0, \%cconfig);
    unless ($status[0]) {
	form($status[1], $status[2]);
    }
    $cmd = $status[1];
} else {
    $q->param("c","off");
    $cconfig{"geo"} = "none";
    foreach (qw(zip city lodeg lomin ladeg lamin lodir ladir m tz dst tzid)) {
	$q->delete($_);
    }
}

foreach (@Hebcal::opts)
{
    $cmd .= " -" . $_
	if defined $q->param($_) && $q->param($_) =~ /^on|1$/
}

$cmd .= " -a"
    if defined $q->param("lg") && $q->param("lg") =~ /^a/;
$cmd .= " -h" if !defined $q->param("nh") || $q->param("nh") eq "off";
$cmd .= " -x" if !defined $q->param("nx") || $q->param("nx") eq "off";

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

my $EXTRA_YEARS = 4;
if ($q->param("ny") && $q->param("ny") =~ /^\d+$/ && $q->param("ny") > 1) {
    $EXTRA_YEARS = $q->param("ny") - 1;
}

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
    $g_date = sprintf("%04d", $q->param("year"));
}

my $g_loc = (defined $cconfig{"city"} && $cconfig{"city"} ne "") ?
    "in " . $cconfig{"city"} : "";
my $g_seph = (defined $q->param("i") && $q->param("i") =~ /^on|1$/) ? 1 : 0;
my $g_nmf = (defined $q->param("mf") && $q->param("mf") =~ /^on|1$/) ? 0 : 1;
my $g_nss = (defined $q->param("ss") && $q->param("ss") =~ /^on|1$/) ? 0 : 1;

if ($cfg eq "html") {
    results_page($g_date, $g_filename);
} elsif ($cfg eq "csv") {
    csv_display();
} elsif ($cfg eq "dba") {
    dba_display();
} elsif ($cfg eq "pdf") {
    pdf_display();
} elsif ($cfg eq "ics") {
    vcalendar_display();
} elsif ($cfg eq "e") {
    javascript_events(0);
} elsif ($cfg eq "e2") {
    javascript_events(1);
} elsif ($cfg eq "json") {
    json_events();
} else {
    die "unknown cfg \"$cfg\"";
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
    my $items = Hebcal::events_to_dict(\@events,"json",$q,0,0,$cconfig{"tzid"});

    print STDOUT $q->header(-type => $content_type,
			    -charset => "UTF-8",
			    );

    my $title = "Hebcal $g_date";
    if (defined $cconfig{"title"} && $cconfig{"title"} ne "") {
	$title .= " "  . $cconfig{"title"};
    }
    Hebcal::items_to_json($items,$q,$title,
			  $cconfig{"latitude"},$cconfig{"longitude"});
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

    print STDOUT $q->header(-type => $content_type,
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
    foreach my $evt (@events) {
	my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];

	my($year,$mon,$mday) = Hebcal::event_ymd($evt);

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

	if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    my $time_formatted = Hebcal::format_evt_time($evt, "p");
	    $subj = sprintf("<strong>%s</strong> %s", $time_formatted, $subj);
	}

	if ($v2) {
	    print STDOUT "," unless $first;
	    $first = 0;
	    printf STDOUT "{d:%04d%02d%02d,s:\"%s\"",
	    $year, $mon, $mday, $subj;
	    if ($href) {
		my $href2 = $href;
		$href2 =~ s,^http://www.hebcal.com/,,;
		print STDOUT ",a:\"$href2\"";
	    }
	    if ($img_url) {
		printf STDOUT ",is:\"%s\",iw:%d,ih:%d",
	    	$img_url, $img_w, $img_h;
	    }
	    print STDOUT "}";
	} else {
	    #DefineEvent(EventDate,EventDescription,EventLink,Image,Width,Height)
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
if(e.a){f.eventLink="http://www.hebcal.com/"+e.a}
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
    return qq{<span lang="he" dir="rtl">$hebrew</span>};
}

sub plus4_events {
    my($cmd,$title,$events) = @_;

    if (defined $q->param("month") && $q->param("month") eq "x") {
	for (my $i = 1; $i <= $EXTRA_YEARS; $i++)
	{
	    my $cmd2 = $cmd;
	    $cmd2 =~ s/(\d+)$/$1+$i/e;
	    my @ev2 = Hebcal::invoke_hebcal($cmd2, $g_loc, $g_seph, undef,
					    $g_nmf, $g_nss);
	    push(@{$events}, @ev2);
	}
	if ($g_date =~ /(\d+)/) {
	    my $plus4 = $1 + $EXTRA_YEARS;
	    ${$title} .= "-" . $plus4;
	}
    }

    1;
}


sub vcalendar_display
{
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    my $title = $g_date;
    plus4_events($cmd, \$title, \@events);
    Hebcal::vcalendar_write_contents($q, \@events, $title, \%cconfig);
}

use constant PDF_WIDTH => 792;
use constant PDF_HEIGHT => 612;
use constant PDF_TMARGIN => 72;
use constant PDF_BMARGIN => 32;
use constant PDF_LMARGIN => 24;
use constant PDF_RMARGIN => 24;
use constant PDF_COLUMNS => 7;
my %pdf_font;

sub pdf_display {
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    my $title = "Jewish Calendar $g_date";
    if (defined $cconfig{"city"} && $cconfig{"city"} ne "") {
	$title .= " "  . $cconfig{"city"};
    }

    eval("use PDF::API2");
    my $pdf = PDF::API2->new();
    $pdf->info("Author" => "Hebcal Jewish Calendar (www.hebcal.com)",
	       "Title" => $title);

    $pdf_font{'plain'} = $pdf->ttfont('./fonts/Open_Sans/OpenSans-Regular.ttf');
    $pdf_font{'bold'} = $pdf->ttfont('./fonts/Open_Sans/OpenSans-Bold.ttf');
    my $lg = $q->param("lg") || "s";
    if ($lg eq "h") {
	$pdf_font{'hebrew'} = $pdf->ttfont('./fonts/SBL_Hebrew/SBL_Hbrw.ttf');
    }

    my %cells;
    foreach my $evt (@events) {
	my($year,$mon,$mday) = Hebcal::event_ymd($evt);
	my $cal_id = sprintf("%04d-%02d", $year, $mon);
	push(@{$cells{$cal_id}{$mday}}, $evt);
    }

    # add blank months in the middle, even if there are no events
    my $numEntries = scalar(@events);
    my($start_year,$start_month,$start_mday) = Hebcal::event_ymd($events[0]);
    my($end_year,$end_month,$end_mday) = Hebcal::event_ymd($events[$numEntries - 1]);
    my $end_days = Date::Calc::Date_to_Days($end_year, $end_month, 1);
    for (my @dt = ($start_year, $start_month, 1);
	 Date::Calc::Date_to_Days(@dt) <= $end_days;
	 @dt = Date::Calc::Add_Delta_YM(@dt, 0, 1)) {
	my $cal_id = sprintf("%04d-%02d", $dt[0], $dt[1]);
	if (! defined $cells{$cal_id}) {
	    $cells{$cal_id}{"dummy"} = [];
	}
    }

    foreach my $year_month (sort keys %cells) {
	my($year,$month) = split(/-/, $year_month);
	$month =~ s/^0//;

	my $month_name = Date::Calc::Month_to_Text($month);
	my $daysinmonth = Date::Calc::Days_in_Month($year,$month);
	my $day = 1;

	# returns "1" for Monday, "2" for Tuesday .. until "7" for Sunday
	my $dow = Date::Calc::Day_of_Week($year,$month,$day);
	$dow = 0 if $dow == 7; # treat Sunday as day 0 (not day 7 as Date::Calc does)

	my($hspace, $vspace) = (0, 0); # Space between columns and rows
	my $rows = 5;
	if (($daysinmonth == 31 && $dow >= 5) || ($daysinmonth == 30 && $dow == 6)) {
	    $rows = 6;
	}

	my $colwidth = (PDF_WIDTH - PDF_LMARGIN - PDF_RMARGIN - (PDF_COLUMNS - 1) * $hspace) / PDF_COLUMNS;
	my $rowheight = (PDF_HEIGHT - PDF_TMARGIN - PDF_BMARGIN - ($rows - 1) * $vspace) / $rows;

	my $page = $pdf->page;
	$page->mediabox(PDF_WIDTH, PDF_HEIGHT);
	$page->cropbox(PDF_WIDTH, PDF_HEIGHT);
	$page->trimbox(PDF_WIDTH, PDF_HEIGHT);

	my $text = $page->text(); # Add the Text object
	$text->translate(PDF_WIDTH / 2, PDF_HEIGHT - PDF_TMARGIN + 24); # Position the Text object
	$text->font($pdf_font{'bold'}, 24); # Assign a font to the Text object
	$text->text_center("$month_name $year"); # Draw the string

	my $g = $page->gfx();
	$g->strokecolor("#aaaaaa");
	$g->linewidth(1);
	$g->rect(PDF_LMARGIN, PDF_BMARGIN,
		 PDF_WIDTH - PDF_LMARGIN - PDF_RMARGIN,
		 PDF_HEIGHT - PDF_TMARGIN - PDF_BMARGIN);
	$g->stroke();
	$g->endpath(); 

	$text->font($pdf_font{'plain'},10);
	for (my $i = 0; $i < scalar(@Hebcal::DoW_long); $i++) {
	    my $x = PDF_LMARGIN + $i * ($colwidth + $hspace) + ($colwidth / 2);
	    $text->translate($x, PDF_HEIGHT - PDF_TMARGIN + 6);
	    $text->text_center($Hebcal::DoW_long[$i]);
	}

	# Loop through the columns
	foreach my $c (0 .. PDF_COLUMNS - 1) {
	    my $x = PDF_LMARGIN + $c * ($colwidth + $hspace);
	    if ($c > 0) {
		# Print a vertical grid line
		$g->move($x, PDF_BMARGIN);
		$g->line($x, PDF_HEIGHT - PDF_TMARGIN);
		$g->stroke;
		$g->endpath();
	    }
    
	    # Loop through the rows
	    foreach my $r (0 .. $rows - 1) {
		my $y = PDF_HEIGHT - PDF_TMARGIN - $r * ($rowheight + $vspace);
		if ($r > 0) {
		    # Print a horizontal grid line
		    $g->move(PDF_LMARGIN, $y);
		    $g->line(PDF_WIDTH - PDF_RMARGIN, $y);
		    $g->stroke;
		    $g->endpath();
		}
	    }
	}

	my $xpos = PDF_LMARGIN + $colwidth - 4;
	$xpos += ($dow * $colwidth);
	my $ypos = PDF_HEIGHT - PDF_TMARGIN - 12;
	for (my $mday = 1; $mday <= $daysinmonth; $mday++) {
	    # render day number
	    $text->font($pdf_font{'plain'}, 11);
	    $text->fillcolor("#000000");
	    $text->translate($xpos, $ypos);
	    $text->text_right($mday);

	    # events within day $mday
	    if (defined $cells{$year_month}{$mday}) {
		$text->translate($xpos - $colwidth + 8, $ypos - 18);
		foreach my $evt (@{$cells{$year_month}{$mday}}) {
		    pdf_render_event($pdf, $text, $evt, $lg);
		}
	    }

	    $xpos += $colwidth;	# move to the right by one cell
	    if (++$dow == 7) {
		$dow = 0;
		$xpos = PDF_LMARGIN + $colwidth - 4;
		$ypos -= $rowheight; # move down the page
	    }
	}

	$text->fillcolor("#000000");
	$text->font($pdf_font{'plain'}, 8);
	if (param_true("c")) {
	    $text->translate(PDF_LMARGIN, PDF_BMARGIN - 12);
	    $text->text("Candle lighting times for " . $cconfig{"title"});
	}

	$text->translate(PDF_WIDTH - PDF_RMARGIN, PDF_BMARGIN - 12);
	$text->text_right("Provided by www.hebcal.com with a Creative Commons Attribution 3.0 license");
    }

    print STDOUT $q->header(-type => $content_type);
    binmode(STDOUT, ":raw");
    print STDOUT $pdf->stringify();
    $pdf->end();
}

sub pdf_render_event {
    my($pdf,$text,$evt,$lg) = @_;

    my $color = "#000000";
    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
    if (($subj =~ /^\d+\w+.+, \d{4,}$/) || ($subj =~ /^\d+\w+ day of the Omer$/)) {
	$color = "#666666";
    }
    $text->fillcolor($color);

    if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0) {
	my $time_formatted = Hebcal::format_evt_time($evt, "p");
	$text->font($pdf_font{'bold'}, 8);
	$text->text($time_formatted . " ");
    }

    my($href,$hebrew,$memo) = Hebcal::get_holiday_anchor($subj,0,undef);
    if ($lg eq "h" && $hebrew) {
	my $str = scalar reverse($hebrew);
	$str =~ s/(\d+)/scalar reverse($1)/ge;
	$str =~ s/\(/\cA/g;
	$str =~ s/\)/\(/g;
	$str =~ s/\cA/\)/g;
	$text->font($pdf_font{'hebrew'}, 10);
	$text->text($str);
    } elsif ($evt->[$Hebcal::EVT_IDX_YOMTOV] == 1) {
	$text->font($pdf_font{'bold'}, 8);
	$text->text($subj);
    } elsif (length($subj) >= 25) {
	# lazy eval on font that might not be used
	if (! defined $pdf_font{'condensed'}) {
	    $pdf_font{'condensed'} = $pdf->ttfont('./fonts/Open_Sans_Condensed/OpenSans-CondLight.ttf');
	}
	$text->font($pdf_font{'condensed'}, 9);
	$text->fillcolor("#000000");
	$text->text($subj);
    } elsif ($subj =~ /^Havdalah \((\d+) min\)$/) {
	my $minutes = $1;
	$text->font($pdf_font{'plain'}, 8);
	$text->text("Havdalah");
	$text->font($pdf_font{'plain'}, 6);
	$text->text(" ($minutes min)");
    } else {
	$text->font($pdf_font{'plain'}, 8);
	$text->text($subj);
    }
    $text->cr(-12);
}


sub dba_display
{
    eval("use Palm::DBA");

    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    Hebcal::export_http_header($q, $content_type);

    my $basename = $q->path_info();
    $basename =~ s,^.*/,,;

    Palm::DBA::write_header($basename);
    Palm::DBA::write_contents(\@events, $cconfig{"tzid"});
}

sub csv_display
{
    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    my $title = $g_date;
    plus4_events($cmd, \$title, \@events);

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

    print STDOUT $q->header(-type => $content_type,
			    -charset => "UTF-8");

    if ($message ne "" && $cfg ne "html") {
	if ($cfg =~ /^(e|e2)$/) {
	    $message =~ s/\"/\\"/g;
	    print STDOUT qq{alert("Error: $message");\n};
	} elsif ($cfg eq "json") {
	    $message =~ s/\"/\\"/g;
	    print STDOUT "{\"error\":\"$message\"}\n";
	} else {
	    print STDOUT $message, "\n";
	}
	exit(0);
    }

    my $xtra_head = <<EOHTML;
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,Torah,parsha">
<meta name="description" content="Personalized Jewish calendar for any year 0001-9999 includes Jewish holidays, candle lighting times, Torah readings. Export to Outlook, Apple iCal, Google, Palm, etc.">
<style type="text/css">
legend {
  font-size: 17px;
  font-weight: bold;
  line-height: 30px;
}
</style>
EOHTML
;

    Hebcal::out_html(undef,
		     Hebcal::html_header_bootstrap("Custom Calendar",
					 $script_name,
					 "single single-post",
					 $xtra_head)
	);
    my $head_divs = <<EOHTML;
<p class="lead">Customize your calendar of Jewish holidays, candle
lighting times, and Torah readings.</p>
EOHTML
;
    Hebcal::out_html(undef, $head_divs);

    if ($message ne "") {
	$help = "" unless defined $help;
	$message = qq{<div class="alert alert-error alert-block">\n} .
	    qq{<button type="button" class="close" data-dismiss="alert">&times;</button>\n} .
	    $message . $help . "</div>";
	Hebcal::out_html(undef, $message, "\n");

    }

    Hebcal::out_html(undef,
    qq{<form id="f1" name="f1" action="$script_name">\n},
    qq{<div class="row-fluid">\n},
    qq{<div class="span6">\n},
    qq{<fieldset><legend>Jewish Holidays for</legend>\n},
    qq{<div class="form-inline">\n},
    qq{<label>Year: },
    $q->textfield(-name => "year",
		  -id => "year",
		  -pattern => '\d*',
		  -default => $this_year,
		  -style => "width:auto",
		  -size => 4,
		  -maxlength => 4),
    "</label>\n",
    qq{<label>Month: },
    $q->popup_menu(-name => "month",
		   -id => "month",
		   -values => ["x",1..12],
		   -default => "x",
		   -class => "input-medium",
		   -labels => \%Hebcal::MoY_long),
    "</label>\n",
    qq{</div><!-- .form-inline -->\n},
    $q->radio_group(-name => "yt",
		    -values => ["G", "H"],
		    -default => "G",
		    -onClick => "s6(this.value)",
		    -labels =>
		    {"G" => " Gregorian (common era) ",
		     "H" => " Hebrew Year"}),
    qq{\n<p><small class="muted">Use all digits to specify a year.\n},
    qq{You probably aren't interested in 08, but rather 2008.</small></p>\n},
    $q->hidden(-name => "v",-value => 1,-override => 1),
    qq{</fieldset>\n}
    );

    Hebcal::out_html(undef, qq{<fieldset><legend>Include events</legend>\n});
    Hebcal::out_html(undef,
    qq{<label class="checkbox">},
    $q->checkbox(-name => "nh",
		 -id => "nh",
		 -checked => 1,
		 -label => "Major + Minor Holidays"),
    "</label>\n",
    qq{<label class="checkbox">},
    $q->checkbox(-name => "nx",
		 -id => "nx",
		 -checked => 1,
		 -label => "Rosh Chodesh"),
    "</label>\n",
    qq{<label class="checkbox">},
    $q->checkbox(-name => "mf",
		 -checked => 1,
		 -label => "Minor Fasts"),
    qq{\n<small class="muted">(Ta'anit Esther, Tzom Gedaliah, etc.)</small></label>\n},
    qq{<label class="checkbox">},
    $q->checkbox(-name => "ss",
		 -checked => 1,
		 -label => "Special Shabbatot"),
    qq{\n<small class="muted">(Shabbat Shekalim, Zachor, etc.)</small></label>\n},
    qq{<label class="checkbox">},
    $q->checkbox(-name => "o",
		 -label => "Days of the Omer"),
    "</label>\n",
    qq{<label class="checkbox">},
    $q->checkbox(-name => "s",
		 -label => "Weekly Torah portion on Saturdays"),
    "</label>\n",
    $q->radio_group(-name => "i",
		    -values => ["off", "on"],
		    -default => "off",
		    -labels =>
		    {"off" => "\nDiaspora ",
		     "on" => "\nIsrael "}),
    "\n <small>(<a\n",
    "href=\"/home/51/what-is-the-differerence-between-the-diaspora-and-israeli-sedra-schemes\">What\n",
    "is the difference?</a>)</small>");

    Hebcal::out_html(undef, qq{</fieldset>\n});
    Hebcal::out_html(undef, qq{</div><!-- .span6 -->\n});

    Hebcal::out_html(undef, qq{<div class="span6">\n});
    Hebcal::out_html(undef,
    "<fieldset><legend>Other options</legend>",
    "<label>Event titles: ",
    $q->popup_menu(-name => "lg",
		   -values => ["s", "sh", "a", "ah", "h"],
		   -default => "s",
		   -labels => \%Hebcal::lang_names),
    "</label>\n",
    qq{<label class="checkbox">},
    $q->checkbox(-name => "vis",
		 -checked => 1,
		 -label => "Display visual calendar grid"),
    "</label>",
    qq{<label class="checkbox">},
    $q->checkbox(-name => "D",
		 -label => "Show Hebrew date for dates with some event"),
    "</label>",
    qq{<label class="checkbox">},
    $q->checkbox(-name => "d",
		 -label => "Show Hebrew date for entire date range"),
    "</label>",
    "</fieldset>\n");

    Hebcal::out_html(undef, qq{<fieldset><legend>Candle lighting times</legend>\n});
    $q->param("c","off") unless defined $q->param("c");
    $q->param("geo","zip") unless defined $q->param("geo");

    Hebcal::out_html(undef,
    $q->hidden(-name => "c"),
    $q->hidden(-name => "geo",
	       -default => "zip"),
    "\n");

    Hebcal::out_html(undef, "<small>[\n");
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
			 "<label>Large City: ",
			 Hebcal::html_city_select($q->param("city")),
			 "</label>\n");
    }
    elsif ($q->param("geo") eq "pos")
    {
	Hebcal::out_html(undef,
	qq{<div class="form-inline">\n},
	"<label>",
	$q->textfield(-name => "ladeg",
		      -style => "width:auto",
		      -pattern => '\d*',
		      -size => 3,
		      -maxlength => 2),
	" deg</label>\n",
	"<label>",
	$q->textfield(-name => "lamin",
		      -style => "width:auto",
		      -pattern => '\d*',
		      -size => 2,
		      -maxlength => 2),
	" min</label>\n",
	$q->popup_menu(-name => "ladir",
		       -class => "input-medium",
		       -values => ["n","s"],
		       -default => "n",
		       -labels => {"n" => "North Latitude",
				   "s" => "South Latitude"}),
	qq{</div>\n},
	qq{<div class="form-inline">\n},
	"<label>",
	$q->textfield(-name => "lodeg",
		      -style => "width:auto",
		      -pattern => '\d*',
		      -size => 3,
		      -maxlength => 3),
	" deg</label>\n",
	"<label>",
	$q->textfield(-name => "lomin",
		      -style => "width:auto",
		      -pattern => '\d*',
		      -size => 2,
		      -maxlength => 2),
	" min</label>\n",
	$q->popup_menu(-name => "lodir",
		       -class => "input-medium",
		       -values => ["w","e"],
		       -default => "w",
		       -labels => {"e" => "East Longitude",
				   "w" => "West Longitude"}),
	qq{</div>\n});
	Hebcal::out_html(undef,
	"<p><small><a href=\"$latlong_url\">Search</a>\n",
	"for the exact location of your city.</small></p>\n");
    }
    elsif ($q->param("geo") ne "none")
    {
	# default is Zip Code
	Hebcal::out_html(undef,
	"<label>ZIP code: ",
	$q->textfield(-name => "zip",
		      -style => "width:auto",
		      -pattern => '\d*',
		      -size => 5,
		      -maxlength => 5),
	"</label>\n");
    }

    if ($q->param("geo") eq "pos") {
	Hebcal::out_html(undef,
	"<label>Time zone: ",
	$q->popup_menu(-name => "tzid",
		       -values => Hebcal::get_timezones(),
		       -default => "UTC"),
	"</label>\n");
    }

    if ($q->param("geo") ne "none") {
	Hebcal::out_html(undef,
	"<label>Havdalah minutes past sundown: ",
	$q->textfield(-name => "m",
		      -pattern => '\d*',
		      -style => "width:auto",
		      -size => 2,
		      -maxlength => 2,
		      -default => $Hebcal::havdalah_min),
	qq{&nbsp;<a href="#" id="havdalahInfo" data-toggle="tooltip" data-placement="bottom" },
	qq{title="Use 42 min for three medium-sized stars, },
	qq{50 min for three small stars, },
	qq{72 min for Rabbeinu Tam, or 0 to suppress Havdalah times"><i class="icon icon-info-sign"></i></a>},
	"</label>\n",
	);

    }

    Hebcal::out_html(undef, qq{</fieldset>\n});
    Hebcal::out_html(undef, qq{</div><!-- .span6 -->\n});
    Hebcal::out_html(undef, qq{</div><!-- .row-fluid -->\n});
    Hebcal::out_html(undef, qq{<div class="clearfix" style="margin-top:10px">\n});
    Hebcal::out_html(undef,
    $q->hidden(-name => ".cgifields",
	       -values => ["nx", "nh", "mf", "ss"],
	       "-override"=>1),
    "\n",
    $q->submit(-name => ".s",
	       -class => "btn btn-primary",
	       -value => "Create Calendar"),
    qq{</div><!-- .clearfix -->\n},
    qq{</form>\n});

    Hebcal::out_html(undef, qq{
<p>Hebcal computes candle-lighting times according to the method defined
by the U.S. Naval Observatory (USNO). The USNO claims accuracy within 2
minutes except at extreme northern or southern latitudes. <a
href="/home/94/how-accurate-are-candle-lighting-times">Read more
&raquo;</a></p>
});

    my $hyear = Hebcal::get_default_hebrew_year($this_year,$this_mon,$this_day);
    my $js=<<JSCRIPT_END;
<script type="text/javascript">
var d=document;
function s1(geo,c){d.f1.geo.value=geo;d.f1.c.value=c;d.f1.v.value='0';
d.f1.submit();return false;}
function s6(val){
if(val=='G'){d.f1.year.value=$this_year;d.f1.month.value=$this_mon;}
if(val=='H'){d.f1.year.value=$hyear;d.f1.month.value='x';}
return false;}
d.getElementById("nh").onclick=function(){if(this.checked==false){d.f1.nx.checked=false;}}
d.getElementById("nx").onclick=function(){if(this.checked==true){d.f1.nh.checked=true;}}
d.getElementById("mf").onclick=function(){if(this.checked==true){d.f1.nh.checked=true;}}
d.getElementById("ss").onclick=function(){if(this.checked==true){d.f1.nh.checked=true;}}
</script>
JSCRIPT_END
	;
    Hebcal::out_html(undef, $js);

    Hebcal::out_html(undef, Hebcal::html_footer_bootstrap($q,undef,1));
    Hebcal::out_html(undef, "<script>\$('#havdalahInfo').tooltip()</script>\n");
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

	$prev_url = Hebcal::self_url($q, {"year" => $py, "month" => $pm}, "&amp;");
	$prev_title = sprintf("%s %04d", $Hebcal::MoY_long{$pm}, $py);

	$next_url = Hebcal::self_url($q, {"year" => $ny, "month" => $nm}, "&amp;");
	$next_title = sprintf("%s %04d", $Hebcal::MoY_long{$nm}, $ny);
    }
    else
    {
	$prev_url = Hebcal::self_url($q, {"year" => ($q->param("year") - 1)}, "&amp;");
	$prev_title = sprintf("%04d", ($q->param("year") - 1));

	$next_url = Hebcal::self_url($q, {"year" => ($q->param("year") + 1)}, "&amp;");
	$next_title = sprintf("%04d", ($q->param("year") + 1));
    }

    my $results_title = "Jewish Calendar $date";
    if (defined $cconfig{"city"} && $cconfig{"city"} ne "") {
	$results_title .= " "  . $cconfig{"city"};
    }

    print STDOUT $q->header(-expires => $http_expires,
			    -type => $content_type,
			    -charset => "UTF-8");

    my $xtra_head = <<EOHTML;
<style type="text/css">
div.cal { margin-bottom: 18px }
div.pbba { page-break-before: always }
.evt {font-size:85%;}
.hl {background:#ff9;}
\@media print { div.pbba { page-break-before: always } }
</style>
EOHTML
;

    my $lang = $q->param("lg");
    my $lang_hebrew = ($lang && $lang =~ /h/) ? 1 : 0;

    Hebcal::out_html(undef,
		     Hebcal::html_header_bootstrap(
			$results_title, $script_name, "ignored",
			$xtra_head, 0, $lang_hebrew)
	);

    my $h1_extra = "";
    if (param_true("c")) {
	$h1_extra = "<br><small>" . $cconfig{"title"} . "</small>";
    }

    my $head_divs = <<EOHTML;
<div class="span8">
<div class="page-header">
<h1>Jewish Calendar $date$h1_extra</h1>
</div>
EOHTML
;
    Hebcal::out_html(undef, $head_divs);

    Hebcal::out_html(undef, "<!-- $cmd -->\n");

    my @events = Hebcal::invoke_hebcal($cmd, $g_loc, $g_seph, $g_month,
				       $g_nmf, $g_nss);

    my $numEntries = scalar(@events);

    my($greg_year1,$greg_year2) = (0,0);
    if ($numEntries > 0)
    {
	$greg_year1 = $events[0]->[$Hebcal::EVT_IDX_YEAR];
	$greg_year2 = $events[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];

	Hebcal::out_html(undef, $HebcalHtml::gregorian_warning)
	    if ($greg_year1 <= 1752);

	if ($greg_year1 >= 3762
	    && (!defined $q->param("yt") || $q->param("yt") eq "G"))
	{
	    my $future_years = $greg_year1 - $this_year;
	    my $new_url = Hebcal::self_url($q, 
					   {"yt" => "H", "month" => "x"},
					   "&amp;");
	    Hebcal::out_html(undef, qq{<div class="alert alert-block">
<button type="button" class="close" data-dismiss="alert">&times;</button>
<strong>Note!</strong>
You are viewing a calendar for <strong>Gregorian</strong> year $greg_year1, which
is $future_years years <em>in the future</em>.</span><br>
Did you really mean to do this? Perhaps you intended to get the calendar
for <a href="$new_url">Hebrew year $greg_year1</a>?<br>
If you really intended to use Gregorian year $greg_year1, please
continue. Hebcal.com results this far in the future should be
accurate.
</div><!-- .alert -->
});
	}
    }

    Hebcal::out_html(undef, $HebcalHtml::indiana_warning)
	if (defined $cconfig{"state"} && $cconfig{"state"} eq "IN");

    my $latitude = $cconfig{"latitude"};
    Hebcal::out_html(undef, $HebcalHtml::usno_warning)
	if (defined $latitude && ($latitude >= 60.0 || $latitude <= -60.0));

    if ($numEntries > 0) {
	my $download_title = $date;
	if (defined $q->param("month") && $q->param("month") eq "x" && $date =~ /(\d+)/) {
	    my $plus4 = $1 + $EXTRA_YEARS;
	    $download_title .= "-" . $plus4;
	}
	Hebcal::out_html(undef, HebcalHtml::download_html_modal($q, $filename, \@events, $download_title));
    }

    Hebcal::out_html(undef, qq{<div class="btn-toolbar">\n});

    if ($numEntries > 0) {
	Hebcal::out_html(undef, HebcalHtml::download_html_modal_button());

	# don't offer "Print PDF" button on Hebrew-only language setting
	my $print_pdf_btn_class = "btn download";
	my $lang = $q->param("lg");
	if ($lang && $lang eq "h") {
	    $print_pdf_btn_class .= " disabled";
	}

	my $pdf_url = Hebcal::download_href($q, $filename, "pdf");
	Hebcal::out_html(undef, qq{<a class="$print_pdf_btn_class" id="pdf" href="$pdf_url"><i class="icon-print"></i> Print PDF</a>\n});

	if (param_true("c") && $q->param("geo") && $q->param("geo") =~ /^city|zip$/) {
	    # Fridge
	    my $url = "/shabbat/fridge.cgi?";
	    if ($q->param("zip")) {
		$url .= "zip=" . $q->param("zip");
	    } else {
		$url .= "city=" . URI::Escape::uri_escape_utf8($q->param("city"));
	    }

	    my $hyear = Hebcal::get_default_hebrew_year($this_year,$this_mon,$this_day);
	    $url .= "&amp;year=$hyear";
	    
	    Hebcal::out_html(undef, qq{<a class="btn" href="$url"><i class="icon-print"></i> Candle-lighting times</a>\n});
	}
    }

    Hebcal::out_html(undef, qq{<a class="btn" href="},
		     Hebcal::self_url($q, {"v" => "0"}, "&amp;"),
		     qq{" title="Change calendar options"><i class="icon-cog"></i> Settings</a>\n});

    Hebcal::out_html(undef, qq{</div><!-- .btn-toolbar -->\n});

    if ($numEntries > 0 && param_true("c") && $q->param("geo") && $q->param("geo") =~ /^city|zip$/) {
	# Email
	my $email_form = <<EOHTML;
<form class="form-inline" action="/email/">
<fieldset>
<input type="hidden" name="v" value="1">
EOHTML
;
	if ($q->param("zip")) {
	    $email_form .= qq{<input type="hidden" name="geo" value="zip">\n};
	    $email_form .= qq{<input type="hidden" name="zip" value="} . $q->param("zip") . qq{">\n};
	} else {
	    $email_form .= qq{<input type="hidden" name="geo" value="city">\n};
	    $email_form .= qq{<input type="hidden" name="city" value="} . $q->param("city") . qq{">\n};
	}

	if (defined $q->param("m") && $q->param("m") =~ /^\d+$/) {
	    $email_form .= qq{<input type="hidden" name="m" value="} . $q->param("m") . qq{">\n};
	}

	$email_form .= <<EOHTML;
<p><small>Subscribe to weekly Shabbat candle lighting times and Torah portion by email.</small></p>
<div class="input-append input-prepend">
<span class="add-on"><i class="icon-envelope"></i></span><input type="email" name="em" placeholder="Email address">
<button type="submit" class="btn" name="modify" value="1"> Sign up</button>
</div>
</fieldset>
</form>
EOHTML
;
	Hebcal::out_html(undef, $email_form);
    }

    if ($numEntries == 0) {    
	Hebcal::out_html(undef,
	qq{<div class="alert">No Hebrew Calendar events for $date</div>\n});
    }

    Hebcal::out_html(undef, "</div><!-- .span8 -->\n");

    my $header_ad = <<EOHTML;
<div class="span4">
<h4 style="font-size:14px;margin-bottom:4px">Advertisement</h4>
<script async src="http://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- 300x250, created 10/14/10 -->
<ins class="adsbygoogle"
 style="display:inline-block;width:300px;height:250px"
 data-ad-client="ca-pub-7687563417622459"
 data-ad-slot="1140358973"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .span4 -->
EOHTML
;
    # slow down Mediapartners-Google/2.1 so it doesn't crawl us so fast
    if (defined $ENV{"REMOTE_ADDR"} && $ENV{"REMOTE_ADDR"} =~ /^66\.249\./) {
	sleep(3);
    }
    Hebcal::out_html(undef, $header_ad);

    Hebcal::out_html(undef, "<div class=\"span12\" id=\"hebcal-results\">\n");

    my @html_cals;
    my %html_cals;
    my @html_cal_ids;

    # make blank calendar month objects for every month in the date range
    if ($numEntries > 0 && $q->param("vis")) {
	my $start_month;
	my $start_year = $events[0]->[$Hebcal::EVT_IDX_YEAR];
	my $end_month;
	my $end_year = $events[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];

	if ($q->param("month") eq "x" &&
	    (! defined $q->param("yt") || $q->param("yt") eq "G")) {
	    $start_month = 1;
	    $end_month = 12;
	} else {
	    $start_month = $events[0]->[$Hebcal::EVT_IDX_MON] + 1;
	    $end_month = $events[$numEntries - 1]->[$Hebcal::EVT_IDX_MON] + 1;
	}

	my $end_days = Date::Calc::Date_to_Days($end_year, $end_month, 1);
	for (my @dt = ($start_year, $start_month, 1);
	     Date::Calc::Date_to_Days(@dt) <= $end_days;
	     @dt = Date::Calc::Add_Delta_YM(@dt, 0, 1))
	{
	    my $cal = new_html_cal($dt[0], $dt[1]);
	    my $cal_id = sprintf("%04d-%02d", $dt[0], $dt[1]);
	    push(@html_cals, $cal);
	    push(@html_cal_ids, $cal_id);
	    $html_cals{$cal_id} = $cal;
	}
    }

    my $prev_nofollow = ($q->param("month") =~ /^\d+$/
			 || $greg_year1 < $this_year
			) ? " nofollow" : "";
    my $next_nofollow = ($q->param("month") =~ /^\d+$/
			 || $greg_year2 > $this_year + 2
			) ? " nofollow" : "";

    my $nav_pagination = <<EOHTML;
<div class="pagination pagination-centered">
<ul>
<li><a href="$prev_url" rel="prev$prev_nofollow">&laquo; $prev_title</a></li>
EOHTML
    ;
    foreach my $cal_id (@html_cal_ids) {
	if ($cal_id =~ /^(\d{4})-(\d{2})$/) {
	    my $year = $1;
	    my $mon = $2;
	    $mon =~ s/^0//;
	    my $mon_long = $Hebcal::MoY_long{$mon};
	    my $mon_short = $Hebcal::MoY_short[$mon-1];
	    $nav_pagination .= qq{<li><a title="$mon_long $year" href="#cal-$cal_id">$mon_short</a></li>\n};
	}
    }
    $nav_pagination .= <<EOHTML;
<li><a href="$next_url" rel="next$next_nofollow">$next_title &raquo;</a></li>
</ul>
</div><!-- .pagination -->
EOHTML
    ;

    Hebcal::out_html(undef, $nav_pagination);

    if (!$q->param("vis")) {
	Hebcal::out_html(undef, qq{<table class="table table-striped"><col style="width:20px"><col style="width:110px"><col><tbody>\n});
    }

    foreach my $evt (@events) {
	my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];

	my($year,$mon,$mday) = Hebcal::event_ymd($evt);

	my($href,$hebrew,$memo) = Hebcal::get_holiday_anchor($subj,0,undef);

	$subj = translate_subject($q,$subj,$hebrew);

	if (defined $href && $href ne "")
	{
	    $subj = qq{<a href="$href">$subj</a>};
	}

	if ($q->param("vis"))
	{
	    my $cal_subj;
	    if ($evt->[$Hebcal::EVT_IDX_UNTIMED]) {
		$cal_subj = $subj;
	    } else {
		my $time_formatted = Hebcal::format_evt_time($evt, "p");
		$cal_subj = sprintf("<strong>%s</strong> %s", $time_formatted, $subj);
	    }

	    $cal_subj =~
		s/ Havdalah \((\d+) min\)$/ Havdalah <small>($1 min)<\/small>/;

	    my $cal_id = sprintf("%04d-%02d", $year, $mon);
	    my $cal = $html_cals{$cal_id};

	    $cal->setcontent($mday, "")
		if $cal->getcontent($mday) eq "&nbsp;";

	    $cal->addcontent($mday, "<br>\n")
		if $cal->getcontent($mday) ne "";

	    my $class = "evt";
	    if ($evt->[$Hebcal::EVT_IDX_YOMTOV] == 1)
	    {
		$class .= " hl";
	    }
	    elsif (($evt->[$Hebcal::EVT_IDX_SUBJ] =~
		    /^\d+\w+.+, \d{4,}$/) ||
		   ($evt->[$Hebcal::EVT_IDX_SUBJ] =~
		    /^\d+\w+ day of the Omer$/))
	    {
		$class .= " muted";
	    }

	    $cal->addcontent($mday, qq{<span class="$class">$cal_subj</span>});
	}
	else
	{
	    my $subj_copy;
	    if ($evt->[$Hebcal::EVT_IDX_UNTIMED]) {
		$subj_copy = $subj;
	    } else {
		my $time_formatted = Hebcal::format_evt_time($evt, "pm");
		$subj_copy = $subj . ": " . $time_formatted;
	    }
	    Hebcal::out_html(undef,
			     qq{<tr>},
			     qq{<td>}, $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)], qq{</td>},
			     qq{<td>}, sprintf("%02d-%s-%04d", $mday, $Hebcal::MoY_short[$mon-1], $year), qq{</td>},
			     qq{<td>}, $subj_copy, qq{</td>},
			     qq{</tr>\n});
	}
    }

    if (!$q->param("vis")) {
	Hebcal::out_html(undef, qq{</tbody></table>\n});
    }

    if (@html_cals) {
	for (my $i = 0; $i < @html_cals; $i++) {
	    write_html_cal($q, \@html_cals, \@html_cal_ids, $i);
	}
    }

    Hebcal::out_html(undef, "</p>") unless $q->param("vis");
    Hebcal::out_html(undef, $nav_pagination);
    Hebcal::out_html(undef, "</div><!-- #hebcal-results -->\n");

    Hebcal::out_html(undef, Hebcal::html_footer_bootstrap($q,undef,1));
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
    my $style = "";
    my $class = "cal";
    if ($i != 0) {
	$class .= " pbba";
	$style = qq{ style="page-break-before:always"};
    }
    if ($id eq sprintf("%04d-%02d", $this_year, $this_mon)) {
	Hebcal::out_html(undef, qq{<div id="cal-current"></div>\n});
    }
    Hebcal::out_html(undef,
		     qq{<div id="cal-$id" class="$class"$style$dir>\n},
		     $cal->as_HTML(), 
		     qq{</div><!-- #cal-$id -->\n});
}

sub new_html_cal
{
    my($year,$month) = @_;

    my $cal = new HTML::CalendarMonthSimple("year" => $year,
					    "month" => $month);
    $cal->border(1);
    $cal->tableclass("table table-bordered");
    $cal->header(sprintf("<h2>%s %04d</h2>", $Hebcal::MoY_long{$month}, $year));

    my $end_day = Date::Calc::Days_in_Month($year, $month);
    for (my $mday = 1; $mday <= $end_day ; $mday++)
    {
	$cal->setcontent($mday, "&nbsp;");
    }

    $cal;
}


# local variables:
# mode: cperl
# end:
