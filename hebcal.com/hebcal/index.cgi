#!/usr/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your ZIP code or closest city).
#
# Copyright (c) 2018  Michael J. Radwin.
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
use File::Basename;
use Hebcal ();
use HebcalConst;
use HebcalGPL ();
use HebcalHtml ();
use POSIX qw(strftime);
use Benchmark qw(:hireswallclock :all);

my @benchmarks;
push(@benchmarks, Benchmark->new);

my $http_cache_control = "max-age=63072000";

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

# process form params
my $q = new CGI;

if (defined $ENV{'REQUEST_METHOD'} && $ENV{'REQUEST_METHOD'} eq "POST" && $ENV{'QUERY_STRING'}) {
    print STDOUT "Allow: GET\n";
    print STDOUT $q->header(-type => "text/plain",
                            -status => "405 Method Not Allowed");
    print STDOUT "POST not allowed; try using GET instead.\n";
    exit(0);
}

$q->delete(".s");               # we don't care about submit button

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
        if ($key eq "city" || $key eq "city-typeahead") {
            $val = decode_utf8($val);
        } elsif ($key eq "tzid") {
            $val =~ s/[^\/\w\.\s-]//g; # allow forward-slash in tzid
        } else {
            # sanitize input to prevent people from trying to hack the site.
            # remove anthing other than word chars, white space, or hyphens.
            $val =~ s/[^\w\.\s-]//g;
        }
        $val =~ s/^\s+//g;              # nuke leading
        $val =~ s/\s+$//g;              # and trailing whitespace
        $q->param($key, $val) if $val ne $orig;
    }
}

my $content_type = "text/html";
my $cfg;
my $pi = $q->path_info();
if (! defined $pi) {
    $cfg = "html";
} elsif ($pi =~ /\.csv$/) {
    $cfg = "csv";
    $content_type = "text/x-csv";
} elsif ($pi =~ /\.dba$/) {
    $cfg = "dba";
    $content_type = "application/x-palm-dba";
} elsif ($pi =~ /\.pdf$/) {
    $cfg = "pdf";
    $content_type = "application/pdf";
} elsif ($pi =~ /\.[vi]cs$/) {
    $cfg = "ics";
    $content_type = "text/calendar";
} elsif (defined $q->param("cfg") && $q->param("cfg") =~ /^(e|e2|json|fc)$/) {
    $cfg = $q->param("cfg");
    $content_type = substr($q->param("cfg"), 0, 1) eq "e"
        ? "text/javascript" : "application/json";
} else {
    $cfg = "html";
}

push(@benchmarks, Benchmark->new);

# decide whether this is a results page or a blank form
form("") unless $q->param("v");

my $g_orig_year_now = 0;
if (defined $q->param("year") && $q->param("year") eq "now") {
    $g_orig_year_now = 1;
    my($yy,$mm,$dd) = Date::Calc::Today();
    if (defined $q->param("yt") && $q->param("yt") eq "H") {
        my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
        $q->param("year", $hebdate->{"yy"});
        $q->param("month", "x");
    } else {
        $q->param("year", $this_year);
        $q->param("month", $this_mon)
            if defined $q->param("month") && $q->param("month") eq "now";        
    }
    my $age_str = $cfg eq "json" ? "86400" : "2592000";
    $http_cache_control = "max-age=$age_str";
}

if ($cfg eq "fc") {
    foreach my $param (qw(start end)) {
        form("Please specify required parameter '$param'")
            unless defined $q->param($param);
        form("Parameter '$param' must match format YYYY-MM-DD")
            unless $q->param($param) =~ /^\d{4}-\d{2}-\d{2}$/;
    }
    my($sy,$sm,$sd) = split(/-/, $q->param("start"), 3);
    my($ey,$em,$ed) = split(/-/, $q->param("end"), 3);
    $q->param("year", $sy);
    $q->param("month", "x");
    $q->param("yt", "G");
    if ($ey ne $sy) {
        $q->param("ny", 2);
    }
}

form("Please specify a year.")
    if !defined $q->param("year") || $q->param("year") eq "";

form("Sorry, invalid year <strong>" . $q->param("year") . "</strong>.")
    if $q->param("year") !~ /^\d+$/ || $q->param("year") == 0;

my $g_year_type = defined $q->param("yt") && $q->param("yt") eq "H" ? "H" : "G";

if ($g_year_type eq "H") {
    form("Sorry, Hebrew year must be 3762 or later.")
        if $q->param("year") < 3762;
    form("Sorry, Hebrew year must be 10665 or earlier.")
        if $q->param("year") > 10665;
} else {
    form("Sorry, Gregorian year must be 9999 or earlier.")
        if $q->param("year") > 9999;
}

form("Sorry, invalid Havdalah minutes <strong>" . $q->param("m") . "</strong>.")
    if defined $q->param("m") &&
    $q->param("m") ne "" && $q->param("m") !~ /^\d+$/;

$q->param("c","on")
    if (defined $q->param("zip") && $q->param("zip") =~ /^\d{5}$/);

# map old "nh=on" to 3 new parameters for Major, Minor and Modern holdays
if (defined $q->param("nh") && $q->param("nh") =~ /^(on|1)$/) {
    foreach my $opt (qw(maj min mod)) {
        $q->param($opt, "on");
    }
    $q->delete("nh");
}

form("Please select at least one event option.")
    if ((!defined $q->param("maj") || $q->param("maj") eq "off") &&
        (!defined $q->param("nx") || $q->param("nx") eq "off") &&
        (!defined $q->param("o") || $q->param("o") eq "off") &&
        (!defined $q->param("c") || $q->param("c") eq "off") &&
        (!defined $q->param("d") || $q->param("d") eq "off") &&
        (!defined $q->param("F") || $q->param("F") eq "off") &&
        (!defined $q->param("s") || $q->param("s") eq "off"));

form("Sorry, invalid language <strong>" . $q->param("lg") . "</strong>.")
    if (defined $q->param("lg") &&
        $q->param("lg") ne "" &&
        ! defined $Hebcal::lang_names{$q->param("lg")});

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
    foreach (qw(zip city lodeg lomin ladeg lamin lodir ladir m b city-typeahead geonameid tz dst tzid)) {
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
$cmd .= " -h" if !defined $q->param("maj") || $q->param("maj") eq "off";
$cmd .= " -x" if !defined $q->param("nx") || $q->param("nx") eq "off";

if ($g_year_type eq "H")
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
my %extra_years_opts = (
    "D" => 2,
    "d" => 1,
    "F" => 1,
    "c" => 3,
    "o" => 3,
    );
if ($q->param("ny") && $q->param("ny") =~ /^\d+$/ && $q->param("ny") >= 1) {
    $EXTRA_YEARS = $q->param("ny") - 1;
} elsif (($g_year_type eq "G" && $q->param("year") >= 2016) || ($g_year_type eq "H" && $q->param("year") >= 5776)) {
    foreach my $opt (keys %extra_years_opts) {
        if (param_true($opt)) {
            my $v = $extra_years_opts{$opt};
            $EXTRA_YEARS = $v if $v < $EXTRA_YEARS;
        }
    }
    # Shabbat plus Hebrew Event every day can get very big
    if (param_true("c") && (param_true("d") || param_true("D"))) {
        $EXTRA_YEARS = 1;
    }
    # reduce size of file for truly crazy people who specify both Daf Yomi and Hebrew Date every day
    if (param_true("F") && (param_true("d") || param_true("D"))) {
        $EXTRA_YEARS = 0;
    }
}

my $g_date;
my $g_filename = "hebcal_" . $q->param("year");
$g_filename .= "H" if $g_year_type eq "H";
if (defined $q->param("month") && defined $q->param("year") &&
    $q->param("month") =~ /^\d{1,2}$/ &&
    $q->param("month") >= 1 && $q->param("month") <= 12)
{
    $g_filename .= "_" . lc($Hebcal::MoY_short[$q->param("month")-1]);
    my $yr = $q->param("year");
    $g_date = sprintf("%s %04d", $Hebcal::MoY_long{$q->param("month")},
                    $yr);
}
else
{
    my $yr = $q->param("year");
    $g_date = sprintf("%04d", $yr);
}

my $g_seph = (defined $q->param("i") && $q->param("i") =~ /^on|1$/) ? 1 : 0;
my $g_nmf = (defined $q->param("mf") && $q->param("mf") =~ /^on|1$/) ? 0 : 1;
my $g_nss = (defined $q->param("ss") && $q->param("ss") =~ /^on|1$/) ? 0 : 1;
my $g_nminor = (defined $q->param("min") && $q->param("min") =~ /^on|1$/) ? 0 : 1;
my $g_nmodern = (defined $q->param("mod") && $q->param("mod") =~ /^on|1$/) ? 0 : 1;

if ($cfg eq "html") {
    results_page($g_date, $g_filename);
} elsif ($cfg eq "json") {
    json_events();
} elsif ($cfg eq "ics") {
    vcalendar_display();
} elsif ($cfg eq "csv") {
    csv_display();
} elsif ($cfg eq "pdf") {
    pdf_display();
} elsif ($cfg eq "fc") {
    fullcalendar_events();
} elsif ($cfg eq "dba") {
    dba_display();
} elsif ($cfg eq "e") {
    javascript_events(0);
} elsif ($cfg eq "e2") {
    javascript_events(1);
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

sub fullcalendar_event {
    my($evt) = @_;

    my $subj = $evt->{subj};
    my($year,$mon,$mday) = Hebcal::event_ymd($evt);
    my $min = $evt->{min};
    my $hour24 = $evt->{hour};
    my $allDay = $evt->{untimed};

    my $start = sprintf("%04d-%02d-%02d", $year, $mon, $mday);
    if (!$allDay) {
        $start .= sprintf("T%02d:%02d:00", $hour24, $min);
    }

    my $className = $evt->{category};
    $className .= " yomtov" if $evt->{yomtov};

    my $lang = $q->param("lg") || "s";
    my $xsubj = Hebcal::translate_event($evt, $lang);

    my $out = {
        title => $xsubj || $subj,
        allDay => $allDay ? \1 : \0,
        className => $className,
        start => $start,
    };

    $out->{hebrew} = $evt->{hebrew} if $evt->{hebrew};
    $out->{url} = $evt->{href} if $evt->{href};
    $out->{description} = $evt->{memo} if $evt->{memo};

    return $out;
}

sub fullcalendar_filter_events {
    my($events) = @_;
    my($sy,$sm,$sd) = split(/-/, $q->param("start"), 3);
    my $start_julian = Date::Calc::Date_to_Days($sy,$sm,$sd);
    my($ey,$em,$ed) = split(/-/, $q->param("end"), 3);
    my $end_julian = Date::Calc::Date_to_Days($ey,$em,$ed);
    my @out;
    foreach my $evt (@{$events}) {
        my($year,$mon,$mday) = Hebcal::event_ymd($evt);
        my $julian = Date::Calc::Date_to_Days($year,$mon,$mday);
        next if $julian < $start_julian;
        last if $julian > $end_julian;
        push(@out, $evt);
    }
    return \@out;
}

sub my_invoke_hebcal_inner {
    my($cmd0,$month) = @_;
    my $no_havdalah = (defined $q->param('m') && $q->param('m') eq "0") ? 1 : 0;
    my @events = Hebcal::invoke_hebcal_v2(
        $cmd0, "", $g_seph, $month,
        $g_nmf, $g_nss, $g_nminor, $g_nmodern,
        $no_havdalah);
    return @events;
}

sub my_invoke_hebcal_cmd {
    my($cmd2) = @_;
    return my_invoke_hebcal_inner($cmd2, undef);
}

sub my_invoke_hebcal {
    return my_invoke_hebcal_inner($cmd, $g_month);
}

sub fullcalendar_events {
    my @events = my_invoke_hebcal();

    my $title = $g_date;
    plus4_events($cmd, \$title, \@events);

    print STDOUT $q->header(-type => $content_type,
                            -charset => "UTF-8",
                            -cache_control => $http_cache_control,
                            -access_control_allow_origin => '*',
                            );

    my $filtered = fullcalendar_filter_events(\@events);
    my @out;
    foreach my $evt (@{$filtered}) {
        push(@out, fullcalendar_event($evt));
    }

    eval("use JSON");
    my $json = JSON->new;
    print STDOUT $json->encode(\@out);
}

sub json_events
{
    my @events = my_invoke_hebcal();
    my $items = Hebcal::events_to_dict(\@events,"json",$q,0,0,$cconfig{"tzid"},0,
        1, param_true("i"));

    print STDOUT $q->header(-type => $content_type,
                            -charset => "UTF-8",
                            -cache_control => $http_cache_control,
                            -access_control_allow_origin => '*',
                            );

    my $title = "Hebcal $g_date";
    if (defined $cconfig{"title"} && $cconfig{"title"} ne "") {
        $title .= " "  . $cconfig{"title"};
    }
    Hebcal::items_to_json($items,$q,$title,
        $cconfig{"latitude"},$cconfig{"longitude"},\%cconfig);
}

sub javascript_events
{
    my($v2) = @_;
    my @events = my_invoke_hebcal();
    my $cmd2 = $cmd;
    $cmd2 =~ s/(\d+)$/$1+1/e;
    my @ev2 = my_invoke_hebcal_cmd($cmd2);
    push(@events, @ev2);

    print STDOUT $q->header(-type => $content_type,
                            -charset => "UTF-8",
                            -cache_control => $http_cache_control,
                            -access_control_allow_origin => '*',
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
        my($year,$mon,$mday) = Hebcal::event_ymd($evt);

        my $img_url = "";
        my $img_w = 0;
        my $img_h = 0;

        if ($q->param("img"))
        {
            if ($evt->{category} eq "candles")
            {
                $img_url = "https://www.hebcal.com/i/sm_candles.gif";
                $img_w = 40;
                $img_h = 69;
            }
            elsif ($evt->{category} eq "havdalah")
            {
                $img_url = "https://www.hebcal.com/i/havdalah.gif";
                $img_w = 46;
                $img_h = 59;
            }
        }

        my $subj = my_translate_event($q,$evt);

        if ($evt->{untimed} == 0)
        {
            my $time_formatted = Hebcal::format_evt_time($evt, "p");
            $subj = sprintf("<strong>%s</strong> %s", $time_formatted, $subj);
        }

        my $href = $evt->{href};
        if ($v2) {
            print STDOUT "," unless $first;
            $first = 0;
            printf STDOUT "{d:%04d%02d%02d,s:\"%s\"",
            $year, $mon, $mday, $subj;
            if ($href) {
                my $href2 = $href;
                $href2 =~ s,^https://www.hebcal.com/,,;
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
if(e.a){f.eventLink="https://www.hebcal.com/"+e.a}
HEBCAL.jec2events.push(f);}
EOJS
;
    }
}

sub my_translate_event {
    my($q,$evt) = @_;

    my $lang = $q->param("lg") || "s";
    my $subj = $evt->{subj};
    if ($lang eq "s" || $lang eq "a") {
        return $subj;
    }

    my $xsubj = Hebcal::translate_event($evt, $lang);
    if ($lang eq "h") {
        return $xsubj ? hebrew_span($xsubj) : $subj;
    } elsif ($lang eq "ah" || $lang eq "sh") {
        if (!$xsubj) {
            return $subj;
        }
        return $subj . "\n<br>" . hebrew_span($xsubj);
    } elsif ($Hebcal::lang_european{$lang}) {
        return $xsubj || $subj;
    } else {
        warn "unknown lang \"$lang\" for $subj";
        return $subj;
    }
}

sub hebrew_span
{
    my($hebrew) = @_;
    return qq{<span lang="he" dir="rtl">$hebrew</span>};
}

sub plus4_events {
    my($cmd,$title,$events) = @_;

    if (defined $q->param("month") && $q->param("month") eq "x" && $EXTRA_YEARS) {
        for (my $i = 1; $i <= $EXTRA_YEARS; $i++)
        {
            my $cmd2 = $cmd;
            $cmd2 =~ s/(\d+)$/$1+$i/e;
            my @ev2 = my_invoke_hebcal_cmd($cmd2);
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
    my @events = my_invoke_hebcal();

    my $title = $g_date;
    plus4_events($cmd, \$title, \@events);
    if ($g_orig_year_now && $q->param("subscribe")) {
        $title = "";
    }
    eval("use HebcalExport");
    HebcalExport::vcalendar_write_contents($q, \@events, $title, \%cconfig);
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
    my @events = my_invoke_hebcal();

    my $title = "Jewish Calendar $g_date";
    if (defined $cconfig{"city"} && $cconfig{"city"} ne "") {
        $title .= " "  . $cconfig{"city"};
    }

    eval("use PDF::API2");
    my $pdf = PDF::API2->new();
    $pdf->info("Author" => "Hebcal Jewish Calendar (www.hebcal.com)",
               "Title" => $title);

    $pdf_font{'plain'} = $pdf->ttfont('./fonts/Source_Sans_Pro/SourceSansPro-Regular.ttf');
    $pdf_font{'bold'} = $pdf->ttfont('./fonts/Source_Sans_Pro/SourceSansPro-Bold.ttf');
    my $lg = $q->param("lg") || "s";
    if ($lg =~ /h/) {
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

    my $pdf_rtl = ($lg eq "h") ? 1 : 0;
    foreach my $year_month (sort keys %cells) {
        my($year,$month) = split(/-/, $year_month);
        $month =~ s/^0//;

        my $month_title;
        my $month_font;
        if ($pdf_rtl) {
            my $s = Hebcal::hebrew_strip_nikkud($Hebcal::MoY_hebrew[$month - 1]);
            $month_font = 'hebrew';
            $month_title = join(" ", $year, scalar reverse($s));
        } else {
            $month_font = 'bold';
            $month_title = join(" ",
                Date::Calc::Month_to_Text($month), $year);
        }
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
        $text->font($pdf_font{$month_font}, 24); # Assign a font to the Text object
        $text->text_center($month_title); # Draw the string

        my $g = $page->gfx();
        $g->strokecolor("#aaaaaa");
        $g->linewidth(1);
        $g->rect(PDF_LMARGIN, PDF_BMARGIN,
                 PDF_WIDTH - PDF_LMARGIN - PDF_RMARGIN,
                 PDF_HEIGHT - PDF_TMARGIN - PDF_BMARGIN);
        $g->stroke();
        $g->endpath();

        my $dow_font = $pdf_rtl ? 'hebrew' : 'plain';
        $text->font($pdf_font{$dow_font},10);
        for (my $i = 0; $i < scalar(@Hebcal::DoW_long); $i++) {
            my $edge_offset = $i * ($colwidth + $hspace) + ($colwidth / 2);
            my $x = $pdf_rtl
                ? PDF_WIDTH - PDF_RMARGIN - $edge_offset
                : PDF_LMARGIN + $edge_offset;
            $text->translate($x, PDF_HEIGHT - PDF_TMARGIN + 6);
            my $dow_text = $pdf_rtl ? scalar reverse($Hebcal::DoW_hebrew[$i]) : $Hebcal::DoW_long[$i];
            $text->text_center($dow_text);
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

        my $xpos_newrow = $pdf_rtl
            ? PDF_WIDTH - PDF_RMARGIN - 4
            : PDF_LMARGIN + $colwidth - 4;
        my $xpos_multiplier = $pdf_rtl ? -1 : 1;
        my $xpos = $xpos_newrow;
        $xpos += ($dow * $colwidth) * $xpos_multiplier;
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

            $xpos += $colwidth * $xpos_multiplier; # move to the right by one cell
            if (++$dow == 7) {
                $dow = 0;
                $xpos = $xpos_newrow;
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

    print STDOUT $q->header(-type => $content_type,
                            -charset => '',
                            -cache_control => $http_cache_control);
    binmode(STDOUT, ":raw");
    print STDOUT $pdf->stringify();
    $pdf->end();
}

sub pdf_render_event {
    my($pdf,$text,$evt,$lg) = @_;

    my $color = "#000000";
    my $subj = $evt->{subj};
    if ($evt->{category} eq "dafyomi" ||
        $evt->{category} eq "hebdate" ||
        $evt->{category} eq "omer") {
        $color = "#666666";
    }
    $text->fillcolor($color);

    if ($evt->{untimed} == 0) {
        my $time_formatted = Hebcal::format_evt_time($evt, "p", $lg);
        $text->font($pdf_font{'bold'}, 8);
        $text->text($time_formatted . " ");
    }

    if ($Hebcal::lang_european{$lg}) {
        my $xsubj = Hebcal::translate_event($evt, $lg);
        if ($xsubj) {
            $subj = $xsubj;
        }
    }

    if ($evt->{category} eq "dafyomi") {
        $subj =~ s/^[^:]+:\s+//; # strip the "Daf Yomi: " prefix
    }

    if ($lg =~ /^(a|s|ah|sh)$/ || $Hebcal::lang_european{$lg}) {
        if ($evt->{yomtov} == 1) {
            $text->font($pdf_font{'bold'}, 8);
            $text->text($subj);
        }
        elsif (length($subj) >= 24) {
            # lazy load this font if we haven't used it yet
            if (!defined $pdf_font{'condensed'}) {
                $pdf_font{'condensed'} = $pdf->ttfont('./fonts/Source_Sans_Pro/SourceSansPro-Light.ttf');
            }
            $text->font($pdf_font{'condensed'}, 7);
            $text->text($subj);
        }
        elsif ($subj =~ /^Havdalah \((\d+) min\)$/) {
            my $minutes = $1;
            $text->font($pdf_font{'plain'}, 8);
            $text->text("Havdalah");
            $text->font($pdf_font{'plain'}, 6);
            $text->text(" ($minutes min)");
        }
        else {
            $text->font($pdf_font{'plain'}, 8);
            $text->text($subj);
        }
        $text->cr(-12);
    }

    if ( $lg =~ /^(h|sh|ah)$/ ) {
        my $hebrew = $evt->{hebrew};
        if ($hebrew) {
            if ( $subj =~ /^Havdalah \((\d+) min\)$/ ) {
                my $minutes = $1;
                $text->font( $pdf_font{'hebrew'}, 8 );
                $text->text("\x{05EA}\x{05D5}\x{05E7}\x{05D3} $minutes - ");

                $hebrew =~ s/ - .+$//;    # remove minutes
                my $str = scalar reverse($hebrew);
                $text->font( $pdf_font{'hebrew'}, 10 );
                $text->text($str);
            }
            else {
                my $str = scalar reverse($hebrew);
                $str =~ s/(\d+)/scalar reverse($1)/ge;
                $str =~ s/\(/\cA/g;
                $str =~ s/\)/\(/g;
                $str =~ s/\cA/\)/g;
                $text->font( $pdf_font{'hebrew'}, 10 );
                $text->text($str);
                $text->cr(-12);
            }
        }
    }
}


sub dba_display
{
    eval("use Palm::DBA");
    eval("use HebcalExport");

    my @events = my_invoke_hebcal();
    my @palm_events;
    foreach my $evt (@events) {
        my $pevt = [
            $evt->{subj},
            $evt->{untimed},
            $evt->{min},
            $evt->{hour},
            $evt->{mday},
            $evt->{mon},
            $evt->{year},
            $evt->{dur},
            $evt->{memo},
        ];
        push(@palm_events, $pevt);
    }

    HebcalExport::export_http_header($q, $content_type);

    my $basename = basename($q->path_info());

    Palm::DBA::write_header($basename);
    Palm::DBA::write_contents(\@palm_events, $cconfig{"tzid"} || 'America/New_York');
}

sub csv_display
{
    my @events = my_invoke_hebcal();

    my $title = $g_date;
    plus4_events($cmd, \$title, \@events);

    my $euro = defined $q->param("euro") ? 1 : 0;
    eval("use HebcalExport");
    HebcalExport::csv_write_contents($q, \@events, $euro, \%cconfig);
}

sub timestamp_comment {
    my $tend = Benchmark->new;
    my $tdiff = timediff($tend, $benchmarks[0]);
    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime(time())) . "Z";
    print "<!-- generated ", $dc_date, "; ",
        timestr($tdiff), " -->\n";
}

sub latlong_form_html {
    my $html = join("",
        qq{<div class="form-group form-inline">\n},
        $q->textfield(-name => "ladeg",
                  -id => "ladeg",
                  -placeholder => "deg",
                  -class => "form-control",
                  -style => "width: 60px",
                  -pattern => '\d*',
                  -size => 3,
                  -maxlength => 2),
        qq{ <label for="ladeg">degrees</label>\n},
        $q->textfield(-name => "lamin",
                  -id => "lamin",
                  -placeholder => "min",
                  -class => "form-control",
                  -style => "width: 45px",
                  -pattern => '\d*',
                  -size => 2,
                  -maxlength => 2),
        qq{ <label for="lamin">minutes</label>\n},
        $q->popup_menu(-name => "ladir",
                   -id => "ladir",
                   -class => "form-control",
                   -style => "width: 160px",
                   -values => ["n","s"],
                   -default => "n",
                   -labels => {"n" => "North Latitude",
                       "s" => "South Latitude"}),
        qq{</div><!-- .form-group -->\n},
        qq{<div class="form-group form-inline">\n},
        $q->textfield(-name => "lodeg",
                  -id => "lodeg",
                  -placeholder => "deg",
                  -class => "form-control",
                  -style => "width: 60px",
                  -pattern => '\d*',
                  -size => 3,
                  -maxlength => 3),
        qq{ <label for="lodeg">degrees</label>\n},
        $q->textfield(-name => "lomin",
                  -id => "lomin",
                  -placeholder => "min",
                  -class => "form-control",
                  -style => "width: 45px",
                  -pattern => '\d*',
                  -size => 2,
                  -maxlength => 2),
        qq{ <label for="lomin">minutes</label>\n},
        $q->popup_menu(-name => "lodir",
                   -id => "lodir",
                   -class => "form-control",
                   -style => "width: 160px",
                   -values => ["w","e"],
                   -default => "w",
                   -labels => {"e" => "East Longitude",
                       "w" => "West Longitude"}),
        qq{</div><!-- .form-group -->\n},
        qq{<div class="form-group">\n},
        qq{<label for="tzid">Time zone</label>\n},
        $q->popup_menu(-name => "tzid",
                   -id => "tzid",
                   -class => "form-control",
                   -values => Hebcal::get_timezones(),
                   -default => "UTC"),
        qq{</div><!-- .form-group -->\n},
    );
    return $html;
}

sub form
{
    my($message,$help) = @_;

    my $http_status = $message eq "" ? "200 OK" : "400 Bad Request";

    print STDOUT $q->header(-type => $content_type,
                            -charset => "UTF-8",
                            -status => $http_status);

    if ($message ne "" && $cfg ne "html") {
        if ($cfg =~ /^(e|e2)$/) {
            $message =~ s/\"/\\"/g;
            $message =~ s/\n/\\n/g;
            print STDOUT qq{alert("Error: $message");\n};
        } elsif ($content_type eq "application/json") {
            $message =~ s/\"/\\"/g;
            $message =~ s/\n/\\n/g;
            print STDOUT "{\"error\":\"$message\"}\n";
        } else {
            print STDOUT $message, "\n";
        }
        exit(0);
    }

    my $xtra_head = <<EOHTML;
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,Torah,parsha">
<meta name="description" content="Personalized Jewish calendar for any year 0001-9999 includes Jewish holidays, candle lighting times, Torah readings. Export to Outlook, Apple iCal, Google, Palm, etc.">
<link rel="stylesheet" type="text/css" href="/i/hyspace-typeahead.css">
EOHTML
;

    print HebcalHtml::header_bootstrap3("Custom Calendar",
        $script_name, "", $xtra_head);

    my $head_divs = <<EOHTML;
<div class="row">
<div class="col-sm-12">
<p class="lead">Customize, print &amp; download your calendar of Jewish holidays.</p>
EOHTML
;
    print $head_divs;

    if ($message ne "") {
        $help = "" unless defined $help;
        $message = qq{<div class="alert alert-danger alert-dismissible">\n} .
            qq{<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>\n} .
            $message . $help . "</div>";
        print $message, "\n";
    }

    my $year_type_radio = HebcalHtml::radio_group($q,
        -name => "yt",
        -values => ["G", "H"],
        -default => "G",
        -onClick => "s6(this.value)",
        -labels => {"G" => "Gregorian year (common era)",
                    "H" => "Hebrew year"}
        );

    my $diaspora_israel_radio = HebcalHtml::radio_group($q,
        -name => "i",
        -values => ["off", "on"],
        -default => "off",
        -labels => {"off" => "Diaspora holiday schedule",
                    "on" => "Israel holiday schedule"}
        );

    print qq{<form id="f1" name="f1" action="$script_name">\n},
    $q->hidden(-name => "v",-value => 1,-override => 1),
    qq{<div class="row">\n},
    qq{<div class="col-sm-6">\n};

    print qq{<fieldset>\n},
    HebcalHtml::checkbox($q, -name => "maj",
                 -id => "maj",
                 -checked => 1,
                 -label => "Major Holidays"),
    HebcalHtml::checkbox($q, -name => "min",
                 -id => "min",
                 -checked => 1,
                 -label => qq{Minor Holidays <small class="text-muted">(Tu BiShvat, Lag BaOmer, ...)</small>}),
    HebcalHtml::checkbox($q, -name => "nx",
                 -id => "nx",
                 -checked => 0,
                 -label => "Rosh Chodesh"),
    HebcalHtml::checkbox($q, -name => "mf",
                 -id => "mf",
                 -checked => 0,
                 -label => qq{Minor Fasts <small class="text-muted">(Ta'anit Esther, Tzom Gedaliah, ...)</small>}),
    HebcalHtml::checkbox($q, -name => "ss",
                 -id => "ss",
                 -checked => 0,
                 -label => qq{Special Shabbatot <small class="text-muted">(Shabbat Shekalim, Zachor, ...)</small>}),
    HebcalHtml::checkbox($q, -name => "mod",
                 -id => "mod",
                 -checked => 0,
                 -label => qq{Modern Holidays <small class="text-muted">(Yom HaShoah, Yom HaAtzma'ut, ...)</small>}),
    HebcalHtml::checkbox($q, -name => "o",
                 -id => "o",
                 -label => "Days of the Omer"),
    HebcalHtml::checkbox($q, -name => "F",
                 -id => "F",
                 -label => "Daf Yomi"),
    HebcalHtml::checkbox($q, -name => "s",
                 -id => "s",
                 -label => "Weekly Torah portion on Saturdays"),
    qq{</fieldset>},
    "\n";

    print qq{<div class="mt-2">}, $diaspora_israel_radio, qq{</div>\n};

    print qq{<div class="form-group mt-3"><label for="year" class="sr-only">Year</label>},
    $q->textfield(-name => "year",
                  -id => "year",
                  -pattern => '\d*',
                  -default => $this_year,
                  -class => "form-control",
                  -style => "width: 80px",
                  -placeholder => "Year",
                  -size => 4,
                  -maxlength => 4),
    "</div>\n",
    $q->hidden(-name => "month",
        -id => "month",
        -value => "x",
        -override => "x");

    print $year_type_radio;

    print qq{</div><!-- .col-sm-6 -->\n},
    qq{<div class="col-sm-6">\n};
    print qq{<fieldset>\n};

    print qq{<div class="form-group"><label for="lg">Event titles</label>},
    $q->popup_menu(-name => "lg",
                   -id => "lg",
                   -values => ["s", "a", "h", @Hebcal::lang_european, "sh", "ah"],
                   -default => "s",
                   -class => "form-control",
                   -labels => \%Hebcal::lang_names),
    "</div>\n",
    HebcalHtml::checkbox($q, -name => "D",
                 -id => "d1",
                 -label => "Show Hebrew date for dates with some event"),
    HebcalHtml::checkbox($q, -name => "d",
                 -id => "d2",
                 -label => "Show Hebrew date every day of the year"),
    "\n";

    print qq{</fieldset>\n};


   print qq{<fieldset>\n};
  #   print qq{<fieldset><legend>Candle lighting times</legend>\n};
    $q->param("c","off") unless defined $q->param("c");
    $q->param("geo","geoname") unless defined $q->param("geo");

    print
        $q->hidden(-name => "c", -id => "c"),
        $q->hidden(-name => "geo",
            -id => "geo",
            -default => "geoname"),
        $q->hidden(-name => "zip", -id => "zip"),
        $q->hidden(-name => "city", -id => "city"),
        $q->hidden(-name => "geonameid", -id => "geonameid"),
        "\n";

    my $city_typeahead_value = "";
    if ($q->param("c") eq "on" && ! $q->param('city-typeahead')) {
        if ($q->param("geo") eq "zip"
            && defined $q->param("zip") && $q->param("zip") =~ /^\d{5}$/) {
            $city_typeahead_value = $q->param('zip');
        } elsif ($q->param("geo") eq "geoname"
            && defined $q->param("geonameid") && $q->param("geonameid") =~ /^\d+$/) {
            my $geonameid = $q->param('geonameid');
            my($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) =
                Hebcal::geoname_lookup($geonameid);
            if ($name) {
                my $city_descr = Hebcal::geoname_city_descr($asciiname,$admin1,$country);
                $city_typeahead_value = $city_descr;
            }
        } elsif ($q->param("geo") eq "city" && $q->param("city")
            && Hebcal::validate_city($q->param("city"))) {
            my $city = Hebcal::validate_city($q->param("city"));
            my $city_descr = Hebcal::woe_city_descr($city);
            $city_typeahead_value = $city_descr;
        }
    }

    if (defined $q->param("geo") && $q->param("geo") eq "pos") {
        print latlong_form_html();
    } else {
        print qq{<div class="form-group mt-2"><label for="city-typeahead">Candle lighting times</label>
<div class="city-typeahead" style="margin-bottom:12px">},
            $q->textfield(-value => $city_typeahead_value,
                  -id => "city-typeahead",
                  -class => "form-control typeahead",
                  -placeholder => "Search for city or ZIP code"),
            qq{</div></div>\n};
    }

    print qq{<div class="form-group"><label for="b1">Candle-lighting minutes before sundown</label>},
            $q->textfield(
                -name      => "b",
                -id        => "b1",
                -pattern   => '\d*',
                -class     => "form-control",
                -style     => "width:60px",
                -size      => 2,
                -maxlength => 2,
                -default   => 18
            ),
            "</div>\n",
            qq{<div class="form-group"><label for="m1">Havdalah minutes past sundown
<a href="#" id="havdalahInfo" data-toggle="tooltip" data-placement="top" title="Use 42 min for three medium-sized stars, 50 min for three small stars, 72 min for Rabbeinu Tam, or 0 to suppress Havdalah times"><span class="glyphicons glyphicons-info-sign"></span></a>
</label>},
            $q->textfield(
                -name      => "m",
                -id        => "m1",
                -pattern   => '\d*',
                -class     => "form-control",
                -style     => "width:60px",
                -size      => 2,
                -maxlength => 2,
                -default   => $Hebcal::havdalah_min
            ),
            qq{</div>\n};

    print qq{
</fieldset>
</div><!-- .col-sm-6 -->
</div><!-- .row -->
<div class="clearfix" style="margin-top:10px">
};

    print $q->submit(-name => ".s",
               -class => "btn btn-primary",
               -value => "Create Calendar");

    print qq{
</div><!-- .clearfix -->
</form>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
};

    my $hyear = Hebcal::get_default_hebrew_year($this_year,$this_mon,$this_day);
    my $xtra_html=<<JSCRIPT_END;
<script src="$Hebcal::JS_TYPEAHEAD_BUNDLE_URL"></script>
<script src="$Hebcal::JS_APP_URL"></script>
<script>
var d=document;
function s6(val){
d.f1.month.value='x';
if(val=='G'){d.f1.year.value=$this_year;}
if(val=='H'){d.f1.year.value=$hyear;}
return false;}
d.getElementById("maj").onclick=function(){
 if (this.checked == false) {
  ["nx","mf","ss","min","mod"].forEach(function(x){
   d.f1[x].checked = false;
  });
 }
};
["nx","mf","ss","min","mod"].forEach(function(x){
 d.getElementById(x).onclick=function(){if(this.checked==true){d.f1.maj.checked=true;}}
});
d.getElementById("d1").onclick=function(){
  if (this.checked) {
    d.getElementById("d2").checked = false;
  }
}
d.getElementById("d2").onclick=function(){
  if (this.checked) {
    d.getElementById("d1").checked = false;
  }
}
window['hebcal'].createCityTypeahead(false);
\$('#havdalahInfo').click(function(e){
 e.preventDefault();
}).tooltip();
</script>
JSCRIPT_END
        ;

    print HebcalHtml::footer_bootstrap3($q,undef,1,$xtra_html);
    print "</body></html>\n";
    timestamp_comment();

    exit(0);
    1;
}

sub possibly_set_cookie {
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

            my_set_cookie($newcookie) if $cmp1 ne $cmp2;
        }
    }
}

sub my_set_cookie
{
    my($str) = @_;
    if ($str =~ /&/) {
        my $cookie_expires = "Tue, 02-Jun-2037 20:00:00 GMT";
        print STDOUT "Cache-Control: private\015\012Set-Cookie: ",
        $str, "; expires=", $cookie_expires, "; path=/\015\012";
    }
}

sub get_start_and_end {
    my($events) = @_;

    my $numEntries = scalar(@{$events});
    my $start_month;
    my $start_year = $events->[0]->{year};
    my $end_month;
    my $end_year = $events->[$numEntries - 1]->{year};

    if ($q->param("month") eq "x" && $g_year_type eq "G") {
        $start_month = 1;
        $end_month = 12;
    } else {
        $start_month = $events->[0]->{mon} + 1;
        $end_month = $events->[$numEntries - 1]->{mon} + 1;
    }
    return ($start_month,$start_year,$end_month,$end_year);
}

sub month_start_dates {
    my($start_month,$start_year,$end_month,$end_year) = @_;

    my @dates;
    my $end_days = Date::Calc::Date_to_Days($end_year, $end_month, 1);
    for (my @dt = ($start_year, $start_month, 1);
         Date::Calc::Date_to_Days(@dt) <= $end_days;
         @dt = Date::Calc::Add_Delta_YM(@dt, 0, 1)) {
            push(@dates, [ $dt[0], $dt[1], $dt[2] ]);
    }

    return \@dates;
}

sub nav_pagination {
    my($start_month,$start_year,$end_month,$end_year) = @_;

    my($prev_url,$next_url,$prev_title,$next_title) = next_and_prev_urls($q);

    my $prev_nofollow = ($q->param("month") =~ /^\d+$/
             || $start_year < $this_year
            ) ? " nofollow" : "";
    my $next_nofollow = ($q->param("month") =~ /^\d+$/
             || $end_year > $this_year + 2
            ) ? " nofollow" : "";

    my $nav_pagination = <<EOHTML;
<nav class="text-center d-print-none">
<ul class="pagination">
<li class="page-item"><a class="page-link" href="$prev_url" rel="prev$prev_nofollow">&laquo; $prev_title</a></li>
EOHTML
    ;

    my $dates = month_start_dates($start_month,$start_year,$end_month,$end_year);
    foreach my $dt (@{$dates}) {
        my $year = $dt->[0];
        my $mon = $dt->[1];
        my $mon_long = $Hebcal::MoY_long{$mon};
        my $mon_short = $Hebcal::MoY_short[$mon-1];
        my $cal_id = sprintf("%04d-%02d", $year, $mon);
        $nav_pagination .= qq{<li class="page-item"><a class="page-link" title="$mon_long $year" href="#cal-$cal_id">$mon_short</a></li>\n};
    }
    $nav_pagination .= <<EOHTML;
<li class="page-item"><a class="page-link" href="$next_url" rel="next$next_nofollow">$next_title &raquo;</a></li>
</ul><!-- .pagination -->
</nav>
EOHTML
    ;

    return $nav_pagination;
}

sub next_and_prev_urls {
    my($q) = @_;
    my($prev_url,$next_url,$prev_title,$next_title);

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
    return ($prev_url,$next_url,$prev_title,$next_title);
}

sub results_page_warnings {
    my($events) = @_;

    if (defined $events && defined $events->[0]) {
        my $greg_year1 = $events->[0]->{year};

        print $HebcalHtml::gregorian_warning
            if ($greg_year1 <= 1752);

        if ($greg_year1 >= 3762 && $g_year_type eq "G")
        {
            my $future_years = $greg_year1 - $this_year;
            my $new_url = Hebcal::self_url($q,
                                           {"yt" => "H", "month" => "x"},
                                           "&amp;");
            print qq{<div class="alert alert-warning alert-dismissible">
<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
<strong>Note!</strong>
You are viewing a calendar for <strong>Gregorian</strong> year $greg_year1, which
is $future_years years <em>in the future</em>.</span><br>
Did you really mean to do this? Perhaps you intended to get the calendar
for <a href="$new_url">Hebrew year $greg_year1</a>?<br>
If you really intended to use Gregorian year $greg_year1, please
continue. Hebcal.com results this far in the future should be
accurate.
</div><!-- .alert -->
};
        }
    }

    print $HebcalHtml::indiana_warning
        if (defined $cconfig{"state"} && $cconfig{"state"} eq "IN");

    print $HebcalHtml::arizona_warning
        if (defined $cconfig{"state"} && $cconfig{"state"} eq "AZ"
            && defined $cconfig{"tzid"} && $cconfig{"tzid"} eq "America/Denver");

    my $latitude = $cconfig{"latitude"};
    print $HebcalHtml::usno_warning
        if (defined $latitude && ($latitude >= 60.0 || $latitude <= -60.0));
}

sub settings_button_html {
    my $settings_url = Hebcal::self_url($q, {"v" => "0"}, "&amp;");
    return qq{<a class="btn btn-secondary btn-sm" href="$settings_url" title="Change calendar options"><i class="glyphicons glyphicons-cog"></i> Settings</a>};
}

sub results_page_toolbar {
    my($filename) = @_;

    my $html = <<EOHTML;
<div class="d-print-none">
  <div class="btn-group mr-2" role="group" data-toggle="buttons">
   <label class="btn btn-secondary btn-sm active">
    <input type="radio" name="view" id="toggle-month" checked>
    <span class="glyphicons glyphicons-calendar"></span> Month
   </label>
   <label class="btn btn-secondary btn-sm">
    <input type="radio" name="view" id="toggle-list">
    <span class="glyphicons glyphicons-list"></span> List
   </label>
  </div><!-- .btn-group -->
EOHTML
;

    $html .= qq{<div class="btn-group mr-1" role="group">};
    $html .= HebcalHtml::download_html_modal_button(" btn-sm");
    $html .= qq{</div>\n};

    my $pdf_url = Hebcal::download_href($q, $filename, "pdf");
    $pdf_url =~ s/&/&amp;/g;
    my $btn_print_html = qq{<div class="btn-group" role="group"><a class="btn btn-secondary btn-sm download" id="print-pdf" href="$pdf_url"><i class="glyphicons glyphicons-print"></i> Print</a></div>};

    if (!param_true("c")) {
        $html .= $btn_print_html;
    } else {
        # Fridge
        my $url = "/shabbat/fridge.cgi?";
        $url .= Hebcal::get_geo_args($q, "&amp;");
        my $hyear = Hebcal::get_default_hebrew_year($this_year,$this_mon,$this_day);
        $url .= "&amp;year=$hyear";
        $url .= "&amp;m=" . $q->param("m")
            if defined $q->param("m") && $q->param("m") =~ /^\d+$/;

        my $lang = $q->param("lg") || "s";
        $url .= "&amp;lg=$lang";

#        my $email_url = "https://www.hebcal.com/email/?geo=" . $cconfig{"geo"} . "&amp;";
#        $email_url .= Hebcal::get_geo_args($q, "&amp;");
#        $email_url .= "&amp;m=" . $q->param("m")
#            if defined $q->param("m") && $q->param("m") =~ /^\d+$/;

        $html .= <<EOHTML;
  <div class="btn-group mr-2" role="group">
    $btn_print_html
    <button type="button" class="btn btn-secondary btn-sm dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
        <span class="caret"></span>
        <span class="sr-only">Toggle Dropdown</span>
    </button>
    <ul class="dropdown-menu">
      <li><a class="dropdown-item download" id="pdf" href="$pdf_url">Monthly calendar</a></li>
      <li><a class="dropdown-item" href="$url">Candle-lighting times only</a></li>
    </ul>
  </div>
EOHTML
;
    }

    my $settings_button_html = settings_button_html();
    $html .= <<EOHTML;
  $settings_button_html
</div><!-- .btn-toolbar -->
EOHTML
;

    return $html;
}

sub results_page
{
    my($date,$filename) = @_;

    eval("use HTML::CalendarMonthSimple ();");

    if (param_true("c"))
    {
        if ($cconfig{"geo"} eq "zip")
        {
            $filename .= "_" . $q->param("zip");
        }
        elsif (defined $cconfig{"city"} && $cconfig{"city"} ne "")
        {
            my $tmp = $cconfig{"city"};
            $tmp =~ s/[^A-Za-z0-9]/_/g;
            $filename .= "_" . $tmp;
        }
    }

    possibly_set_cookie();

    my $results_title = "Jewish Calendar $date";
    if (defined $cconfig{"city"} && $cconfig{"city"} ne "") {
        $results_title .= " "  . $cconfig{"city"};
    }

    print STDOUT $q->header(-cache_control => $http_cache_control,
                            -type => $content_type,
                            -charset => "UTF-8");

    my $xtra_head = <<EOHTML;
<style>
div.cal { margin-bottom: 18px }
div.pbba { page-break-before: always }
\@media print { div.pbba { page-break-before: always } }
.fc-emulated-table {
  table-layout: fixed;
}
.fc-emulated-table tr th, .fc-emulated-table tr td {
  padding: 4px;
}
.fc-emulated-table tr th {
  text-align: center;
}
.fc-emulated-table tr td {
  height: 90px;
}
.fc-event {
    display: block; /* make the <a> tag block */
    font-size: .85em;
    line-height: 1.3;
    border-radius: 3px;
    border: 1px solid #3a87ad; /* default BORDER color */
    background-color: #3a87ad; /* default BACKGROUND color */
    margin: 1px 2px 0; /* spacing between events and edges */
    padding: 0 1px;
}
.fc-time {
  font-weight: bold;
}
.fc-event a {
    color: #fff;
}
.fc-event a:hover,
.fc-event a:focus {
    color: #fff;
}
.fc-event.hebdate, .fc-event.omer {
  background-color:#FFF;
  border-color:#FFF;
  color:#999;
}
.fc-event.dafyomi,
.fc-event.dafyomi a {
  background-color:#FFF;
  border-color:#FFF;
  color:#08c;
}
.fc-event.dafyomi a:hover,
.fc-event.dafyomi a:focus {
    color: #005580;
}
.fc-event.candles, .fc-event.havdalah {
  background-color:#FFF;
  border-color:#FFF;
  color:#333;
}
.fc-event.holiday {
  background-color:#3a87ad;
  border-color:#3a87ad;
  color:#FFF;
}
.fc-event.holiday.yomtov,
.fc-event.holiday.yomtov a {
  background-color:#ffd446;
  border-color:#ffd446;
  color:#333;
}
.fc-event.parashat {
  background-color:#257e4a;
  border-color:#257e4a;
  color:#FFF;
}
.fc-event.hebrew .fc-title {
  font-family:'Alef Hebrew','SBL Hebrew',David;
  font-size:110%;
  font-weight:normal;
  direction:rtl;
}
.fc-event.hebrew .fc-time {
  direction:ltr;
  unicode-bidi: bidi-override;
}
.label-lightgrey {
  background-color: #e7e7e7;
  background-image: -webkit-linear-gradient(#fefefe, #e7e7e7);
  background-image: linear-gradient(#fefefe, #e7e7e7);
  border: 1px solid #cfcfcf;
  border-radius: 2px;
}
.table-event.yomtov {
  background:#ff9;
}
</style>
EOHTML
;

    my $lang = $q->param("lg") || "s";
    my $lang_hebrew = ($lang && $lang =~ /h/) ? 1 : 0;

    print HebcalHtml::header_bootstrap3($results_title,
        $script_name, "", $xtra_head, 0, $lang_hebrew);

    my $h1_extra = "";
    if (param_true("c")) {
        $h1_extra = "<br><small class=\"text-muted\">" . $cconfig{"title"} . "</small>";
    } else {
        my $where = param_true("i") ? "Israel" : "Diaspora";
        $h1_extra = " <small class=\"text-muted\">$where</small>";
    }

    my $head_divs = <<EOHTML;
<div class="row">
<div class="col-sm-8">
<h2>Jewish Calendar $date$h1_extra</h2>
<!-- $cmd -->
EOHTML
;
    print $head_divs;

    my @events = my_invoke_hebcal();
    push(@benchmarks, Benchmark->new);

    results_page_warnings(\@events);

    my $numEntries = scalar(@events);

    if ($numEntries > 0) {
        print results_page_toolbar($filename);
    } else {
        print qq{<div class="alert alert-warning">No Hebrew Calendar events for $date</div>\n},
            settings_button_html();
    }

    print "</div><!-- .col-sm-8 -->\n";

    my $header_ad = <<EOHTML;
<div class="col-sm-4 d-print-none">
<h4 style="font-size:14px;margin-bottom:4px">Advertisement</h4>
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- banner-320x100 -->
<ins class="adsbygoogle"
 style="display:inline-block;width:320px;height:100px"
 data-ad-client="ca-pub-7687563417622459"
 data-ad-slot="1867606375"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .col-sm-4 -->
</div><!-- .row -->
EOHTML
;
    print $header_ad;

    print "<div id=\"hebcal-results\">\n";

    my @html_cals;
    my %html_cals;
    my @html_cal_ids;
    my $nav_pagination = "";

    # make blank calendar month objects for every month in the date range
    if ($numEntries > 0) {
        my($start_month,$start_year,$end_month,$end_year) = get_start_and_end(\@events);
        $nav_pagination = nav_pagination($start_month,$start_year,$end_month,$end_year);
        my $dates = month_start_dates($start_month,$start_year,$end_month,$end_year);
        foreach my $dt (@{$dates}) {
            my $year = $dt->[0];
            my $mon = $dt->[1];
            my $cal = new_html_cal($year, $mon);
            my $cal_id = sprintf("%04d-%02d", $year, $mon);
            push(@html_cals, $cal);
            push(@html_cal_ids, $cal_id);
            $html_cals{$cal_id} = $cal;
        }
    }

    print $nav_pagination;

    push(@benchmarks, Benchmark->new);

    foreach my $evt (@events) {
        my($year,$mon,$mday) = Hebcal::event_ymd($evt);

        my $subj = my_translate_event($q,$evt);
        $subj = qq{<span class="fc-title">$subj</span>};

        my $a_start = "";
        my $a_end = "";

        my $href = $evt->{href};
        if (defined $href && $href ne "")
        {
            my $memo = $evt->{memo};
            my $atitle = $memo ? qq{ title="$memo"} : "";
            my $aclass = "";
            if (index($href, "https://www.hebcal.com/") == 0) {
                $href = substr($href, 22);
            }
            if ($href =~ /^http/) {
              $aclass = qq{ class="outbound"};
            }
            $a_start = qq{<a$atitle$aclass href="$href">};
            $a_end = qq{</a>};
        }

        my $cal_subj;
        if ($evt->{untimed}) {
            $cal_subj = $subj;
        } else {
            my $time_formatted = Hebcal::format_evt_time($evt, "p", $lang);
            $cal_subj = sprintf(qq{<span class="fc-time">%s</span> %s},
                $time_formatted, $subj);
        }

        $cal_subj =~
            s/Havdalah \((\d+) min\)/Havdalah <small>($1 min)<\/small>/;
        $cal_subj =~ s/Daf Yomi: //;

        my $cal_id = sprintf("%04d-%02d", $year, $mon);
        my $cal = $html_cals{$cal_id};

        my $category = $evt->{category};
        my $class = "fc-event $category";
        if ($evt->{yomtov} == 1)
        {
            $class .= " yomtov";
        }

        $cal->addcontent($mday, qq{<div class="$class">$a_start$cal_subj$a_end</div>});
    }

    push(@benchmarks, Benchmark->new);

    for (my $i = 0; $i < @html_cals; $i++) {
        write_html_cal($q, \@html_cals, \@html_cal_ids, $i);
    }

    push(@benchmarks, Benchmark->new);

    print $nav_pagination;

    print "</div><!-- #hebcal-results -->\n";

    html_table_events(\@events);
    push(@benchmarks, Benchmark->new);

    my $single_month = $q->param('month') eq 'x' ? 'false' : 'true';
    my $xtra_html=<<JSCRIPT_END;
<script src="//cdnjs.cloudflare.com/ajax/libs/moment.js/2.8.4/moment.min.js"></script>
<script src="$Hebcal::JS_APP_URL"></script>
<script>
\$(document).ready(function() {
    \$('#toggle-month').on('change', function() {
        \$('div.agenda').hide();
        \$('div.cal').show();
    });
    \$('#toggle-list').on('change', function() {
        \$('div.cal').hide();
        window['hebcal'].renderMonthTables();
        \$('div.agenda').show();
    });
    if (\$(window).width() < 768) {
        \$('#toggle-list').click();
    }
});
</script>
JSCRIPT_END
        ;

    print HebcalHtml::footer_bootstrap3($q,undef,1,$xtra_html);

    if ($numEntries > 0) {
        my $download_title = $date;
        if (defined $q->param("month") && $q->param("month") eq "x" && $date =~ /(\d+)/ && $EXTRA_YEARS) {
            my $plus4 = $1 + $EXTRA_YEARS;
            $download_title .= "-" . $plus4;
        }
        print HebcalHtml::download_html_modal($q, $filename, \@events, $download_title, 0, 1);
    }

    print "</body></html>\n";

    for (my $i = 1; $i < scalar(@benchmarks); $i++) {
        my $tdiff = timediff($benchmarks[$i], $benchmarks[$i-1]);
        print "<!-- ", timestr($tdiff), " -->\n";
    }

    timestamp_comment();

    1;
}

sub html_table_events {
    my($events) = @_;
    my $dict = Hebcal::events_to_dict($events,"json",$q,0,0,$cconfig{"tzid"},1,0);
    my $items = Hebcal::json_transform_items($dict,$q);
    eval("use JSON");
    my $json = JSON->new;
    my $out = $json->encode($items);
    my $json_cconfig = $json->encode(\%cconfig);
    my $lang = $q->param("lg") || "s";
    print "<script>\nwindow['hebcal']=window['hebcal']||{};\n",
        "window['hebcal'].lang='$lang';\n",
        "window['hebcal'].events=", $out, ";\n",
        "window['hebcal'].cconfig=", $json_cconfig, ";\n</script>\n";
}

sub write_html_cal
{
    my($q,$cals,$cal_ids,$i) = @_;
    my $lang = $q->param("lg") || "s";
    my $dir = "";
    if ($lang eq "h") {
        $dir = qq{ dir="rtl"};
    }
    my $cal = $cals->[$i];
    my $id = $cal_ids->[$i];
    my($year,$month) = split(/-/, $id, 2);
    $month =~ s/^0//;
    my $header = $lang eq "h"
        ? sprintf(qq{<h2 lang="he">%s %s</h2>}, $Hebcal::MoY_hebrew[$month-1], $year)
        : sprintf("<h3>%s %s</h3>", $Hebcal::MoY_long{$month}, $year);
    my $style = "";
    my $class = "cal";
    if ($i != 0) {
        $class .= " pbba";
        $style = qq{ style="page-break-before:always"};
    }
    if ($id eq sprintf("%04d-%02d", $this_year, $this_mon)) {
        print qq{<div id="cal-current"></div>\n};
    }
    my $cal_html = $cal->as_HTML();
    $cal_html =~ s/ border="0" width="100%">/>/;
    $cal_html =~ s/<td width="14%" valign="top" align="left">/<td>/g;
    print qq{<div id="cal-$id">\n},
        qq{<div class="$class"$style$dir>\n},
        $header,
        $cal_html,
        qq{</div><!-- .cal -->\n},
        qq{<div class="agenda">\n},
        qq{</div><!-- .agenda -->\n},
        qq{</div><!-- #cal-$id -->\n};
}

sub new_html_cal
{
    my($year,$month) = @_;

    my $cal = new HTML::CalendarMonthSimple("year" => $year,
                                            "month" => $month);
    my $lang = $q->param("lg") || "s";
    if ($lang eq "h") {
        $cal->saturday($Hebcal::DoW_hebrew[6]);
        $cal->sunday($Hebcal::DoW_hebrew[0]);
        $cal->weekdays(@Hebcal::DoW_hebrew[1..5]);
    } else {
        $cal->saturday('Sat');
        $cal->sunday('Sun');
        $cal->weekdays('Mon','Tue','Wed','Thu','Fri');
    }
    $cal->border(0);
    $cal->tableclass("table table-bordered fc-emulated-table");
    $cal->header('');

    $cal;
}

# local variables:
# mode: cperl
# end:
