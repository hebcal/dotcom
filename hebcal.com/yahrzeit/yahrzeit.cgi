#!/usr/bin/perl -w

########################################################################
# compute yahrzeit dates based on gregorian calendar based on Hebcal
#
# Copyright (c) 2019  Michael J. Radwin.
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
use Encode qw(decode_utf8);
use Hebcal ();
use HebcalGPL ();
use HebcalHtml ();
use POSIX ();
use Date::Calc ();
use File::Temp ();

my @HEB_MONTH_NAME =
(
  [
    "VOID", "Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
    "Cheshvan", "Kislev", "Tevet", "Sh'vat", "Adar", "Nisan"
  ],
  [
    "VOID", "Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
    "Cheshvan", "Kislev", "Tevet", "Sh'vat", "Adar I", "Adar II",
    "Nisan"
  ]
);

# process form params
my $q = new CGI;

Hebcal::process_b64_download_pathinfo($q);

my $script_name = $q->script_name();
$script_name =~ s,/[^/]+$,/,;

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
foreach my $key ($q->param())
{
    next if $key =~ /^ref_(url|text)$/;
    my $val = $q->param($key);
    if (defined $val) {
        my $orig = $val;
        if ($key =~ /^n\d+$/) {
            $val = decode_utf8($val);
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

my $count;
if (defined $q->param("count") && $q->param("count") =~ /^\d+$/) {
    $count = $q->param("count");
} else {
    $count = 1;
    foreach my $key ($q->param()) {
        if ($key =~ /^[dy](\d+)$/) {
            my $n = $1;
            if ($q->param($key) =~ /^\d+$/) {
                $count = $n if $n > $count;
            }
        }
    }
    $count += 5;
}

my $num_years = 20;
if (defined $q->param("years") && $q->param("years") =~ /^\d+$/) {
    $num_years = $q->param("years");
    $num_years = 99 if $num_years > 99;
}

my @inputs = ();
my %input_types;
my %input_names;
foreach my $key (1 .. $count)
{
    if (defined $q->param("m$key") &&
        defined $q->param("d$key") &&
        defined $q->param("y$key") &&
        $q->param("m$key") =~ /^\d{1,2}$/ &&
        $q->param("d$key") =~ /^\d{1,2}$/ &&
        $q->param("y$key") =~ /^\d{2,4}$/)
    {
        $q->param("y$key", "19" . $q->param("y$key"))
            if $q->param("y$key") =~ /^\d{2}$/;
        $q->param("n$key", "Person$key") unless $q->param("n$key");

        my $gm = $q->param("m$key");
        my $gd = $q->param("d$key");
        my $gy = $q->param("y$key");

        # after sunset?
        if (param_true("s$key"))
        {
            ($gy,$gm,$gd) = Date::Calc::Add_Delta_Days($gy,$gm,$gd,1);
        }

        my $type = $q->param("t$key") || "Yahrzeit";
        my $name = $q->param("n$key");
        push(@inputs, [$key, $gy, $gm, $gd, $name, $type]);
        $input_types{$type} = 1;
        $input_names{$name} = 1;
    }
}

if (! defined $q->path_info())
{
    results_page();
}
elsif ($q->path_info() =~ /[^\/]+.csv$/)
{
    csv_display();
}
elsif ($q->path_info() =~ /[^\/]+.dba$/)
{
    dba_display();
}
elsif ($q->path_info() =~ /[^\/]+\.[vi]cs$/)
{
    # text/x-vCalendar
    vcalendar_display();
}
elsif (defined $q->param("cfg") && $q->param("cfg") eq "json")
{
    json_display();
}
else
{
    results_page();
}

close(STDOUT);
exit(0);

sub get_title {
    my($escape_comma) = @_;
    my $title;
    my @types = keys %input_types;
    if (scalar(@types) == 1) {
        $title = $types[0];
    } else {
        $title = "Anniversary";
    }

    my @names = sort keys %input_names;
    if (scalar(@names) > 3) {
        @names = @names[0 .. 2];
        push(@names, "...");
    }
    my $sep = $escape_comma ? '\, ' : ', ';
    $title .= " for " . join($sep, @names);
    return $title;
}

sub json_display {
    my @events = my_invoke_hebcal();
    my $items = Hebcal::events_to_dict(\@events,"json",$q,0,0);

    print STDOUT $q->header(-type => "application/json",
                            -charset => "UTF-8",
                            -cache_control => "private",
                            -access_control_allow_origin => '*',
                            );
    my $title = get_title(0);
    Hebcal::items_to_json($items,$q,$title);
}

sub vcalendar_display
{
    my @events = my_invoke_hebcal();

    my $title = get_title(1);
    eval("use HebcalExport");
    HebcalExport::vcalendar_write_contents($q, \@events, $title, undef);
}

sub dba_display
{
    print STDOUT $q->header(-type => "text/plain",
                            -status => "410 Gone");
    print STDOUT "Palm DBA download support removed.\n";
    exit(0);
}

sub csv_display
{
    my @events = my_invoke_hebcal();

    my $euro = defined $q->param("euro") ? 1 : 0;
    eval("use HebcalExport");
    HebcalExport::csv_write_contents($q, \@events, $euro, undef);
}


sub get_birthday_or_anniversary {
    my($gy,$gm,$gd,$hyear) = @_;

    my $orig = HebcalGPL::greg2hebrew($gy,$gm,$gd);
    my $res = {"dd" => $orig->{"dd"}, "mm" => $orig->{"mm"}, "yy" => $hyear};

    # The birthday of someone born in Adar of an ordinary year or
    # Adar II of a leap year is also always in the last month of the
    # year, be that Adar or Adar II.
    if (($orig->{"mm"} == $HebcalGPL::ADAR_I && !HebcalGPL::LEAP_YR_HEB($orig->{"yy"}))
        || ($orig->{"mm"} == $HebcalGPL::ADAR_II && HebcalGPL::LEAP_YR_HEB($orig->{"yy"})))
    {
        $res->{"mm"} = HebcalGPL::MONTHS_IN_HEB($hyear);
    }
    # The birthday in an ordinary year of someone born during the
    # first 29 days of Adar I in a leap year is on the corresponding
    # day of Adar; in a leap year, the birthday occurs in Adar I, as
    # expected.
    #
    # Someone born on the thirtieth day of Marcheshvan, Kislev, or
    # Adar I has his birthday postponed until the first of the
    # following month in years where that day does not
    # occur. [Calendrical Calculations p. 111]
    elsif ($orig->{"mm"} == $HebcalGPL::CHESHVAN && $orig->{"dd"} == 30
           && !HebcalGPL::long_cheshvan($hyear))
    {
        $res->{"mm"} = $HebcalGPL::KISLEV;
        $res->{"dd"} = 1;
    }
    elsif ($orig->{"mm"} == $HebcalGPL::KISLEV && $orig->{"dd"} == 30
           && HebcalGPL::short_kislev($hyear))
    {
        $res->{"mm"} = $HebcalGPL::TEVET;
        $res->{"dd"} = 1;
    }
    elsif ($orig->{"mm"} == $HebcalGPL::ADAR_I && $orig->{"dd"} == 30
           && HebcalGPL::LEAP_YR_HEB($orig->{"yy"})
           && !HebcalGPL::LEAP_YR_HEB($hyear))
    {
        $res->{"mm"} = $HebcalGPL::NISAN;
        $res->{"dd"} = 1;
    }

    $res;
}

sub format_hdate {
    my($hdate) = @_;
    return sprintf("%d%s of %s",
        $hdate->{"dd"},
        HebcalGPL::numSuffix($hdate->{"dd"}),
        $HEB_MONTH_NAME[HebcalGPL::LEAP_YR_HEB($hdate->{"yy"})][$hdate->{"mm"}]);
}

sub my_invoke_hebcal {
    my %yahrzeits;
    my %date_of_death;
    my($fh,$tmpfile) = File::Temp::tempfile();
    binmode( $fh, ":utf8" );
    foreach my $input (@inputs) {
        my($key,$gy,$gm,$gd,$name,$type) = @{$input};
        if ($type eq "Yahrzeit") {
            my $hebcal_name = "YahrzeitPerson" . $key;
            printf $fh "%02d %02d %4d %s\n", $gm, $gd, $gy, $hebcal_name;
            $yahrzeits{$hebcal_name} = $name;
            $date_of_death{$hebcal_name} = Date::Calc::Date_to_Days($gy, $gm, $gd);
        }
    }
    close($fh);

    my @events2 = ();

    my($this_year,$this_mon,$this_day) = Date::Calc::Today();
    my $this_abs_days = Date::Calc::Date_to_Days($this_year,$this_mon,$this_day);
    my $cmd = "./hebcal -x -Y $tmpfile --years $num_years $this_year";
    my @events = Hebcal::invoke_hebcal_v2($cmd, "", undef);
    foreach my $evt (@events) {
        my $subj = $evt->{subj};
        my($year,$mon,$mday) = Hebcal::event_ymd($evt);
        my $abs_days = Date::Calc::Date_to_Days($year, $mon, $mday);
        next if $abs_days < $this_abs_days;

        if (defined $yahrzeits{$subj}) {
            # ignore events before or on the actual anniversary.
            next if $date_of_death{$subj} >= $abs_days;

            my $name = $yahrzeits{$subj};
            my $subj2 = "${name}'s Yahrzeit";
            if ($q->param("hebdate")) {
                my $hdate = HebcalGPL::greg2hebrew($year,$mon,$mday);
                $subj2 .= " (" . format_hdate($hdate) . ")";
            }

            my $evt2 = {
                subj => $subj2,
                untimed => 1,
                min => 0,
                hour => 0,
                mday => $evt->{mday},
                mon => $evt->{mon},
                year => $evt->{year},
                dur => 0,
                memo => "",
                yomtov => 0,
                category => "yahrzeit",
            };
            push(@events2, $evt2);
        }
        elsif ($subj eq "Pesach VIII" || $subj eq "Shavuot II" ||
                $subj eq "Yom Kippur" || $subj eq "Shmini Atzeret")
        {
            next unless defined $q->param("yizkor") &&
                ($q->param("yizkor") eq "on" ||
                    $q->param("yizkor") eq "1");

            my %evt_copy = map { $_, $evt->{$_} } keys %{$evt};
            $evt_copy{subj} = "Yizkor ($subj)";
            push(@events2, \%evt_copy);
        }
    }
    unlink($tmpfile);

    foreach my $year ($this_year .. ($this_year + $num_years))
    {
        my $hyear = $year + 3760;
        # first process birthday and anniversaries
        foreach my $input (@inputs) {
            my($key,$gy,$gm,$gd,$name,$type) = @{$input};
            next if $type eq "Yahrzeit";
            my $hdate = get_birthday_or_anniversary($gy,$gm,$gd,$hyear);
            my $gregdate = HebcalGPL::abs2greg(HebcalGPL::hebrew2abs($hdate));

            # ignore events before or on the actual anniversary.
            my $orig_days = Date::Calc::Date_to_Days($gy, $gm, $gd);
            my $abs_days  = Date::Calc::Date_to_Days($gregdate->{"yy"}, $gregdate->{"mm"}, $gregdate->{"dd"});
            next if $orig_days >= $abs_days;
            next if $abs_days < $this_abs_days;

            my $subj = "${name}'s Hebrew ${type}";
            if ($q->param("hebdate")) {
                $subj .= " (" . format_hdate($hdate) . ")";
            }

            my $evt = {
                subj => $subj,
                untimed => 1,
                min => 0,
                hour => 0,
                mday => $gregdate->{"dd"},
                mon => $gregdate->{"mm"} - 1,
                year => $gregdate->{"yy"},
                dur => 0,
                memo => "",
                yomtov => 0,
                category => "hebrew-" . lc($type),
            };
            push(@events2, $evt);
        }

    }

    sort { Hebcal::event_to_time($a) <=> Hebcal::event_to_time($b) } @events2;
}

sub results_page {
    my $type = "text/html";

    print STDOUT $q->header(-type => "$type;charset=UTF-8");

    my $xtra_head = <<EOHTML;
<meta name="keywords" content="yahzeit,yahrzeit,yohrzeit,yohrtzeit,yartzeit,yarzeit,yortzeit,yorzeit,yizkor,yiskor,kaddish">
<style type="text/css">
\@media (min-width: 768px) {
 .form-inline .radio label {
    padding-left: 8px;
 }
}
div.yahrzeit-row {
  border-bottom:1px solid #dddddd;
  padding:4px;
}
.yahrzeit-form > div.yahrzeit-row:nth-of-type(odd) {
  background-color: #f9f9f9;
}
</style>
EOHTML
;

    if (scalar(@inputs) >= 1) {
        $xtra_head .= qq{<meta name="robots" content="noindex">\n};
    }

    print HebcalHtml::header_bootstrap3("Yahrzeit + Anniversary Calendar",
        $script_name, "", $xtra_head);
    print qq{<div class="row">\n<div class="col-sm-12">\n};

    if ($q->param("ref_url"))
    {
        my $ref_url = $q->param("ref_url");
        my $ref_text = $q->param("ref_text") || $ref_url;
        print qq{<div class="alert alert-info alert-dismissible" role="alert" style="margin-top:12px">
  <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
<p>Welcome to the Hebcal Yahrzeit + Anniversary Calendar.</p>
<p><a href="$ref_url">Return to $ref_text</a></p>
</div><!-- .alert -->
};
    }

    form(1,'') unless scalar(@inputs) >= 1;

    my @events = my_invoke_hebcal();

    if (scalar(@events) > 0) {
        $q->param("v", "yahrzeit");

        print qq{<div class="btn-toolbar d-print-none">\n};
        print qq{<div class="mr-1">\n};
        print HebcalHtml::download_html_modal_button();
        print qq{</div>\n};
        print qq{<a class="btn btn-secondary" href="#form"><i class="glyphicons glyphicons-cog"></i> Enter more dates and names</a>\n};
        print qq{</div><!-- .btn-toolbar -->\n};

        print qq{<p>Yahrzeit candles should be lit
the evening before the date specified. This is because the Jewish
day actually begins at sundown on the previous night.</p>\n};
    }

    foreach my $evt (@events) {
        my($gy,$gm,$gd) = Hebcal::event_ymd($evt);
        my $hdate = HebcalGPL::greg2hebrew($gy,$gm,$gd);
        if ($hdate->{"mm"} >= $HebcalGPL::ADAR_I) {
            print qq{<div class="alert alert-info alert-dismissible" role="alert">
  <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
<strong>Note:</strong> the results below contain one or more anniversary in Adar.
To learn more about how Hebcal handles these dates, read <a
href="/home/54/how-does-hebcal-determine-an-anniversary-occurring-in-adar">How
does Hebcal determine an anniversary occurring in Adar?</a>
</div><!-- .alert -->
};
            last;
        }
    }

    print qq{<table class="table table-condensed table-striped">}
        unless $q->param("yizkor");

    my $prev_year = 0;
    foreach my $evt (@events)
    {
        my $subj = $evt->{subj};
        my($year,$mon,$mday) = Hebcal::event_ymd($evt);

        if ($year != $prev_year && $q->param("yizkor"))
        {
            print "</table>" unless $prev_year == 0;
            print qq{<h4>$year</h4>\n<table class="table table-condensed table-striped">};
        }

        my $dow = $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)] . " ";

        printf(qq{<tr><td style="width:170px"><strong>%s%02d-%s-%04d</strong></td><td>%s</td></tr>\n},
            $dow, $mday, $Hebcal::MoY_short[$mon-1], $year,
            HebcalHtml::html_entify($subj));
        $prev_year = $year;
    }

    print "</table>\n";

    my $xtra_html = '';
    if (scalar(@events) > 0) {
        my $title;
        my @types = keys %input_types;
        if (scalar(@types) == 1) {
            $title = $types[0];
        } else {
            $title = "Anniversary";
        }

        my $filename = join("_", lc($title), POSIX::strftime("%Y%m%d%H%M%S", gmtime(time())));

        remove_empty_parameters($q);
        $xtra_html = HebcalHtml::download_html_modal($q, $filename, \@events, $title, 1, 1);
    }

    print qq{<h3 id="form" class="d-print-none">Enter more dates and names</h3>\n};

    form(0,$xtra_html);
}

# remove empty parameters from long download link
sub remove_empty_parameters {
    my($q) = @_;

    my %nonempty;
    foreach my $input (@inputs) {
        $nonempty{$input->[0]} = 1;
    }
    my @to_delete;
    foreach my $key ($q->param()) {
        if ($key =~ /^[tdmyns](\d+)$/) {
            unless ($nonempty{$1}) {
                push(@to_delete, $key);
            }
        }
    }
    if (! $q->param("ref_url")) {
        push(@to_delete, qw(ref_url ref_text));
    }
    # don't delete while iterating through the parameters
    foreach my $key (@to_delete) {
        $q->delete($key);
    }
}

sub form
{
    my($head,$xtra_html) = @_;

    print qq{<div class="d-print-none">
<p class="lead">Generate a list of Yahrzeit dates, Hebrew Birthdays,
or Hebrew Anniversaries for the next 20 years.</p>
<p>For example, you might enter <strong>20 October 1994 (after
sunset)</strong> to calculate <strong>Reb Shlomo Carlebach</strong>&apos;s
yahrzeit.</p>
<p>If you know the Hebrew but not the Gregorian date, use the <a
href="/converter/">Hebrew Date Converter</a> to get the Gregorian date
and then come back to this page.</p>
</div><!-- .d-print-none -->
<form class="yahrzeit-form d-print-none" method="post" action="/yahrzeit/">
};

    for (my $i = 1; $i <= $count; $i++) {
        show_row($q,$i,\%Hebcal::MoY_long);
    }

    print "",
    HebcalHtml::checkbox($q,
                 -name => "hebdate",
                 -id => "hebdate",
                 -checked => "checked",
                 -label => "Include Hebrew dates"),
    "\n",
    HebcalHtml::checkbox($q,
                 -name => "yizkor",
                 -id => "yizkor",
                 -label => "Include Yizkor dates"),
    "\n",
    qq{<div class="form-group form-inline"><label for="years" class="mr-1">Number of years: </label>},
    $q->textfield(-name => "years",
                    -id => "years",
                  -class => "form-control",
                  -default => $num_years,
                  -pattern => '\d*',
                  -min => "1",
                  -max => "99",
                  -maxlength => 2,
                  -size => 2),
    "</div>\n",
    $q->hidden(-name => "ref_url"), "\n",
    $q->hidden(-name => "ref_text"), "\n",
    $q->hidden(-name => ".cgifields",
               -values => ["hebdate", "yizkor"],
               -override => 1), "\n",
    qq{<input type="submit" class=\"btn btn-primary\" value="Create Calendar"></form>\n};

    print qq{
<p class="d-print-none">Would you like to use this calendar for your website? See
<a href="/home/43/customizing-yahrzeit-birthday-and-anniversary-calendar-for-your-website">developer
instructions</a>.</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
};

    print HebcalHtml::footer_bootstrap3($q,undef,0,$xtra_html);

    exit(0);
}

sub show_row {
    my($q,$i,$months) = @_;

    print qq{<div class="form-inline yahrzeit-row">\n},
         qq{<div class="form-group mr-1">},
         $q->popup_menu(-name => "t$i",
                        -class => "form-control",
                        -values => ["Yahrzeit","Birthday","Anniversary"]),
         qq{</div>\n<div class="form-group mr-1">},
         $q->textfield(-name => "n$i",
                       -placeholder => "Name (optional)",
                       -class => "form-control"),
         qq{</div>\n<div class="form-group mr-1">},
         $q->textfield(-name => "d$i",
                       -class => "form-control",
                       -placeholder => "Day",
                       -pattern => '\d*',
                       -min => "1",
                       -max => "31",
                       -style => "width:auto",
                       -maxlength => 2,
                       -size => 2),
         qq{</div>\n<div class="form-group mr-1">},
         $q->popup_menu(-name => "m$i",
                        -class => "form-control",
                        -values => [1..12],
                        -labels => $months),
         qq{</div>\n<div class="form-group mr-1">},
         $q->textfield(-name => "y$i",
                        -class => "form-control",
                       -placeholder => "Year",
                       -pattern => '\d*',
                       -style => "width:auto",
                       -maxlength => 4,
                       -size => 4),
         qq{</div>\n<div class="form-group mr-1">},
         HebcalHtml::radio_group($q,
            -name => "s$i",
            -values => ["off", "on"],
            -default => "off",
            -labels => {"off" => " Before sunset",
                        "on" => " After sunset"}),
         qq{</div>\n},
         qq{</div><!-- .form-inline -->\n};
}

sub param_true {
    my($k) = @_;
    my $v = $q->param($k);
    return ((defined $v) && ($v ne "off") && ($v ne "0") && ($v ne "")) ? 1 : 0;
}

# local variables:
# mode: cperl
# end:
