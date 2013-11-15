#!/usr/bin/perl -w

########################################################################
#
# Generates the Torah Readings for http://www.hebcal.com/sedrot/
#
# Calculates full kriyah according to standard tikkun
#
# Calculates triennial according to
#   A Complete Triennial System for Reading the Torah
#   http://www.jtsa.edu/prebuilt/parashaharchives/triennial.shtml
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
use utf8;
use open ":utf8";
use Hebcal ();
use HebcalGPL ();
use Date::Calc ();
use Getopt::Std ();
use XML::Simple ();
use POSIX qw(strftime);
use Log::Message::Simple qw[:STD :CARP];
use DBI;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-hitf] [-H <year>] [-d d.sqlite3] aliyah.xml festival.xml output-dir
    -h        Display usage information.
    -i        Use Israeli sedra scheme (disables triennial functionality!).
    -t        Dump triennial readings to comma separated values
    -f        Dump full kriyah readings to comma separated values
    -H <year> Start with hebrew year <year> (default this year)
    -d DBFILE Write state to SQLite3 file 
";

my $opt_verbose = 1;
my %opts;
Getopt::Std::getopts('hH:tfd:i', \%opts) || croak "$usage\n";
$opts{'h'} && croak "$usage\n";
(@ARGV == 3) || croak "$usage";

my %hebcal_to_strassfeld = 
    (
     "Pesach III (CH''M)" => "Pesach Chol ha-Moed Day 1",
     "Pesach IV (CH''M)" => "Pesach Chol ha-Moed Day 2",
     "Sukkot III (CH''M)" => "Sukkot Chol ha-Moed Day 1",
     "Sukkot IV (CH''M)" => "Sukkot Chol ha-Moed Day 2",
     "Sukkot V (CH''M)" => "Sukkot Chol ha-Moed Day 3",
     "Sukkot VI (CH''M)" => "Sukkot Chol ha-Moed Day 4",
     "Sukkot VII (Hoshana Raba)" => "Sukkot Chol ha-Moed Day 5 (Hoshana Raba)",
);

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

my $HEBCAL_CMD = "./hebcal";
$HEBCAL_CMD .= " -i" if $opts{"i"};

my $aliyah_in = shift;
my $festival_in = shift;
my $outdir = shift;

if (! -d $outdir) {
    croak "$outdir: $!\n";
}

$| = 1;

## load aliyah.xml data to get parshiot
msg("Loading $aliyah_in...", $opt_verbose);
my $axml = XML::Simple::XMLin($aliyah_in);
msg("Loading $festival_in...", $opt_verbose);
my $fxml = XML::Simple::XMLin($festival_in);

my %triennial_aliyot;
read_aliyot_metadata($axml, \%triennial_aliyot)
    unless $opts{"i"};

my(@all_inorder,@combined,%combined,%parashah2id);
foreach my $h (keys %{$axml->{'parsha'}})
{
    my $num = $axml->{'parsha'}->{$h}->{'num'};
    if ($axml->{'parsha'}->{$h}->{'combined'})
    {
	$combined[$num - 101] = $h;

	my($p1,$p2) = split(/-/, $h);
	$combined{$p1} = $h;
	$combined{$p2} = $h;
    }
    else
    {
	$all_inorder[$num - 1] = $h;
	$parashah2id{$h} = $num;
    }
}

my(%prev,%next,$h2);
foreach my $h (@all_inorder)
{
    $prev{$h} = $h2;
    $h2 = $h;
}

$h2 = undef;
foreach my $h (reverse @all_inorder)
{
    $next{$h} = $h2;
    $h2 = $h;
}

foreach my $parashah (@combined)
{
    my($p1,$p2) = split(/-/, $parashah);
    $next{$parashah} = $next{$p2};
    $prev{$parashah} = $prev{$p1};
}

msg("Finished building internal data structures", $opt_verbose);

## load 4 years of hebcal event data
my($hebrew_year);
if ($opts{'H'}) {
    $hebrew_year = $opts{'H'};
} else {
    my($yy,$mm,$dd) = Date::Calc::Today();
    $hebrew_year = Hebcal::get_default_hebrew_year($yy,$mm,$dd);
}

# year I in triennial cycle was 5756
my $year_num = (($hebrew_year - 5756) % 3) + 1;
msg("Current Hebrew year $hebrew_year is year $year_num.", $opt_verbose);

my @cycle_start_years;
my @triennial_readings;
my @triennial_events;
my @bereshit_indices;
for (my $i = 0; $i < 3; $i++) {
    my $year_offset = ($i - 1) * 3;
    my $cycle_start_year = $hebrew_year - ($year_num - 1) + $year_offset;
    $cycle_start_years[$i] = $cycle_start_year;
    msg("3-cycle started at year $cycle_start_year", $opt_verbose);
    my($bereshit_idx,$pattern,$events) = get_tri_events($cycle_start_year);
    $triennial_events[$i] = $events;
    $bereshit_indices[$i] = $bereshit_idx;
    unless ($opts{"i"}) {
	my $cycle_option = calc_variation_options($axml,$pattern);
	$triennial_readings[$i] = cycle_readings($bereshit_idx,$events,$cycle_option);
    }
}

my %special;
foreach my $yr (($cycle_start_years[0] - 1) .. ($cycle_start_years[2] + 10)) {
    my $cmd = "$HEBCAL_CMD -H $yr";
    my @ev = Hebcal::invoke_hebcal($cmd, "", 0);
    special_readings(\@ev);

    # hack for Pinchas
    $cmd = "$HEBCAL_CMD -s -h -x -H $yr";
    my @ev2 = Hebcal::invoke_hebcal($cmd, "", 0);
    special_pinchas(\@ev2);
}

if ($opts{'t'}) {
    for (my $i = 0; $i < 3; $i++) {
	triennial_csv($axml,
		      $triennial_events[$i],
		      $bereshit_indices[$i],
		      $triennial_readings[$i],
		      $cycle_start_years[$i]);
    }
}

my $DBH;
my $SQL_INSERT_INTO_LEYNING =
  "INSERT INTO leyning (dt, parashah, num, reading) VALUES (?, ?, ?, ?)";
if ($opts{'d'}) {
  my $dbfile = $opts{'d'};
  $DBH = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "",
		     { RaiseError => 1, AutoCommit => 0 })
    or croak $DBI::errstr;
  my @sql = ("DROP TABLE IF EXISTS leyning",
	     "CREATE TABLE leyning (dt TEXT NOT NULL, parashah TEXT NOT NULL, num TEXT NOT NULL, reading TEXT NOT NULL)",
	     "CREATE INDEX leyning_dt ON leyning (dt)",
	     );
  foreach my $sql (@sql) {
    $DBH->do($sql)
      or croak $DBI::errstr;
  }
}

my %parashah_date_sql;
my(%parashah_time);
my($saturday) = get_saturday();
readings_for_current_year($axml);

my %next_reading;
my $NOW = time();
my @parashah_list = (@all_inorder, @combined);
foreach my $h (@parashah_list) {
    foreach my $dt (@{$parashah_date_sql{$h}}) {
	next unless $dt;
	my($year,$month,$day) = split(/-/, $dt);
	my $time = Date::Calc::Date_to_Time($year,$month,$day,12,59,59);
	if ($time >= $NOW) {
	    $next_reading{$h} = $dt;
	    last;
	}
    }
    # see if the combined reading is sooner
    if ($combined{$h}) {
	my $doubled = $combined{$h};
	foreach my $dt (@{$parashah_date_sql{$doubled}}) {
	    next unless $dt;
	    my($year,$month,$day) = split(/-/, $dt);
	    my $time = Date::Calc::Date_to_Time($year,$month,$day,12,59,59);
	    if ($time >= $NOW && $dt lt $next_reading{$h}) {
		$next_reading{$h} = $dt;
		last;
	    }
	}
    }
}

# init global vars needed for html
my %seph2ashk = reverse %Hebcal::ashk2seph;

my $html_footer = Hebcal::html_footer_bootstrap(undef, undef, 0);

foreach my $h (@parashah_list) {
    write_sedra_page($axml,$h,$prev{$h},$next{$h},
		     \@triennial_readings);
}

write_index_page($axml);

if ($opts{'d'}) {
  $DBH->commit;
  $DBH->disconnect;
  $DBH = undef;
}


exit(0);

sub get_tri_events
{
    my($start) = @_;

    my @events;
    foreach my $cycle (0 .. 3)
    {
	my($yr) = $start + $cycle;
	my @ev = Hebcal::invoke_hebcal("$HEBCAL_CMD -s -h -x -H $yr", "", 0);
	push(@events, @ev);
    }

    my $idx;
    for (my $i = 0; $i < @events; $i++)
    {
	if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit')
	{
	    $idx = $i;
	    last;
	}
    }

    croak "can't find Bereshit for Year I" unless defined $idx;

    # determine triennial year patterns
    my %pattern;
    for (my $i = $idx; $i < @events; $i++)
    {
	next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
	my $subj = $1;

	if ($subj =~ /^([^-]+)-(.+)$/ &&
	    defined $combined{$1} && defined $combined{$2})
	{
	    push(@{$pattern{$1}}, 'T');
	    push(@{$pattern{$2}}, 'T');
	}
	else
	{
	    push(@{$pattern{$subj}}, 'S');
	}
    }

    ($idx,\%pattern,\@events);
}

sub cycle_readings
{
    my($bereshit_idx,$events,$option) = @_;

    my %readings;
    my $yr = 1;
    for (my $i = $bereshit_idx; $i < @{$events}; $i++)
    {
	if ($events->[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit' &&
	    $i != $bereshit_idx)
	{
	    $yr++;
	    last if ($yr == 4);
	}

	next unless $events->[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/;
	my $h = $1;

	my($year,$month,$day) = Hebcal::event_ymd($events->[$i]);
	my $stime = sprintf("%02d %s %04d",
			    $day,
			    $Hebcal::MoY_long{$month},
			    $year);

	if (defined $combined{$h})
	{
	    my $variation = $option->{$h} . "." . $yr;
	    my $a = $triennial_aliyot{$h}->{$variation};
	    croak unless defined $a;
	    $readings{$h}->[$yr] = [$a, $stime, $h];
	}
	elsif (defined $triennial_aliyot{$h}->{$yr})
	{
	    my $a = $triennial_aliyot{$h}->{$yr};
	    croak unless defined $a;

	    $readings{$h}->[$yr] = [$a, $stime, $h];

	    if ($h =~ /^([^-]+)-(.+)$/ &&
		defined $combined{$1} && defined $combined{$2})
	    {
		$readings{$1}->[$yr] = [$a, $stime, $h];
		$readings{$2}->[$yr] = [$a, $stime, $h];
	    }
	}
	elsif (defined $triennial_aliyot{$h}->{"Y.$yr"})
	{
	    my $a = $triennial_aliyot{$h}->{"Y.$yr"};
	    croak unless defined $a;

	    $readings{$h}->[$yr] = [$a, $stime, $h];

	    if ($h =~ /^([^-]+)-(.+)$/ &&
		defined $combined{$1} && defined $combined{$2})
	    {
		$readings{$1}->[$yr] = [$a, $stime, $h];
		$readings{$2}->[$yr] = [$a, $stime, $h];
	    }
	}
	else
	{
	    croak "can't find aliyot for $h, year $yr";
	}
    }

    \%readings;
}

sub write_index_page
{
    my($parshiot) = @_;

    my $fn = "$outdir/index.php";
    msg("write_index_page: $fn", $opt_verbose);
    open(OUT1, ">$fn.$$") || croak "$fn.$$: $!\n";


    my $xtra_head = <<EOHTML;
<link rel="alternate" type="application/rss+xml" title="RSS" href="index.xml">
EOHTML
;
    print OUT1 Hebcal::html_header_bootstrap("Torah Readings",
				   "/sedrot/",
				   "single single-post",
				   $xtra_head);
    print OUT1 <<EOHTML;
<div class="page-header">
<h1>Torah Readings</h1>
</div>

<p class="lead">Weekly Torah readings (Parashat ha-Shavua) including
verses for each aliyah and accompanying Haftarah. Includes
both traditional (full kriyah) and triennial reading schemes.</p>
EOHTML
    ;

print OUT1 q'<?php
require("../pear/Hebcal/common.inc");
list($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$gm = $mon + 1;
$gd = $mday;
$gy = $year + 1900;
$century = substr($gy, 0, 2);
$fn = $_SERVER["DOCUMENT_ROOT"] . "/converter/sedra/$century/$gy.inc";
@include($fn);
list($saturday_gy,$saturday_gm,$saturday_gd) = get_saturday($gy, $gm, $gd);
$saturday_iso = sprintf("%04d%02d%02d", $saturday_gy, $saturday_gm, $saturday_gd);
if (isset($sedra) && isset($sedra[$saturday_iso])) {
    if (is_array($sedra[$saturday_iso])) {
	$sat_events = $sedra[$saturday_iso];
    } else {
	$sat_events = array($sedra[$saturday_iso]);
    }
    foreach ($sat_events as $h) {
	if (strncmp($h, "Parashat ", 9) == 0) {
	    $anchor = hebcal_make_anchor($h);
	    $sat_timestamp = mktime(12, 34, 56, $saturday_gm, $saturday_gd, $saturday_gy);
	    echo "<p class=\"lead\">This week&apos;s Torah Portion is <a href=\"", $anchor, "\">", $h, "</a> (read in the Diaspora on ", date("j F Y", $sat_timestamp), ").</p>\n";
	    break;
	}
    }
}
?>
';


    print OUT1 <<EOHTML;
<div class="btn-toolbar">
<a class="btn" title="Download aliyah-by-aliyah breakdown"
href="#download"><i
class="icon-download-alt"></i> Leyning spreadsheet</a>
<a class="btn" href="index.xml"><img src="/i/feed-icon-14x14.png"
style="border:none" alt="View the raw XML source" width="14"
height="14"> Parashat ha-Shavua RSS feed</a>
</div><!-- .btn-toolbar -->

<div class="row-fluid">
<div class="span4">
<h3 id="Genesis">Genesis</h3>
<ol class="unstyled">
EOHTML
    ;

    my $book_count = 1;
    my $prev_book = "Genesis";
    foreach my $h (@all_inorder) {
	my($book) = $parshiot->{'parsha'}->{$h}->{'verse'};
	$book =~ s/\s+.+$//;

	if ($prev_book ne $book) {
	    print OUT1 "</ol>\n</div><!-- .span4 -->\n";
	    if ($book_count++ % 3 == 0) {
		print OUT1 qq{</div><!-- .row-fluid -->\n<div class="row-fluid">\n};
	    }
	    print OUT1 qq{<div class="span4">\n<h3 id="$book">$book</h3>\n<ol class="unstyled">\n};
	}
	$prev_book = $book;

	my $anchor = lc($h);
	$anchor =~ s/[^\w]//g;
	print OUT1 qq{<li><a href="$anchor">Parashat $h</a>\n};
    }

    print OUT1 <<EOHTML;
</ol>
</div><!-- .span4 -->
<div class="span4">
<h3 id="DoubledParshiyot">Doubled Parshiyot</h3>
<ol class="unstyled">
EOHTML
;

    foreach my $h (@combined) {
	my $anchor = lc($h);
	$anchor =~ s/[^\w]//g;
	print OUT1 qq{<li><a href="$anchor">Parashat $h</a>\n};
    }

    print OUT1 <<EOHTML;
</ol>
</div><!-- .span4 -->
</div><!-- .row-fluid -->
<div class="row-fluid">
<div class="span12">
<h3>Parashat ha-Shavua by Hebrew year</h3>
<div class="pagination">
<ul>
<li class="disabled"><a href="#">Diaspora</a></li>
EOHTML
;
    my $extra_years = 8;
    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
	my $nofollow = $i > 3 ? qq{ rel="nofollow"} : "";
	print OUT1 qq{<li><a$nofollow href="/hebcal/?year=$yr&amp;v=1&amp;month=x&amp;yt=H&amp;s=on&amp;i=off&amp;set=off">$yr</a></li>\n};
    }

    print OUT1 <<EOHTML;
</ul>
</div><!-- .pagination -->
<div class="pagination">
<ul>
<li class="disabled"><a href="#">Israel</a></li>
EOHTML
;

    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
	my $nofollow = $i > 3 ? qq{ rel="nofollow"} : "";
	print OUT1 qq{<li><a$nofollow href="/hebcal/?year=$yr&amp;v=1&amp;month=x&amp;yt=H&amp;s=on&amp;i=on&amp;set=off">$yr</a></li>\n};
    }

    print OUT1 <<EOHTML;
</ul>
</div><!-- .pagination -->
</div><!-- .span12 -->
</div><!-- .row-fluid -->
EOHTML
;

    my $full_kriyah_download_html = "";
    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
	my $basename = "fullkriyah-$yr.csv";
	$full_kriyah_download_html .= qq{<a class="btn download" id="leyning-fullkriyah-$yr" href="$basename"
title="Download $basename"><i class="icon-download-alt"></i> $yr</a>
};
    }

    my $triennial_download_html = "";
    for (my $i = 0; $i < 3; $i++) {
	my $start_year = $cycle_start_years[$i];
	my $triennial_range = triennial_csv_range($start_year);
	my $triennial_basename = triennial_csv_basename($start_year);
	$triennial_download_html .= qq{
<a class="btn download" id="leyning-triennial-$start_year" href="$triennial_basename"
title="Download $triennial_basename"><i class="icon-download-alt"></i> $triennial_range</a>
};
    }

    print OUT1 <<EOHTML;
<div class="row-fluid">
<div class="span12">
<h3 id="download">Download aliyah-by-aliyah breakdown of Torah readings</h3>
<p class="lead">Leyning coordinators can download these Comma Separated
Value (CSV) files and import into Microsoft Excel or some other
spreadsheet program.</p>
<p>Note that they follow the Diaspora <a
href="/home/51/what-is-the-differerence-between-the-diaspora-and-israeli-sedra-schemes">sedra
scheme</a>.</p>
<h4>Full Kriyah</h4>
<div class="btn-toolbar">
$full_kriyah_download_html
</div><!-- .btn-toolbar -->
<h4>Triennial</h4>
<div class="btn-toolbar">
$triennial_download_html
</div><!-- .btn-toolbar -->
<h4>Leyning spreadsheet file format</h4>
<p>The format of the CSV files looks something like this:</p>
<table class="table table-striped table-condensed">
<tbody>
<tr><th>Date</th><th>Parashah</th><th>Aliyah</th><th>Reading</th><th>Verses</th></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>1</td><td>Genesis 1:1 &#8211; 2:3</td><td>34</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>2</td><td>Genesis 2:4 &#8211; 2:19</td><td>16</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>3</td><td>Genesis 2:20 &#8211; 3:21</td><td>27</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>4</td><td>Genesis 3:22 &#8211; 4:18</td><td>21</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>5</td><td>Genesis 4:19 &#8211; 4:22</td><td>4</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>6</td><td>Genesis 4:23 &#8211; 5:24</td><td>28</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>7</td><td>Genesis 5:25 &#8211; 6:8</td><td>16</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>maf</td><td>Genesis 6:5 &#8211; 6:8</td><td>4</td></tr>
<tr><td>25-Oct-2003</td><td>Bereshit</td><td>Haftara</td><td>Isaiah 42:5 &#8211; 43:11</td><td></td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>1</td><td>Genesis 6:9 &#8211; 6:22</td><td>14</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>2</td><td>Genesis 7:1 &#8211; 7:16</td><td>16</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>3</td><td>Genesis 7:17 &#8211; 8:14</td><td>22</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>4</td><td>Genesis 8:15 &#8211; 9:7</td><td>15</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>5</td><td>Genesis 9:8 &#8211; 9:17</td><td>10</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>6</td><td>Genesis 9:18 &#8211; 10:32</td><td>44</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>7</td><td>Genesis 11:1 &#8211; 11:32</td><td>32</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>maf</td><td>Genesis 11:29 &#8211; 11:32</td><td>4</td></tr>
<tr><td>1-Nov-2003</td><td>Noach</td><td>Haftara</td><td>Isaiah 54:1 &#8211; 55:5</td><td></td></tr>
</tbody>
</table>
</div><!-- .span12 -->
</div><!-- .row-fluid -->
EOHTML
;

    print OUT1 $html_footer;

    close(OUT1);
    rename("$fn.$$", $fn) || croak "$fn: $!\n";

    1;
}

sub date_sql_to_dd_MMM_yyyy {
    my($date_sql) = @_;
    my($year,$month,$day) = split(/-/, $date_sql);
    $day =~ s/^0//;
    $month =~ s/^0//;
    sprintf "%02d %s %04d", $day, $Hebcal::MoY_long{$month}, $year;
}

sub calc_variation_options
{
    my($parshiot,$patterns) = @_;

    my $option = {};
    foreach my $parashah (@combined)
    {
	my($p1,$p2) = split(/-/, $parashah);
	my $pat = '';
	foreach my $yr (0 .. 2) {
	    $pat .= $patterns->{$p1}->[$yr];
	}

	if ($pat eq 'TTT')
	{
	    $option->{$parashah} = 'all-together';
	}
	else
	{
	    my $vars =
		$parshiot->{'parsha'}->{$parashah}->{'variations'}->{'cycle'};
	    foreach my $cycle (@{$vars}) {
		if ($cycle->{'pattern'} eq $pat) {
		    $option->{$parashah} = $cycle->{'option'};
		    $option->{$p1} = $cycle->{'option'};
		    $option->{$p2} = $cycle->{'option'};
		    last;
		}
	    }

	    croak "can't find option for $parashah (pat == $pat)"
		unless defined $option->{$parashah};
	}

	msg("  $parashah: $pat ($option->{$parashah})", $opt_verbose);
    }

    $option;
}

sub read_aliyot_metadata
{
    my($parshiot,$aliyot) = @_;

    # build a lookup table so we don't have to follow num/variation/sameas
    foreach my $parashah (keys %{$parshiot->{'parsha'}}) {
	my $val = $parshiot->{'parsha'}->{$parashah};
	my $yrs = $val->{'triennial'}->{'year'};
	
	foreach my $y (@{$yrs}) {
	    if (defined $y->{'num'}) {
		$aliyot->{$parashah}->{$y->{'num'}} = $y->{'aliyah'};
	    } elsif (defined $y->{'variation'}) {
		if (! defined $y->{'sameas'}) {
		    $aliyot->{$parashah}->{$y->{'variation'}} = $y->{'aliyah'};
		}
	    } else {
		croak "strange data for Parashat $parashah";
	    }
	}

	# second pass for sameas
	foreach my $y (@{$yrs}) {
	    if (defined $y->{'variation'} && defined $y->{'sameas'}) {
		my $sameas = $y->{'sameas'};
		croak "Bad sameas=$sameas for Parashat $parashah"
		    unless defined $aliyot->{$parashah}->{$sameas};
		$aliyot->{$parashah}->{$y->{'variation'}} =
		    $aliyot->{$parashah}->{$sameas};
	    }
	}
    }

    1;
}

sub write_sedra_sidebar {
    my($parshiot,$current) = @_;

    print OUT2 <<EOHTML;
<div class="span2 hidden-phone">
<div class="sidebar-nav">
<ul class="nav nav-list">
EOHTML
;
    my $prev_book = "";
    foreach my $h (@all_inorder) {
	my $book = $parshiot->{'parsha'}->{$h}->{'verse'};
	$book =~ s/\s+.+$//;

	print OUT2 qq{<li class="nav-header">$book</li>\n} if $prev_book ne $book;
	$prev_book = $book;

	if ($h eq $current) {
	    print OUT2 qq{<li class="active">};
	} else {
	    print OUT2 qq{<li>};
	}

	my $anchor = lc($h);
	$anchor =~ s/[^\w]//g;
	print OUT2 qq{<a href="$anchor">$h</a></li>\n};
    }

    print OUT2 qq{<li class="nav-header">Doubled Parshiyot</li>\n};
    foreach my $h (@combined) {
	if ($h eq $current) {
	    print OUT2 qq{<li class="active">};
	} else {
	    print OUT2 qq{<li>};
	}

	my $anchor = lc($h);
	$anchor =~ s/[^\w]//g;
	print OUT2 qq{<a href="$anchor">$h</a></li>\n};
    }

    print OUT2 <<EOHTML;
</ul>
</div>
</div><!-- .span2 -->
EOHTML
;
}

sub write_sedra_page
{
    my($parshiot,$h,$prev,$next,$triennial_readings) = @_;

    my($hebrew,$torah,$haftarah,$haftarah_seph,
       $torah_href,$haftarah_href,
       $drash_ou,$drash_torg) = get_parashah_info($parshiot,$h);

    if ($hebrew) {
	$hebrew = Hebcal::hebrew_strip_nikkud($hebrew);
    }

    my $seph = '';
    my $ashk = '';

    if (defined($haftarah_seph) && ($haftarah_seph ne $haftarah))
    {
	$seph = "\n<br>Haftarah for Sephardim: $haftarah_seph";
	$ashk = " for Ashkenazim";
    }

    my $anchor = lc($h);
    $anchor =~ s/[^\w]//g;
    my $fn = "$outdir/$anchor";
    msg("write_sedra_page: $fn", $opt_verbose);
    open(OUT2, ">$fn.$$") || croak "$fn.$$: $!\n";

    my $keyword = $h;
    $keyword .= ",$seph2ashk{$h}" if defined $seph2ashk{$h};

    my $description = "Parashat $h ($torah). ";
    my $default_intro_summary = qq{<p class="lead">};
    my $intro_summary = $default_intro_summary;
    if ($next_reading{$h}) {
	my $dt = date_sql_to_dd_MMM_yyyy($next_reading{$h});
	$intro_summary .= "Next read in the Diaspora on $dt.";
	$description .= "Read on $dt in the Diaspora.";
    } else {
	$description .= "List of dates when read in the Diaspora.";
    }

    if (defined $parashah2id{$h}) {
	$intro_summary .= "\nParashat $h is the " . ordinate($parashah2id{$h})
	    . " weekly Torah portion in the annual Jewish cycle of Torah reading."
    }

    if ($intro_summary eq $default_intro_summary) {
	$intro_summary = "";
    } else {
	$intro_summary .= "</p>";
    }

    $description .= " Torah reading, Haftarah, links to audio and commentary.";

    print OUT2 Hebcal::html_header_bootstrap(
	"$h - Torah Portion - $hebrew", "/sedrot/$anchor", "ignored",
	qq{<meta name="description" content="$description">\n}, 0, 1);

    my $amazon_link2 =
	"http://www.amazon.com/o/ASIN/0899060145/hebcal-20";

    write_sedra_sidebar($parshiot,$h);

    print OUT2 <<EOHTML;
<div class="span10">
<div class="page-header">
<h1 class="entry-title">Parashat $h / <span lang="he" dir="rtl">$hebrew</span></h1>
</div>
$intro_summary
<h3 id="torah">Torah Portion: <a class="outbound"
href="$torah_href"
title="Translation from JPS Tanakh">$torah</a></h3>
<div class="row-fluid">
<div class="span3">
<h4>Full Kriyah</h4>
<ol class="unstyled">
EOHTML
;

    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$aliyot})
    {
	print OUT2 "<li>", format_aliyah($aliyah,$h,$torah);
    }

    print OUT2 "</ol>\n</div><!-- .span3 fk -->\n";

    write_sedra_tri_cells($h,$torah,$triennial_readings->[1]);

    print OUT2 qq{</div><!-- .row-fluid -->\n};

    if (defined $parashah_date_sql{$h}) {
	my %sp_dates;
	foreach my $dt (@{$parashah_date_sql{$h}}) {
	    if (defined $dt && (defined $special{$dt}->{"M"} || defined $special{$dt}->{"8"})) {
		my $reason = $special{$dt}->{"reason"};
		push(@{$sp_dates{$reason}}, $dt);
	    }
	}

	if (keys %sp_dates) {
	    print OUT2 qq{<h4>Special Maftir</h4>\n};
	    foreach my $reason (sort keys %sp_dates) {
		my $info = "";
		my $count = 0;
		foreach my $aliyah ("8", "M") {
		  my $aa = $special{$sp_dates{$reason}->[0]}->{$aliyah};
		  if ($aa) {
		    my $aa_parashah = $all_inorder[$aa->{'parsha'} - 1];
		    $info .= "<br>\n" if $count++;
		    $info .= format_aliyah($aa, $aa_parashah, undef, 1);
		  }
		}
#		print OUT2 "<br>\n" if $count++;
		print OUT2 <<EOHTML;
On <b>$reason</b><br>
$info<ul class="gtl">
EOHTML
;
		foreach my $dt (@{$sp_dates{$reason}}) {
		    my($year,$month,$day) = split(/-/, $dt);
		    print OUT2 "<li>", format_html_date($year,$month,$day), "\n";
		}

		print OUT2 "</ul>\n";
	    }
	}
    }

    print OUT2 <<EOHTML;
<h3 id="haftarah">Haftarah$ashk: <a class="outbound"
href="$haftarah_href"
title="Translation from JPS Tanakh">$haftarah</a>$seph</h3>
EOHTML
;

    if (defined $parashah_date_sql{$h}) {
	my $did_special;
	foreach my $dt (@{$parashah_date_sql{$h}}) {
	    if (defined $dt && defined $special{$dt}->{"H"}) {
		if (!$did_special) {
		    print OUT2 <<EOHTML;
When Parashat $h coincides with a special Shabbat, we read a
different Haftarah:
<ul class="gtl">
EOHTML
;
		    $did_special = 1;
		}
		my $sp_verse = $special{$dt}->{"H"};
		my $sp_festival = $special{$dt}->{"reason"};
		$sp_festival =~ s/ - Day \d//; # Chanukah
		my $sp_href = $fxml->{'festival'}->{$sp_festival}->{'kriyah'}->{'haft'}->{'href'};
		if ($h eq "Pinchas" && ! defined $sp_href) {
		  $sp_href = "http://www.jtsa.edu/PreBuilt/ParashahArchives/jpstext/mattot_haft.shtml";
		}
		my($year,$month,$day) = split(/-/, $dt);
		my $stime2 = format_html_date($year,$month,$day);
		print OUT2 <<EOHTML;
<li>$stime2 -
<b>$sp_festival</b> / <a class="outbound"
title="Special Haftara for $sp_festival"
href="$sp_href">$sp_verse</a>
EOHTML
;
	    }
	}
	if ($did_special) {
	    print OUT2 "</ul>\n";
	}
    }

    my $has_drash = $drash_ou || $drash_torg;
    if ($has_drash) {
	print OUT2 qq{<h3 id="drash">Commentary</h3>\n<ul class="gtl">\n};
    }

    if ($drash_ou) {
	print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from Orthodox Union"\nhref="$drash_ou">OU Torah</a>\n};
    }

    if ($drash_torg) {
	print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from Project Genesis"\nhref="$drash_torg">Torah.org</a>\n};
    }

    if ($has_drash) {
	print OUT2 qq{</ul>\n};
    }

    if (defined $parashah_date_sql{$h}) {
	print OUT2 <<EOHTML;
<h3 id="dates">List of Dates</h3>
Parashat $h is read in the Diaspora on:
<ul class="unstyled">
EOHTML
	;
	my @dates;
	my %doubled;
	foreach my $dt (@{$parashah_date_sql{$h}}) {
	    next unless $dt;
	    push(@dates, $dt);
	}
	if ($combined{$h}) {
	    my $doubled = $combined{$h};
	    foreach my $dt (@{$parashah_date_sql{$doubled}}) {
		next unless $dt;
		push(@dates, $dt);
		$doubled{$dt} = 1;
	    }
	}
	foreach my $dt (sort @dates) {
	    my($year,$month,$day) = split(/-/, $dt);
	    print OUT2 "<li>", format_html_date($year,$month,$day), "\n";
	    if ($doubled{$dt}) {
		print OUT2 " - <small>Parashat ", $combined{$h}, "</small>\n";
	    }
	}
	print OUT2 "</ul>\n";
    }

    # if this is a combined parashah or one half of one that's sometimes combined
    if ($combined{$h} || index($h, "-") != -1) {
	print OUT2 qq{<h3>Triennial readings for previous and future cycles</h3>\n};
	print OUT2 qq{<div class="row-fluid">\n};
	write_sedra_tri_cells($h,$torah,$triennial_readings->[0]);
	print OUT2 qq{</div><!-- .row-fluid -->\n};
	print OUT2 qq{<div class="row-fluid">\n};
	write_sedra_tri_cells($h,$torah,$triennial_readings->[2]);
	print OUT2 qq{</div><!-- .row-fluid -->\n};
    }
    
    print OUT2 <<EOHTML;
<h3 id="ref">References</h3>
<dl>
<dt><em><a class="amzn" id="chumash-2"
href="$amazon_link2">The
Chumash: The Stone Edition (Artscroll Series)</a></em>
<dd>Nosson Scherman, Mesorah Publications, 1993
<dt><em><a class="outbound"
href="http://www.jtsa.edu/prebuilt/parashaharchives/triennial.shtml">A
Complete Triennial System for Reading the Torah</a></em>
<dd>Committee on Jewish Law and Standards of the Rabbinical Assembly
<dt><em><a class="outbound"
href="http://www.mechon-mamre.org/p/pt/pt0.htm">Hebrew - English Bible</a></em>
<dd>Mechon Mamre
</dl>
EOHTML
;

    print OUT2 <<EOHTML;
</div><!-- .span10 -->
EOHTML
;
    print OUT2 $html_footer;

    close(OUT2);
    rename("$fn.$$", $fn) || croak "$fn: $!\n";
}

sub write_sedra_tri_cells {
    my($h,$torah,$triennial_readings) = @_;

    my $triennial = $triennial_readings->{$h};
    my @tri_date;
    if ($h eq 'Vezot Haberakhah') {
	$tri_date[1] = $tri_date[2] = $tri_date[3] =
	    "To be read on Simchat Torah.<br>\nSee holiday readings.";
    } else {
	foreach my $yr (1 .. 3) {
	    $tri_date[$yr] = (defined $triennial->[$yr]) ? $triennial->[$yr]->[1] : "";
	}
    }
    foreach my $yr (1 .. 3) {
	print OUT2 <<EOHTML;
<div class="span3">
<h4>Triennial Year $yr</h4>
<div class="muted">$tri_date[$yr]</div>
EOHTML
;
	print_tri_cell($triennial_readings,$h,$yr,$torah);
	print OUT2 qq{</div><!-- .span3 tri$yr -->\n};
    }
    1;
}

sub format_html_date {
  my($gy,$gm,$gd) = @_;
  $gm =~ s/^0//;
  $gd =~ s/^0//;
  my $nofollow = $gy > $this_year + 2 ? qq{ rel="nofollow"} : "";
  sprintf "<a title=\"%s %d holiday calendar\"%s href=\"/hebcal/?v=1&amp;year=%d&amp;month=%d" .
    "&amp;s=on&amp;nx=on&amp;mf=on&amp;ss=on&amp;nh=on&amp;D=on&amp;vis=on&amp;set=off#hebcal-results\">%02d %s %d</a>",
    $Hebcal::MoY_long{$gm}, $gy,
    $nofollow,
    $gy, $gm,
    $gd, $Hebcal::MoY_long{$gm}, $gy;
}

sub print_tri_cell
{
    my($triennial_readings,$h,$yr,$torah) = @_;

    my $triennial = $triennial_readings->{$h};
    if ($h eq 'Vezot Haberakhah')
    {
	print OUT2 "&nbsp;\n";
	return;
    }
    elsif (! defined $triennial->[$yr])
    {
	my($p1,$p2) = split(/-/, $h);

	print OUT2 "<p>Read separately. See:</p>\n<ul>\n";

	my($anchor) = lc($p1);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor\">$p1</a>\n";
	print OUT2 qq{- <span class="muted">},
	    $triennial_readings->{$p1}->[$yr]->[1], qq{</span>\n};

	$anchor = lc($p2);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor\">$p2</a>\n";
	print OUT2 qq{- <span class="muted">},
	    $triennial_readings->{$p2}->[$yr]->[1], qq{</span>\n};
	print OUT2 "</ul>\n";
	return;
    }
    elsif ($triennial->[$yr]->[2] ne $h)
    {
	my($h_combined) = $triennial->[$yr]->[2];
	my($p1,$p2) = split(/-/, $h_combined);

	my($other) = ($p1 eq $h) ? $p2 : $p1;

	print OUT2 "<p>Read together with<br>Parashat $other.<br>\n";

	my($anchor) = lc($h_combined);
	$anchor =~ s/[^\w]//g;
	print OUT2 "See <a href=\"$anchor\">$h_combined</a></p>\n";
	return;
    }

    croak "no aliyot array for $h (year $yr)"
	unless defined $triennial->[$yr]->[0];

    print OUT2 qq{<ul class="unstyled">\n};
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$triennial->[$yr]->[0]})
    {
	print OUT2 "<li>", format_aliyah($aliyah,$h,$torah);
    }
    print OUT2 "</ul>\n";
}

sub format_aliyah
{
    my($aliyah,$h,$torah,$show_book) = @_;

    my($c1,$v1) = ($aliyah->{'begin'} =~ /^(\d+):(\d+)$/);
    my($c2,$v2) = ($aliyah->{'end'}   =~ /^(\d+):(\d+)$/);
    my($info);
    if ($c1 == $c2) {
	$info = "$c1:$v1-$v2";
    } else {
	$info = "$c1:$v1-$c2:$v2";
    }

    $torah ||= $aliyah->{"book"}; # special maftirs
    $torah =~ s/\s+.+$//;

    if ($show_book) {
	$info = "$torah $info";
    }

    if (defined $parashah2id{$h}) {
#	my $url = Hebcal::get_mechon_mamre_url($torah, $c1, $v1);
#	my $title = "Hebrew-English bible text";
	my $url = Hebcal::get_bible_ort_org_url($torah, $c1, $v1, $parashah2id{$h});
	$url =~ s/&/&amp;/g;
	my $title = "Hebrew-English bible text from ORT";
	$info = qq{<a class="outbound" title="$title"\nhref="$url">$info</a>};
    }

    my $label = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    $info = "$label: $info\n";

    if ($aliyah->{'numverses'}) {
	$info .= qq{<small class="muted">(} . $aliyah->{'numverses'} .
	    "&nbsp;p'sukim)</small>\n";
    }

    $info;
}

sub get_parashah_info
{
    my($parshiot,$h) = @_;

    my $parashat = "\x{05E4}\x{05E8}\x{05E9}\x{05EA}";  # Unicode for "parashat"

    my($hebrew);
    my($torah,$haftarah,$haftarah_seph);
    my($torah_href,$haftarah_href);
    my $drash_ou;
    my $drash_torg;
    if ($h =~ /^([^-]+)-(.+)$/ &&
	defined $combined{$1} && defined $combined{$2})
    {
	my($p1,$p2) = ($1,$2);

	# HEBREW PUNCTUATION MAQAF (U+05BE)
	$hebrew = sprintf("%s %s%s%s",
			  $parashat,
			  $parshiot->{'parsha'}->{$p1}->{'hebrew'},
			  "\x{05BE}", 
			  $parshiot->{'parsha'}->{$p2}->{'hebrew'});

	my $torah_end = $parshiot->{'parsha'}->{$p2}->{'verse'};
	$torah_end =~ s/^.+\s+(\d+:\d+)\s*$/$1/;

	$torah = $parshiot->{'parsha'}->{$p1}->{'verse'};
	$torah =~ s/\s+\d+:\d+\s*$/ $torah_end/;

	# on doubled parshiot, read only the second Haftarah
	# except for Nitzavim-Vayelech
	my $ph = ($p1 eq 'Nitzavim') ? $p1 : $p2;
	$haftarah = $parshiot->{'parsha'}->{$ph}->{'haftara'};
	$haftarah_seph = $parshiot->{'parsha'}->{$ph}->{'sephardic'};

	my $links = $parshiot->{'parsha'}->{$ph}->{'links'}->{'link'};
	foreach my $l (@{$links})
	{
	    if ($l->{'rel'} eq 'torah')
	    {
		$torah_href = $l->{'href'};
	    }
	}

	$haftarah_href = $torah_href;
	$haftarah_href =~ s/.shtml$/_haft.shtml/;

	# for now, link torah reading to first part
	$links = $parshiot->{'parsha'}->{$p1}->{'links'}->{'link'};
	foreach my $l (@{$links})
	{
	    if ($l->{'rel'} eq 'torah')
	    {
		$torah_href = $l->{'href'};
	    }
	}

	# grab drash for the combined reading
	$links = $parshiot->{'parsha'}->{$h}->{'links'}->{'link'};
	$links = [ $links ] unless ref($links) eq "ARRAY";
	foreach my $l (@{$links})
	{
	    if ($l->{'rel'} eq 'drash:ou.org') {
		my $cid = $l->{'cid'};
		$drash_ou = "http://www.ou.org/index.php/torah/browse_parsha/C$cid/";
	    } elsif ($l->{'rel'} eq 'drash:torah.org') {
		$drash_torg = $l->{'href'};
	    }
	}

    }
    else
    {
	$hebrew = sprintf("%s %s",
			  $parashat,
			  $parshiot->{'parsha'}->{$h}->{'hebrew'});
	$torah = $parshiot->{'parsha'}->{$h}->{'verse'};
	$haftarah = $parshiot->{'parsha'}->{$h}->{'haftara'};
	$haftarah_seph = $parshiot->{'parsha'}->{$h}->{'sephardic'};

	my $links = $parshiot->{'parsha'}->{$h}->{'links'}->{'link'};
	foreach my $l (@{$links})
	{
	    if ($l->{'rel'} eq 'drash:ou.org') {
		my $cid = $l->{'cid'};
		$drash_ou = "http://www.ou.org/index.php/torah/browse_parsha/C$cid/";
	    } elsif ($l->{'rel'} eq 'drash:torah.org') {
		$drash_torg = $l->{'href'};
	    } elsif ($l->{'rel'} eq 'torah') {
		$torah_href = $l->{'href'};
	    }
	}

	$haftarah_href = $torah_href;
	$haftarah_href =~ s/.shtml$/_haft.shtml/;
    }

    ($hebrew,$torah,$haftarah,$haftarah_seph,
     $torah_href,$haftarah_href,$drash_ou,$drash_torg);
}

sub get_special_aliyah
{
    my($h,$aliyah_num) = @_;

    if (defined $fxml->{'festival'}->{$h}) {
	if (defined $fxml->{'festival'}->{$h}->{'kriyah'}->{'aliyah'}) {
	    my $a = $fxml->{'festival'}->{$h}->{'kriyah'}->{'aliyah'};
	    if (ref($a) eq 'HASH') {
		if ($a->{'num'} eq $aliyah_num) {
		    return $a;
		}
	    } else {
		foreach my $aliyah (@{$a}) {
		    if ($aliyah->{'num'} eq $aliyah_num) {
			return $aliyah;
		    }
		}
	    }
	}
    }

    return undef;
}

sub special_pinchas {
    my($events) = @_;
    foreach my $evt (@{$events}) {
	next unless "Parashat Pinchas" eq $evt->[$Hebcal::EVT_IDX_SUBJ];
	my($year,$month,$day) = Hebcal::event_ymd($evt);
	my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
	# check to see if it's after the 17th of Tammuz
	if ($hebdate->{"mm"} > 4
	    || ($hebdate->{"mm"} == 4 && $hebdate->{"dd"} > 17)) {
	    my $dt = Hebcal::date_format_sql($year, $month, $day);
	    $special{$dt}->{"H"} = "Jeremiah 1:1 - 2:3";
	    $special{$dt}->{"reason"} = "Pinchas occurring after 17 Tammuz";
	}
    }
}

sub special_readings
{
    my($events) = @_;

    for (my $i = 0; $i < @{$events}; $i++) {
	my($year,$month,$day) = Hebcal::event_ymd($events->[$i]);
	my $dt = Hebcal::date_format_sql($year, $month, $day);
	next if defined $special{$dt};
	
	my $dow = Date::Calc::Day_of_Week($year, $month, $day);

	my $h = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $chanukah_day = 0;
	# hack! for Shabbat Rosh Chodesh
	if ($dow == 6 && $h =~ /^Rosh Chodesh/
	    && $events->[$i+1]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Chanukah: (\d) Candles/
	    && $1 > 1
	    && defined $events->[$i+1]
	    && Hebcal::event_dates_equal($events->[$i], $events->[$i+1])) {
	    $h = "Shabbat Rosh Chodesh Chanukah"; # don't set $chanukah_day = 6
	} elsif ($dow == 6 && $h =~ /^Rosh Chodesh/
	    && $events->[$i+1]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Shabbat HaChodesh/
	    && defined $events->[$i+1]
	    && Hebcal::event_dates_equal($events->[$i], $events->[$i+1])) {
	    $h = "Shabbat HaChodesh (on Rosh Chodesh)";
	} elsif ($dow == 6 && $h =~ /^Rosh Chodesh/) {
	    $h = 'Shabbat Rosh Chodesh';
	} elsif ($dow == 7 && $h =~ /^Rosh Chodesh/) {
	    # even worse hack!
	    $h = 'Shabbat Machar Chodesh';
	    my($year0,$month0,$day0) =
		Date::Calc::Add_Delta_Days($year, $month, $day, -1);
	    $dt = Hebcal::date_format_sql($year0, $month0, $day0);
	    next if defined $special{$dt};
	} elsif ($dow != 6) {
	    next;
	}

	# since dow == 6, this is only for Shabbat
	if ($h eq "Chanukah: 8th Day") {
	    $chanukah_day = 8;
	    $h = "Shabbat Chanukah II";
	} elsif ($h =~ /^Chanukah: (\d)/ && $1 > 1) {
	    $chanukah_day = $1 - 1;
	    $h = "Shabbat Chanukah";
	}

	if (defined $fxml->{'festival'}->{$h}) {
	    my $haft =
		$fxml->{'festival'}->{$h}->{'kriyah'}->{'haft'}->{'reading'};
	    if (defined $haft) {
		$special{$dt}->{"H"} = $haft;
		$special{$dt}->{"reason"} = $h;
	    }

	    my $a;
	    if ($chanukah_day) {
		my $a2 = $fxml->{"festival"}->{"Chanukah (Day $chanukah_day)"}->{"kriyah"}->{"aliyah"};
		$a = {
		    "book" => $a2->[0]->{"book"},
		    "parsha" => $a2->[0]->{"parsha"},
		    "begin" => $a2->[0]->{"begin"},
		    "end" => $a2->[2]->{"end"},
		    "num" => "M",
		};
	    } else {
		$a = get_special_aliyah($h, "M");
	    }
	    if ($a) {
		if ($chanukah_day) {
		    $h .= " - Day $chanukah_day";
		    $special{$dt}->{"reason"} = $h;
		}
		my $maftir_reading = sprintf("%s %s - %s",
					     $a->{'book'},
					     $a->{'begin'},
					     $a->{'end'});
		$special{$dt}->{"M"} = $a;
	    }
	    my $a8 = get_special_aliyah($h, "8");
	    $special{$dt}->{"8"} = $a8 if $a8;
	}
    }

    1;
}

# write all of the aliyot for Shabbat to CSV file.
# if $dbh is defined (for fullkriyah), also write to the leyning DB.
sub csv_parasha_event_inner
{
    my($evt,$h,$verses,$aliyot,$dbh) = @_;

    my($year,$month,$day) = Hebcal::event_ymd($evt);
    my $stime2 = Hebcal::date_format_csv($year, $month, $day);
    my $dt = Hebcal::date_format_sql($year, $month, $day);

    if (defined $dbh) {
      my $sth = $dbh->prepare($SQL_INSERT_INTO_LEYNING);
      my $rv = $sth->execute($dt, $h, "T", $verses)
	or croak "can't execute the query: " . $sth->errstr;
    }

    my $book = $verses;
    $book =~ s/\s+.+$//;

    my %aliyot = map { $_->{"num"} => $_ } @{$aliyot};
    $aliyot{"M"} = $special{$dt}->{"M"} if defined $special{$dt}->{"M"};
    $aliyot{"8"} = $special{$dt}->{"8"} if defined $special{$dt}->{"8"};

    my @sorted_aliyot = sort { $a->{'num'} cmp $b->{'num'} } values %aliyot;
    foreach my $aliyah (@sorted_aliyot) {
	my $aliyah_text = sprintf("%s %s - %s",
				  $aliyah->{"book"} || $book,
				  $aliyah->{'begin'}, $aliyah->{'end'});
	if (defined $special{$dt}->{$aliyah->{"num"}}) {
	    $aliyah_text = sprintf("%s %s - %s | %s",
				   $aliyah->{"book"}, $aliyah->{"begin"}, $aliyah->{"end"},
				   $special{$dt}->{"reason"});
	}
	printf CSV
		qq{%s,"%s",%s,"%s",},
		$stime2,
		$h,
		($aliyah->{'num'} eq 'M' ? '"maf"' : $aliyah->{'num'}),
		$aliyah_text;
	print CSV $aliyah->{'numverses'}
	  if $aliyah->{'numverses'};
	print CSV "\015\012";
	if (defined $dbh) {
	  my $sth = $dbh->prepare($SQL_INSERT_INTO_LEYNING);
	  my $rv = $sth->execute($dt, $h, $aliyah->{'num'}, $aliyah_text)
	    or croak "can't execute the query: " . $sth->errstr;
	}
    }
}

# write all of the aliyot for Shabbat to CSV file.
# if $dbh is defined (for fullkriyah), also write to the leyning DB.
sub csv_haftarah_event {
    my($evt,$h,$parshiot,$dbh) = @_;

    my($year,$month,$day) = Hebcal::event_ymd($evt);
    my $dt = Hebcal::date_format_sql($year, $month, $day);

    my $haft = $special{$dt}->{"H"}
      || $parshiot->{'parsha'}->{$h}->{'haftara'};

    if (! defined $haft && $h =~ /^([^-]+)-(.+)$/ &&
	defined $combined{$1} && defined $combined{$2}) {
      my($p1,$p2) = ($1,$2);
      my $ph = ($p1 eq 'Nitzavim') ? $p1 : $p2;
      $haft = $parshiot->{'parsha'}->{$ph}->{'haftara'};
    }

    my $haftarah_reading = $haft;
    if (defined $special{$dt}->{"H"}) {
      $haftarah_reading .= " | " . $special{$dt}->{"reason"};
    }

    csv_haftarah_event_inner($evt,$h,$haftarah_reading,$dbh);
}

sub csv_haftarah_event_inner {
    my($evt,$h,$haftarah_reading,$dbh) = @_;

    my($year,$month,$day) = Hebcal::event_ymd($evt);
    my $dt = Hebcal::date_format_sql($year, $month, $day);
    my $stime2 = Hebcal::date_format_csv($year, $month, $day);

    printf CSV
      qq{%s,"%s","%s","%s",\015\012},
      $stime2,
      $h,
      'Haftara',
      $haftarah_reading;

    if (defined $dbh) {
      my $sth = $dbh->prepare($SQL_INSERT_INTO_LEYNING);
      my $rv = $sth->execute($dt, $h, "H", $haftarah_reading)
	or croak "can't execute the query: " . $sth->errstr;
    }
}

sub csv_extra_newline {
    print CSV "\015\012";
}

sub get_festival_torah_verses {
    my($aliyot) = @_;

    my($torah,$book,$begin,$end);
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			    @{$aliyot}) {
	if ($aliyah->{'num'} =~ /^\d+$/) {
	    if (($book && $aliyah->{'book'} eq $book) ||
		($aliyah->{'num'} eq '8')) {
		$end = $aliyah->{'end'};
	    }
	    $book = $aliyah->{'book'} unless $book;
	    $begin = $aliyah->{'begin'} unless $begin;
	}
    }

    if ($book) {
	$torah = "$book $begin - $end";
    }

    $torah;
}

sub get_festival_xml_for_event {
    my($evt) = @_;

    my($year,$month,$day) = Hebcal::event_ymd($evt);
    my $dow = Date::Calc::Day_of_Week($year, $month, $day);

    my $h = $evt->[$Hebcal::EVT_IDX_SUBJ];
    if ($h =~ /^Rosh Hashana \d{4}/) {
	$h =~ s/ \d{4}$/ I/;
    } elsif ($dow == 6 && $h =~ /^(Pesach|Sukkot).+\(CH''M\)$/) {
	$h = "$1 Shabbat Chol ha-Moed";
    } elsif (defined $hebcal_to_strassfeld{$h}) {
	$h = $hebcal_to_strassfeld{$h};
	# TODO: if Shabbat falls on the third day of Chol ha-Moed
	# Pesach, the readings for the third, fourth, and fifth days are
	# moved ahead
    } elsif ($h =~ /^Chanukah: (\d) Candles$/) {
	my $chanukah_day = $1 - 1;
	my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
	if ($chanukah_day == 7 && $hebdate->{"dd"} == 1) {
	    $h = "Chanukah (Day 7 on Rosh Chodesh)";
	} else {
	    $h = "Chanukah (Day $chanukah_day)";
	}
    } elsif ($h eq "Chanukah: 8th Day") {
	$h = "Chanukah (Day 8)";
    }

    my $fest;
    if ($dow == 6) {
	$fest = $fxml->{'festival'}->{"$h (on Shabbat)"};
    }
    # try without "on Shabbat" if we didn't find it
    $fest = $fxml->{'festival'}->{$h} unless defined $fest;

    if ($dow == 6 && $h =~ /^Chanukah/) {
	my $chanukah_haft_id = "Shabbat Chanukah";
	if ($evt->[$Hebcal::EVT_IDX_SUBJ] eq "Chanukah: 8th Day") {
	    $chanukah_haft_id = "Shabbat Chanukah II";
	}
	my $new_fest = { "kriyah" => { "aliyah" => $fest->{"kriyah"}->{"aliyah"},
				       "haft" => $fxml->{"festival"}->{$chanukah_haft_id}->{"kriyah"}->{"haft"},
				     } };
	$fest = $new_fest;
    }

    ($h,$fest);
}

sub write_holiday_event_to_csv_and_db {
    my($evt) = @_;
    my($h,$fest) = get_festival_xml_for_event($evt);
    if (defined $fest) {
	my $aliyot = $fest->{"kriyah"}->{"aliyah"};
	if (defined $aliyot) {
	    if (ref($aliyot) eq 'HASH') {
		$aliyot = [ $aliyot ];
	    }
	    my $verses = get_festival_torah_verses($aliyot);
	    if ($verses) {
		csv_parasha_event_inner($evt,$h,$verses,$aliyot,$DBH);
		my $haftarah_reading = $fest->{"kriyah"}->{"haft"}->{"reading"};
		csv_haftarah_event_inner($evt,$h,$haftarah_reading,$DBH)
		    if defined $haftarah_reading;
		csv_extra_newline();
		return 1;
	    }
	}
    }
    return undef;
}

sub readings_for_current_year
{
    my($parshiot) = @_;

    my $extra_years = 8;
    my %wrote_csv;
    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
	my $basename = "fullkriyah-$yr.csv";
	my $filename = "$outdir/$basename";
	my $tmpfile = "$outdir/.$basename.$$";
	if ($opts{"f"}) {
	    msg("readings_for_current_year: $filename", $opt_verbose);
	    open(CSV, ">$tmpfile") || croak "$tmpfile: $!\n";
	    print CSV qq{"Date","Parashah","Aliyah","Reading","Verses"\015\012};
	}
	my @events = Hebcal::invoke_hebcal("$HEBCAL_CMD -s -H $yr", "", 0);
	foreach my $evt (@events) {
	    my($year,$month,$day) = Hebcal::event_ymd($evt);
	    my $dt = Hebcal::date_format_sql($year, $month, $day);
	    if ($evt->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/) {
		my $h = $1;
		$parashah_date_sql{$h}->[$i] = $dt;
		$parashah_time{$h} = Hebcal::event_to_time($evt)
		    if $i == 1;	# second year in array

		if ($opts{'f'}) {
		    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
		    my $verses = $parshiot->{'parsha'}->{$h}->{'verse'};
		    csv_parasha_event_inner($evt,$h,$verses,$aliyot,$DBH);
		    csv_haftarah_event($evt,$h,$parshiot,$DBH);
		    csv_extra_newline();
		    $wrote_csv{$dt} = 1;
		}
	    } elsif ($opts{'f'} && ! defined $wrote_csv{$dt}) {
		# write out non-sedra (holiday) event to DB and CSV
		write_holiday_event_to_csv_and_db($evt);
	    }
	}
	if ($opts{"f"}) {
	    close(CSV);
	    rename($tmpfile, $filename) || croak "rename $tmpfile => $filename: $!\n";
	}
    }
}

sub triennial_csv_range {
    my($start_year) = @_;
    sprintf("%d-%d", $start_year, $start_year + 3);
}

sub triennial_csv_basename {
    my($start_year) = @_;
    "triennial-" . triennial_csv_range($start_year) . ".csv";
}

sub triennial_csv
{
    my($parshiot,$events,$bereshit_idx,$readings,$start_year) = @_;

    my $basename = triennial_csv_basename($start_year);
    my $filename = "$outdir/$basename";
    my $tmpfile = "$outdir/.$basename.$$";
    msg("triennial_csv: $filename", $opt_verbose);
    open(CSV, ">$tmpfile") || croak "$tmpfile: $!\n";
    print CSV qq{"Date","Parashah","Aliyah","Triennial Reading"\015\012};

    my $yr = 1;
    for (my $i = $bereshit_idx; $i < @{$events}; $i++)
    {
	my $evt = $events->[$i];
	my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
	if ($subj eq "Parashat Bereshit" && $i != $bereshit_idx) {
	    $yr++;
	    last if ($yr == 4);
	}

	if ($subj =~ /^Parashat (.+)/) {
	    my $h = $1;
	    my $aliyot = $readings->{$h}->[$yr]->[0];
	    my $verses = $parshiot->{'parsha'}->{$h}->{'verse'};
	    csv_parasha_event_inner($evt,$h,$verses,$aliyot,undef);
	    csv_haftarah_event($evt,$h,$parshiot,undef);
	    csv_extra_newline();
	}
    }

    close(CSV);
    rename($tmpfile, $filename) || croak "rename $tmpfile => $filename: $!\n";
}

sub get_saturday
{
    my($now) = time();
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($now);

    my $sat =
    ($wday == 6) ? $now + (60 * 60 * 24) :
	$now + ((6 - $wday) * 60 * 60 * 24);

    # don't bump parashah forward until Wednesday
    if ($wday < 3) {
	$sat -= (7 * 24 * 60 * 60);
    }

    $sat;
}

########################################################################
# from Lingua::EN::Numbers::Ordinate
########################################################################

sub ordsuf ($) {
  return 'th' if not(defined($_[0])) or not( 0 + $_[0] );
   # 'th' for undef, 0, or anything non-number.
  my $n = abs($_[0]);  # Throw away the sign.
  return 'th' unless $n == int($n); # Best possible, I guess.
  $n %= 100;
  return 'th' if $n == 11 or $n == 12 or $n == 13;
  $n %= 10;
  return 'st' if $n == 1; 
  return 'nd' if $n == 2;
  return 'rd' if $n == 3;
  return 'th';
}

sub ordinate ($) {
  my $i = $_[0] || 0;
  return $i . ordsuf($i);
}
