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
use HebcalHtml ();
use Palm::DBA ();
use POSIX ();
use Date::Calc ();

my $this_year = (localtime)[5];
$this_year += 1900;

my $rcsrev = '$Revision$'; #'

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
}

my %yahrzeits = ();
my %ytype = ();
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

	$yahrzeits{$q->param("n$key")} =
	    sprintf("%02d %02d %4d %s",
		    $gm,
		    $gd,
		    $gy,
		    $q->param("n$key"));
	$ytype{$q->param("n$key")} = 
	    ($q->param("t$key") eq "Yahrzeit") ?
		$q->param("t$key") : "Hebrew " . $q->param("t$key");
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
    my @events = my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

    Hebcal::vcalendar_write_contents($q, \@events, undef, undef,
				     "Yahrzeit");
}

sub dba_display
{
    my @events = my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

    Hebcal::export_http_header($q, "application/x-palm-dba");

    my $path_info = $q->path_info();
    $path_info =~ s,^.*/,,;

    Palm::DBA::write_header($path_info);
    Palm::DBA::write_contents(\@events, 0, 0);
}

sub csv_display
{
    my @events = my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

    my $euro = defined $q->param("euro") ? 1 : 0;
    Hebcal::csv_write_contents($q, \@events, $euro);
}

sub my_invoke_hebcal {
    my($this_year,$y,$t) = @_;
    my @events2 = ();

    my $tmpfile = POSIX::tmpnam();
    open(T, ">$tmpfile") || die "$tmpfile: $!\n";
    foreach my $key (keys %{$y})
    {
	print T $y->{$key}, "\n";
    }
    close(T);

    my $cmd = "./hebcal -D -x -Y $tmpfile";

    my %greg2heb = ();

    foreach my $year ($this_year .. ($this_year + $num_years))
    {
	my @events = Hebcal::invoke_hebcal("$cmd $year", "", undef);
	my $numEntries = scalar(@events);
	for (my $i = 0; $i < $numEntries; $i++)
	{
	    my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	    my $year = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	    my $mon = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	    my $mday = $events[$i]->[$Hebcal::EVT_IDX_MDAY];
	
	    if ($subj =~ /^(\d+\w+\s+of\s+.+),\s+\d{4}\s*$/)
	    {
		$greg2heb{sprintf("%04d%02d%02d", $year, $mon, $mday)} = $1;
		next;
	    }

	    if (defined $y->{$subj})
	    {
		my $subj2 = "${subj}'s " . $t->{$subj};
		my $isodate = sprintf("%04d%02d%02d", $year, $mon, $mday);

		$subj2 .= " ($greg2heb{$isodate})"
		    if ($q->param("hebdate") && defined $greg2heb{$isodate});

		push(@events2,
		     [$subj2,
		      $events[$i]->[$Hebcal::EVT_IDX_UNTIMED],
		      $events[$i]->[$Hebcal::EVT_IDX_MIN],
		      $events[$i]->[$Hebcal::EVT_IDX_HOUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		      $events[$i]->[$Hebcal::EVT_IDX_MON],
		      $events[$i]->[$Hebcal::EVT_IDX_YEAR],
		      $events[$i]->[$Hebcal::EVT_IDX_DUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MEMO],
		      $events[$i]->[$Hebcal::EVT_IDX_YOMTOV],
		      ]);
	    }
	    elsif ($subj eq "Pesach VIII" || $subj eq "Shavuot II" ||
		   $subj eq "Yom Kippur" || $subj eq "Shmini Atzeret")
	    {
		next unless defined $q->param("yizkor") &&
		    ($q->param("yizkor") eq "on" ||
		     $q->param("yizkor") eq "1");

		my $subj2 = "Yizkor ($subj)";

		push(@events2,
		     [$subj2,
		      $events[$i]->[$Hebcal::EVT_IDX_UNTIMED],
		      $events[$i]->[$Hebcal::EVT_IDX_MIN],
		      $events[$i]->[$Hebcal::EVT_IDX_HOUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		      $events[$i]->[$Hebcal::EVT_IDX_MON],
		      $events[$i]->[$Hebcal::EVT_IDX_YEAR],
		      $events[$i]->[$Hebcal::EVT_IDX_DUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MEMO],
		      $events[$i]->[$Hebcal::EVT_IDX_YOMTOV],
		      ]);
	    }
	}
    }

    unlink($tmpfile);
    @events2;
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

form(1) unless keys %yahrzeits;

my @events = my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);
my $numEntries = scalar(@events);

if ($numEntries > 0) {
    $q->param("v", "yahrzeit");
    Hebcal::out_html($cfg, HebcalHtml::download_html_modal($q, "yahrzeit", \@events));

    Hebcal::out_html($cfg, qq{<div class="btn-toolbar">\n});
    Hebcal::out_html($cfg, qq{<a class="btn" href="#form"><i class="icon-cog"></i> Enter more dates and names</a>\n});
    Hebcal::out_html($cfg, HebcalHtml::download_html_modal_button());
    Hebcal::out_html($cfg, qq{</div><!-- .btn-toolbar -->\n});

    Hebcal::out_html($cfg,
		      qq{<p>Yahrzeit candles should be lit
the evening before the date specified. This is because the Jewish
day actually begins at sundown on the previous night.</p>\n});
}

for (my $i = 0; $i < $numEntries; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ / of Adar/) {
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

for (my $i = 0; $i < $numEntries; $i++)
{
    my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
    my $year = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
    my $mon = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
    my $mday = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

    if ($year != $events[$i - 1]->[$Hebcal::EVT_IDX_YEAR] &&
	$q->param("yizkor"))
    {
	Hebcal::out_html($cfg, "</table>") unless $i == 0;
	Hebcal::out_html($cfg, qq{<h4>$year</h4>\n<table class="table table-condensed table-striped">});
    }

    my $dow = $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)] . " ";

    Hebcal::out_html
	($cfg,
	 sprintf(qq{<tr><td style="width:130px"><strong>%s%02d-%s-%04d</strong></td><td>%s</td></tr>\n},
		 $dow, $mday, $Hebcal::MoY_short[$mon-1], $year,
		 Hebcal::html_entify($subj)));
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
<p>For example, you might enter <strong>October 20, 1994 (after
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
    $q->hidden(-name => "years", -default => $num_years), "\n",
    $q->hidden(-name => "ref_url"), "\n",
    $q->hidden(-name => "ref_text"), "\n",
#    $q->hidden(-name => "cfg"),
#    $q->hidden(-name => "rand",-value => time(),-override => 1),
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

	Hebcal::out_html($cfg, Hebcal::html_footer_bootstrap($q,$rcsrev,0));
    }

    exit(0);
}

sub show_row {
    my($q,$cfg,$i,$months) = @_;

    Hebcal::out_html
	($cfg,
	 qq{<div class="form-inline">\n},
	 $q->popup_menu(-name => "t$i",
			-class => "input-small",
			-values => ["Yahrzeit","Birthday","Anniversary"]),
	 "\n<label>Month: ",
	 $q->popup_menu(-name => "m$i",
			-class => "input-medium",
			-values => [1..12],
			-labels => $months),
	 "</label>\n<label>Day: ",
	 $q->textfield(-name => "d$i",
		       -style => "width:auto",
		       -maxlength => 2,
		       -size => 2),
	 "</label>\n<label>Year: ",
	 $q->textfield(-name => "y$i",
		       -style => "width:auto",
		       -maxlength => 4,
		       -size => 4),
	 "</label>\n<label>Name: ",
	 $q->textfield(-name => "n$i",
		       -class => "input-medium"),
	 qq{</label>\n<label class="checkbox">},
	 $q->checkbox(-name => "s$i",
		      -label => "After sunset"),
	 qq{</label>\n},
	 qq{</div><!-- .form-inline -->\n},
	 );
}

# local variables:
# mode: perl
# end:
