#!/usr/local/bin/perl -w

########################################################################
# compute yahrzeit dates based on gregorian calendar based on Hebcal
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
use Hebcal ();
use HebcalGPL ();
use HebcalHtml ();
use Palm::DBA ();
use POSIX ();
use Date::Calc ();

my $this_year = (localtime)[5];
$this_year += 1900;

my $NISAN = 1;
my $IYYAR = 2;
my $SIVAN = 3;
my $TAMUZ = 4;
my $AV = 5;
my $ELUL = 6;
my $TISHREI = 7;
my $CHESHVAN = 8;
my $KISLEV = 9;
my $TEVET = 10;
my $SHVAT = 11;
my $ADAR_I = 12;
my $ADAR_II = 13;

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

my $script_name = $q->script_name();
$script_name =~ s,/[^/]+$,/,;

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
foreach my $key ($q->param())
{
    next if $key =~ /^ref_(url|text)$/;
    my $val = $q->param($key);
    $val = "" unless defined $val;
    $val =~ s/[^\w\s\.-]//g
	unless $key =~ /^n\d+$/;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

my $cfg = $q->param("cfg");
$cfg ||= "";

my $count;
if ($cfg eq "i" || $cfg eq "j") {
    $count = 1;
} elsif (defined $q->param("count") && $q->param("count") =~ /^\d+$/) {
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
	if ($q->param("s$key"))
	{
	    ($gy,$gm,$gd) = Date::Calc::Add_Delta_Days($gy,$gm,$gd,1);
	}

	my $type = $q->param("t$key");
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
else
{
    results_page();
}

close(STDOUT);
exit(0);

sub vcalendar_display
{
    my @events = my_invoke_hebcal($this_year);

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
    $title .= " for " . join('\, ', @names);

    Hebcal::vcalendar_write_contents($q, \@events, undef, undef, $title);
}

sub dba_display
{
    my @events = my_invoke_hebcal($this_year);

    Hebcal::export_http_header($q, "application/x-palm-dba");

    my $path_info = $q->path_info();
    $path_info =~ s,^.*/,,;

    Palm::DBA::write_header($path_info);
    Palm::DBA::write_contents(\@events, 0, 0);
}

sub csv_display
{
    my @events = my_invoke_hebcal($this_year);

    my $euro = defined $q->param("euro") ? 1 : 0;
    Hebcal::csv_write_contents($q, \@events, $euro);
}


sub get_birthday_or_anniversary {
    my($gy,$gm,$gd,$hyear) = @_;

    my $orig = HebcalGPL::greg2hebrew($gy,$gm,$gd);
    my $res = {"dd" => $orig->{"dd"}, "mm" => $orig->{"mm"}, "yy" => $hyear};

    # The birthday of someone born in Adar of an ordinary year or
    # Adar II of a leap year is also always in the last month of the
    # year, be that Adar or Adar II.
    if (($orig->{"mm"} == $ADAR_I && !HebcalGPL::LEAP_YR_HEB($orig->{"yy"}))
	|| ($orig->{"mm"} == $ADAR_II && HebcalGPL::LEAP_YR_HEB($orig->{"yy"})))
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
    elsif ($orig->{"mm"} == $CHESHVAN && $orig->{"dd"} == 30
	   && !HebcalGPL::long_cheshvan($hyear))
    {
	$res->{"mm"} = $KISLEV;
	$res->{"dd"} = 1;
    }
    elsif ($orig->{"mm"} == $KISLEV && $orig->{"dd"} == 30
	   && HebcalGPL::short_kislev($hyear))
    {
	$res->{"mm"} = $TEVET;
	$res->{"dd"} = 1;
    }
    elsif ($orig->{"mm"} == $ADAR_I && $orig->{"dd"} == 30
	   && HebcalGPL::LEAP_YR_HEB($orig->{"yy"})
	   && !HebcalGPL::LEAP_YR_HEB($hyear))
    {
	$res->{"mm"} = $NISAN;
	$res->{"dd"} = 1;
    }

    $res;
}

sub my_invoke_hebcal {
    my($this_year) = @_;
    my @events2 = ();

    my %yahrzeits;
    my $tmpfile = POSIX::tmpnam();
    open(T, ">$tmpfile") || die "$tmpfile: $!\n";
    foreach my $input (@inputs) {
	my($key,$gy,$gm,$gd,$name,$type) = @{$input};
	if ($type eq "Yahrzeit") {
	    printf T "%02d %02d %4d %s\n", $gm, $gd, $gy, $name;
	    $yahrzeits{$name} = 1;
	}
    }
    close(T);

    my $cmd = "./hebcal -D -x -Y $tmpfile";

    my %greg2heb = ();

    foreach my $year ($this_year .. ($this_year + $num_years))
    {
	my $hyear = $year + 3760;
	# first process birthday and anniversaries
	foreach my $input (@inputs) {
	    my($key,$gy,$gm,$gd,$name,$type) = @{$input};
	    next if $type eq "Yahrzeit";
	    my $hdate = get_birthday_or_anniversary($gy,$gm,$gd,$hyear);
	    my $gregdate = HebcalGPL::abs2greg(HebcalGPL::hebrew2abs($hdate));
	    push(@events2, [
		     sprintf("%s's Hebrew %s (%d%s of %s)",
			     $name, $type,
			     $hdate->{"dd"}, HebcalGPL::numSuffix($hdate->{"dd"}),
			     $HEB_MONTH_NAME[HebcalGPL::LEAP_YR_HEB($hdate->{"yy"})][$hdate->{"mm"}]),
		     1, # EVT_IDX_UNTIMED
		     0, # EVT_IDX_MIN
		     0, # EVT_IDX_HOUR
		     $gregdate->{"dd"},
		     $gregdate->{"mm"} - 1,
		     $gregdate->{"yy"},
		     0, # EVT_IDX_DUR
		     "", # EVT_IDX_MEMO
		     0, # EVT_IDX_YOMTOV,
		 ]);
	}

	my @events = Hebcal::invoke_hebcal("$cmd $year", "", undef);
	foreach my $evt (@events) {
	    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
	    my $year = $evt->[$Hebcal::EVT_IDX_YEAR];
	    my $mon = $evt->[$Hebcal::EVT_IDX_MON] + 1;
	    my $mday = $evt->[$Hebcal::EVT_IDX_MDAY];
	
	    if ($subj =~ /^(\d+\w+\s+of\s+.+),\s+\d{4}\s*$/)
	    {
		$greg2heb{sprintf("%04d%02d%02d", $year, $mon, $mday)} = $1;
		next;
	    }

	    if (defined $yahrzeits{$subj})
	    {
		my $subj2 = "${subj}'s Yahrzeit";
		my $isodate = sprintf("%04d%02d%02d", $year, $mon, $mday);

		$subj2 .= " ($greg2heb{$isodate})"
		    if ($q->param("hebdate") && defined $greg2heb{$isodate});

		push(@events2,
		     [$subj2,
		      1, # EVT_IDX_UNTIMED
		      0, # EVT_IDX_MIN
		      0, # EVT_IDX_HOUR
		      $evt->[$Hebcal::EVT_IDX_MDAY],
		      $evt->[$Hebcal::EVT_IDX_MON],
		      $evt->[$Hebcal::EVT_IDX_YEAR],
		      0, # EVT_IDX_DUR
		      "", # EVT_IDX_MEMO
		      0, # EVT_IDX_YOMTOV,
		      ]);
	    }
	    elsif ($subj eq "Pesach VIII" || $subj eq "Shavuot II" ||
		   $subj eq "Yom Kippur" || $subj eq "Shmini Atzeret")
	    {
		next unless defined $q->param("yizkor") &&
		    ($q->param("yizkor") eq "on" ||
		     $q->param("yizkor") eq "1");

		my @evt_copy = @{$evt};
		$evt_copy[$Hebcal::EVT_IDX_SUBJ] = "Yizkor ($subj)";
		push(@events2, \@evt_copy);
	    }
	}
    }

    unlink($tmpfile);
    sort { Hebcal::event_to_time($a) <=> Hebcal::event_to_time($b) } @events2;
}

sub results_page {
    my $type =  ($cfg eq "j") ? "text/javascript" : "text/html";

    print STDOUT $q->header(-type => "$type;charset=UTF-8");

    if ($cfg eq "j")
    {
	# nothing
    }
    else
    {
	my $xtra_head = <<EOHTML;
<meta name="keywords" content="yahzeit,yahrzeit,yohrzeit,yohrtzeit,yartzeit,yarzeit,yortzeit,yorzeit,yizkor,yiskor,kaddish">
EOHTML
;

	Hebcal::out_html($cfg,
			 Hebcal::html_header_bootstrap("Yahrzeit + Anniversary Calendar",
					     $script_name,
					     "single single-post",
					     $xtra_head)
	    );
    }

    if ($cfg eq "i" || $cfg eq "j")
    {
	my $self_url = join("", "http://", $q->virtual_host(), $script_name);
	if (defined $ENV{"HTTP_REFERER"} && $ENV{"HTTP_REFERER"} !~ /^\s*$/)
	{
	    $self_url .= "?.from=" . Hebcal::url_escape($ENV{"HTTP_REFERER"});
	}
	elsif ($q->param(".from"))
	{
	    $self_url .= "?.from=" . Hebcal::url_escape($q->param(".from"));
	}

	Hebcal::out_html
	    ($cfg,
	     "<h3><a target=\"_top\"\nhref=\"$self_url\">Yahrzeit,\n",
	     "Birthday and Anniversary\nCalendar</a></h3>\n");
    }

    if ($q->param("ref_url"))
    {
	my $ref_text = $q->param("ref_text") ? $q->param("ref_text") : 
	    $q->param("ref_url");
	Hebcal::out_html($cfg,
			  "<center><big><a href=\"", $q->param("ref_url"),
			  "\">Click\nhere to return to $ref_text",
			  "</a></big></center>\n");
    }

form(1) unless scalar(@inputs) >= 1;

my @events = my_invoke_hebcal($this_year);

if (scalar(@events) > 0) {
    $q->param("v", "yahrzeit");

    my $filename;
    my @types = keys %input_types;
    if (scalar(@types) == 1) {
	$filename = lc($types[0]);
    } else {
	$filename = "anniversary";
    }

    my @names = sort keys %input_names;
    if (scalar(@names) > 3) {
	@names = @names[0 .. 2];
    }
    @names = map { Hebcal::make_anchor($_) } @names;
    $filename .= "_" . join("_", @names);

    $q->param("filename", $filename);
    Hebcal::out_html($cfg, HebcalHtml::download_html_modal($q, $filename, \@events));

    Hebcal::out_html($cfg, qq{<div class="btn-toolbar">\n});
    Hebcal::out_html($cfg, HebcalHtml::download_html_modal_button());
    Hebcal::out_html($cfg, qq{<a class="btn" href="#form"><i class="icon-cog"></i> Enter more dates and names</a>\n});
    Hebcal::out_html($cfg, qq{</div><!-- .btn-toolbar -->\n});

    Hebcal::out_html($cfg,
		      qq{<p>Yahrzeit candles should be lit
the evening before the date specified. This is because the Jewish
day actually begins at sundown on the previous night.</p>\n});
}

foreach my $evt (@events) {
    my $hdate = HebcalGPL::greg2hebrew($evt->[$Hebcal::EVT_IDX_YEAR],
				       $evt->[$Hebcal::EVT_IDX_MON] + 1,
				       $evt->[$Hebcal::EVT_IDX_MDAY]);
    if ($hdate->{"mm"} >= $ADAR_I) {
	Hebcal::out_html($cfg, qq{<div class="alert alert-info">
<button type="button" class="close" data-dismiss="alert">&times;</button>
<strong>Note:</strong> the results below contain one or more anniversary in Adar.
To learn more about how Hebcal handles these dates, read <a
href="/home/54/how-does-hebcal-determine-an-anniversary-occurring-in-adar">How
does Hebcal determine an anniversary occurring in Adar?</a>
</div>});
	last;
    }
}

Hebcal::out_html($cfg, qq{<table class="table table-condensed table-striped">}) unless ($q->param("yizkor"));

my $prev_year = 0;
foreach my $evt (@events)
{
    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
    my $year = $evt->[$Hebcal::EVT_IDX_YEAR];
    my $mon = $evt->[$Hebcal::EVT_IDX_MON] + 1;
    my $mday = $evt->[$Hebcal::EVT_IDX_MDAY];

    if ($year != $prev_year && $q->param("yizkor"))
    {
	Hebcal::out_html($cfg, "</table>") unless $prev_year == 0;
	Hebcal::out_html($cfg, qq{<h4>$year</h4>\n<table class="table table-condensed table-striped">});
    }

    my $dow = $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)] . " ";

    Hebcal::out_html
	($cfg,
	 sprintf(qq{<tr><td style="width:130px"><strong>%s%02d-%s-%04d</strong></td><td>%s</td></tr>\n},
		 $dow, $mday, $Hebcal::MoY_short[$mon-1], $year,
		 Hebcal::html_entify($subj)));
    $prev_year = $year;
}

Hebcal::out_html($cfg, "</table>\n");

Hebcal::out_html($cfg, qq{<h3 id="form">Enter more dates and names</h3>\n});

form(0);
}

sub form
{
    my($head) = @_;

    Hebcal::out_html($cfg,
qq{<p class="lead">Generate a list of Yahrzeit dates, Hebrew Birthdays,
or Hebrew Anniversaries for the next 20 years.</p>
<p>For example, you might enter <strong>20 October 1994 (after
sunset)</strong> to calculate <strong>Reb Shlomo Carlebach</b>'s
yahrzeit.</strong>
<p>If you know the Hebrew but not the Gregorian date, use the <a
href="/converter/">Hebrew Date Converter</a> to get the Gregorian date
and then come back to this page.</p>
<form method="post" action="/yahrzeit/">
});

    for (my $i = 1; $i <= $count; $i++) {
	show_row($q,$cfg,$i,\%Hebcal::MoY_long);
    }

    Hebcal::out_html($cfg, qq{<label class="checkbox">},
    $q->checkbox(-name => "hebdate",
		 -checked => "checked",
		 -label => "Include Hebrew dates"),
    "</label>",
    qq{<label class="checkbox">},
    $q->checkbox(-name => "yizkor",
		 -label => "Include Yizkor dates"),
    "</label>",
    "\n<label>Number of years: ",
    $q->textfield(-name => "years",
		  -default => $num_years,
		  -pattern => '\d*',
		  -min => "1",
		  -max => "99",
		  -style => "width:auto",
		  -maxlength => 2,
		  -size => 2),
    "</label>",
    $q->hidden(-name => "ref_url"), "\n",
    $q->hidden(-name => "ref_text"), "\n",
    $q->hidden(-name => ".cgifields",
	       -values => ["hebdate", "yizkor"],
	       -override => 1), "\n",
    qq{<input\ntype="submit" class=\"btn btn-primary\" value="Create Calendar"></form>\n});

    if ($cfg eq "i")
    {
	Hebcal::out_html($cfg, "</body></html>\n");
    }
    elsif ($cfg eq "j")
    {
	# nothing
    }
    else
    {
	Hebcal::out_html($cfg,qq{
<p>Would you like to use this calendar for your website? See
<a href="/home/43/customizing-yahrzeit-birthday-and-anniversary-calendar-for-your-website">developer
instructions</a>.</p>
});

	Hebcal::out_html($cfg, Hebcal::html_footer_bootstrap($q,undef,0));
    }

    exit(0);
}

sub show_row {
    my($q,$cfg,$i,$months) = @_;

    my $style = "border-top:1px solid #dddddd;padding:4px";
    if (($i - 1) % 2 == 0) {
	$style .= ";background-color:#f9f9f9";
    }
    Hebcal::out_html
	($cfg,
	 qq{<div class="form-inline" style="$style">\n},
	 $q->popup_menu(-name => "t$i",
			-class => "input-small",
			-values => ["Yahrzeit","Birthday","Anniversary"]),
	 "\n",
	 $q->textfield(-name => "d$i",
		       -placeholder => "Day",
		       -pattern => '\d*',
		       -min => "1",
		       -max => "31",
		       -style => "width:auto",
		       -maxlength => 2,
		       -size => 2),
	 "\n",
	 $q->popup_menu(-name => "m$i",
			-class => "input-medium",
			-values => [1..12],
			-labels => $months),
	 "\n",
	 $q->textfield(-name => "y$i",
		       -placeholder => "Year",
		       -pattern => '\d*',
		       -style => "width:auto",
		       -maxlength => 4,
		       -size => 4),
	 "\n",
	 $q->textfield(-name => "n$i",
		       -placeholder => "Name (optional)",
		       -class => "input-medium"),
	 qq{\n<label class="checkbox">},
	 $q->checkbox(-name => "s$i",
		      -label => "After sunset"),
	 qq{</label>\n},
	 qq{</div><!-- .form-inline -->\n},
	 );
}

# local variables:
# mode: perl
# end:
