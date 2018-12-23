#!/usr/bin/perl -w

########################################################################
#
# Generates the Torah Readings for http://www.hebcal.com/sedrot/
#
# Calculates full kriyah according to standard tikkun
#
# Calculates triennial according to
#   A Complete Triennial System for Reading the Torah
#   https://www.rabbinicalassembly.org/sites/default/files/public/halakhah/teshuvot/19861990/eisenberg_triennial.pdf
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
use utf8;
use open ":utf8";
use Hebcal ();
use HebcalHtml ();
use HebcalGPL ();
use Date::Calc ();
use Getopt::Long ();
use XML::Simple ();
use POSIX qw(strftime);
use Carp;
use Log::Log4perl qw(:easy);
use DBI;

$0 =~ s,.*/,,;  # basename

my $usage = "usage: $0 [options] aliyah.xml festival.xml output-dir
    --help            Display usage information.
    --[no]html        Enable/Disable HTML pages (default true).
    --israel          Use Israeli sedra scheme (disables triennial functionality!).
    --triennial       Dump triennial readings to comma separated values
    --fullkriyah      Dump full kriyah readings to comma separated values
    --hebyear YEAR    Start with hebrew year YEAR (default this year)
    --dbfile DBFILE   Write state to SQLite3 file
";

my $opt_help;
my $opt_verbose = 0;
my $opt_html = 1;
my $opt_israel;
my $opt_csv_tri;
my $opt_csv_fk;
my $opt_hebyear;
my $opt_dbfile;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "verbose|v+" => \$opt_verbose,
     "html!" => \$opt_html,
     "israel|i" => \$opt_israel,
     "triennial|t" => \$opt_csv_tri,
     "fullkriyah|f" => \$opt_csv_fk,
     "hebyear=i" => \$opt_hebyear,
     "dbfile|D=s" => \$opt_dbfile)) {
    croak $usage;
}

$opt_help && croak $usage;
(@ARGV == 3) || croak $usage;

Log::Log4perl->easy_init($INFO);

my %hebcal_to_strassfeld;

if ($opt_israel) {
    # TODO: figure it out!
    %hebcal_to_strassfeld = (
    );
} else {
    # TODO: if Shabbat falls on the third day of Chol ha-Moed
    # Pesach, the readings for the third, fourth, and fifth days are
    # moved ahead
    %hebcal_to_strassfeld = (
         "Pesach III (CH''M)" => "Pesach Chol ha-Moed Day 1",
         "Pesach IV (CH''M)" => "Pesach Chol ha-Moed Day 2",
#         "Pesach V (CH''M)" => "Pesach Chol ha-Moed Day 3",
#         "Pesach VI (CH''M)" => "Pesach Chol ha-Moed Day 4",
         "Sukkot III (CH''M)" => "Sukkot Chol ha-Moed Day 1",
         "Sukkot IV (CH''M)" => "Sukkot Chol ha-Moed Day 2",
         "Sukkot V (CH''M)" => "Sukkot Chol ha-Moed Day 3",
         "Sukkot VI (CH''M)" => "Sukkot Chol ha-Moed Day 4",
         "Sukkot VII (Hoshana Raba)" => "Sukkot Chol ha-Moed Day 5 (Hoshana Raba)",
    );
}
my $extra_years = 13;

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

my $parashat_hebrew = "\x{05E4}\x{05E8}\x{05E9}\x{05EA}";  # Unicode for "parashat"

my $HEBCAL_CMD = "./hebcal";
$HEBCAL_CMD .= " -i" if $opt_israel;

my $aliyah_in = shift;
my $festival_in = shift;
my $outdir = shift;

if (! -d $outdir) {
    croak "$outdir: $!\n";
}

$| = 1;

## load aliyah.xml data to get parshiot
INFO("Loading $aliyah_in...");
my $axml = XML::Simple::XMLin($aliyah_in);
INFO("Loading $festival_in...");
my $fxml = XML::Simple::XMLin($festival_in);

my %triennial_aliyot;
my %triennial_aliyot_alt;
read_aliyot_metadata($axml, \%triennial_aliyot, \%triennial_aliyot_alt)
    unless $opt_israel;

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

INFO("Finished building internal data structures");

## load 4 years of hebcal event data
my($hebrew_year);
if ($opt_hebyear) {
    $hebrew_year = $opt_hebyear;
} else {
    my($yy,$mm,$dd) = Date::Calc::Today();
    my $hebdate = HebcalGPL::greg2hebrew($yy,$mm,$dd);
    $hebrew_year = $hebdate->{"yy"};
}

# year I in triennial cycle was 5756
my $year_num = (($hebrew_year - 5756) % 3) + 1;
INFO("Current Hebrew year $hebrew_year is year $year_num.");

my @cycle_start_years;
my @triennial_readings;
#my @triennial_alt_readings;
my @triennial_events;
my @bereshit_indices;
my $max_triennial_cycles = 5;
for (my $i = 0; $i < $max_triennial_cycles; $i++) {
    my $year_offset = ($i - 1) * 3;
    my $cycle_start_year = $hebrew_year - ($year_num - 1) + $year_offset;
    $cycle_start_years[$i] = $cycle_start_year;
    INFO("3-cycle started at year $cycle_start_year");
    my($bereshit_idx,$pattern,$events) = get_tri_events($cycle_start_year);
    $triennial_events[$i] = $events;
    $bereshit_indices[$i] = $bereshit_idx;
    unless ($opt_israel) {
	my $cycle_option = calc_variation_options($axml,$pattern);
	$triennial_readings[$i] = cycle_readings(\%triennial_aliyot,$bereshit_idx,$events,$cycle_option);
#	$triennial_alt_readings[$i] = cycle_readings(\%triennial_aliyot_alt,$bereshit_idx,$events,$cycle_option);
    }
}

my %special;
my $special_start_year = $cycle_start_years[0] - 1;
my $special_end_year = math_max( $hebrew_year + $extra_years - 1,
    $cycle_start_years[ $max_triennial_cycles - 1 ] + 3 );
foreach my $yr ($special_start_year .. $special_end_year) {
    INFO("Special readings for $yr");
    my $cmd = "$HEBCAL_CMD -H $yr";
    my @ev = Hebcal::invoke_hebcal_v2($cmd, "", 0);
    special_readings(\%special, \@ev);

    # hack for Pinchas
    $cmd = "$HEBCAL_CMD -s -h -x -H $yr";
    my @ev2 = Hebcal::invoke_hebcal_v2($cmd, "", 0);
    special_pinchas(\%special, \@ev2);
}

my $DBH;
my $SQL_INSERT_INTO_LEYNING;
if ($opt_dbfile) {
    ($DBH,$SQL_INSERT_INTO_LEYNING) = db_open($opt_dbfile);
}

if ($opt_csv_tri) {
    for (my $i = 0; $i < $max_triennial_cycles; $i++) {
	triennial_csv($axml,
		      $triennial_events[$i],
		      $bereshit_indices[$i],
		      $triennial_readings[$i],
		      $cycle_start_years[$i]);
    }
}

my %parashah_date_sql;
my(%parashah_time);
my($saturday) = get_saturday();
readings_for_current_year($axml);

if (!$opt_html) {
    db_cleanup($DBH) if $opt_dbfile;
    exit(0);
}

my $past_readings = readings_for_past_years();

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
	    if ($time >= $NOW && defined $next_reading{$h} && $dt lt $next_reading{$h}) {
		$next_reading{$h} = $dt;
		last;
	    }
	}
    }
}

# init global vars needed for html
my %seph2ashk = reverse %Hebcal::ashk2seph;

my $html_footer = HebcalHtml::footer_bootstrap3(undef, undef, 0, qq{
<script>
\$('#ort-audio').tooltip();
</script>
});

foreach my $h (@parashah_list) {
    write_sedra_page($axml,$h,$prev{$h},$next{$h},
		     \@triennial_readings);
}

write_index_page($axml);

db_cleanup($DBH) if $opt_dbfile;

exit(0);

sub db_open {
    my($dbfile) = @_;
    my $table = $opt_israel ? "leyning_israel" : "leyning";
    my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "",
                           { RaiseError => 1, AutoCommit => 0 })
        or croak $DBI::errstr;
    my @sql = ("DROP TABLE IF EXISTS $table",
         "CREATE TABLE $table (dt TEXT NOT NULL, parashah TEXT NOT NULL, num TEXT NOT NULL, reading TEXT NOT NULL)",
         "CREATE INDEX ${table}_dt ON $table (dt)",
         );
    foreach my $sql (@sql) {
        DEBUG($sql);
        $dbh->do($sql)
            or croak $DBI::errstr;
    }
    my $sql_insert =
      "INSERT INTO $table (dt, parashah, num, reading) VALUES (?, ?, ?, ?)";
    return ($dbh,$sql_insert);
}

sub db_cleanup {
    my($dbh) = @_;
    $dbh->commit;
    $dbh->disconnect;
}

sub math_max {
    my ( $a, $b ) = @_;
    return $a > $b ? $a : $b;
}

sub get_tri_events
{
    my($start) = @_;

    my @events;
    foreach my $cycle (0 .. 3)
    {
	my($yr) = $start + $cycle;
        my @ev = Hebcal::invoke_hebcal_v2("$HEBCAL_CMD -s -h -x -H $yr", "", 0);
	push(@events, @ev);
    }

    my $idx;
    for (my $i = 0; $i < @events; $i++)
    {
        if ($events[$i]->{subj} eq 'Parashat Bereshit')
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
        next unless ($events[$i]->{subj} =~ /^Parashat (.+)/);
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

sub cycle_readings {
    my ( $aliyot, $bereshit_idx, $events, $option ) = @_;

    my %readings;
    my $yr = 1;
    for ( my $i = $bereshit_idx; $i < @{$events}; $i++ ) {
        my $subj = $events->[$i]->{subj};
        if ( $subj eq 'Parashat Bereshit' && $i != $bereshit_idx ) {
            $yr++;
            last if $yr == 4;
        }

        next unless $subj =~ /^Parashat (.+)/;
        my $h = $1;

        my ( $year, $month, $day ) = Hebcal::event_ymd( $events->[$i] );
        my $stime = sprintf( "%02d %s %04d", $day, $Hebcal::MoY_short[$month-1],
            $year );
        my $dt = Hebcal::date_format_sql($year, $month, $day);

        if ( defined $combined{$h} ) {
            my $variation = $option->{$h} . "." . $yr;
            my $a         = $aliyot->{$h}->{$variation};
            croak unless defined $a;
            $readings{$h}->[$yr] = [ $a, $stime, $h, $dt ];
        }
        elsif ( defined $aliyot->{$h}->{$yr} ) {
            my $a = $aliyot->{$h}->{$yr};
            croak unless defined $a;

            $readings{$h}->[$yr] = [ $a, $stime, $h, $dt ];

            if (   $h =~ /^([^-]+)-(.+)$/
                && defined $combined{$1}
                && defined $combined{$2} )
            {
                $readings{$1}->[$yr] = [ $a, $stime, $h, $dt ];
                $readings{$2}->[$yr] = [ $a, $stime, $h, $dt ];
            }
        }
        elsif ( defined $aliyot->{$h}->{"Y.$yr"} ) {
            my $a = $aliyot->{$h}->{"Y.$yr"};
            croak unless defined $a;

            $readings{$h}->[$yr] = [ $a, $stime, $h, $dt ];

            if (   $h =~ /^([^-]+)-(.+)$/
                && defined $combined{$1}
                && defined $combined{$2} )
            {
                $readings{$1}->[$yr] = [ $a, $stime, $h, $dt ];
                $readings{$2}->[$yr] = [ $a, $stime, $h, $dt ];
            }
        }
        else {
            croak "can't find aliyot for $h, year $yr";
        }
    }

    \%readings;
}

sub write_index_page
{
    my($parshiot) = @_;

    my $fn = "$outdir/index.php";
    INFO("write_index_page: $fn");
    open(OUT1, ">$fn.$$") || croak "$fn.$$: $!\n";


    my $xtra_head = <<EOHTML;
<link rel="alternate" type="application/rss+xml" title="RSS" href="index.xml">
EOHTML
;
    print OUT1 HebcalHtml::header_bootstrap3("Torah Readings",
				   "/sedrot/",
				   "single single-post",
				   $xtra_head);
    print OUT1 <<EOHTML;
<div class="row">
<div class="col-sm-12">
<h2>Torah Readings</h2>
<p>Weekly Torah readings (Parashat ha-Shavua) including
verses for each aliyah and accompanying Haftarah. Includes
both traditional (full kriyah) and <a
href="/home/50/what-is-the-triennial-torah-reading-cycle">triennial</a> reading schemes.</p>
EOHTML
    ;

print OUT1 q'<?php
require("../pear/Hebcal/common.inc");
list($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
$gm = $mon + 1;
$gd = $mday;
$gy = $year + 1900;
list($saturday_gy,$saturday_gm,$saturday_gd) = get_saturday($gy, $gm, $gd);
$century = substr($saturday_gy, 0, 2);
$fn = $_SERVER["DOCUMENT_ROOT"] . "/converter/sedra/$century/$saturday_gy.inc";
@include($fn);
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
	    echo "<p>This week&apos;s Torah Portion is <a href=\"", $anchor, "\">", $h, "</a> (read in the Diaspora on ", date("j F Y", $sat_timestamp), ").</p>\n";
	    break;
	}
    }
}
?>
';

    my $download_button_diaspora = download_torah_button("Diaspora", "index.xml");
    my $download_button_israel = download_torah_button("Israel", "israel.xml", "israel-he.xml");

    print OUT1 <<EOHTML;
<div class="btn-toolbar">
$download_button_diaspora
$download_button_israel
<a class="btn btn-sm btn-secondary" title="Download aliyah-by-aliyah breakdown"
href="#download"><i
class="glyphicons glyphicons-download-alt"></i> Leyning spreadsheet</a>
</div><!-- .btn-toolbar -->
</div><!-- .col-sm-12 -->
</div><!-- .row -->

<div class="row">
<div class="col-4">
<h4 id="Genesis">Genesis</h4>
<ol class="list-unstyled">
EOHTML
    ;

    my $book_count = 1;
    my $prev_book = "Genesis";
    foreach my $h (@all_inorder) {
	my($book) = $parshiot->{'parsha'}->{$h}->{'verse'};
	$book =~ s/\s+.+$//;

	if ($prev_book ne $book) {
	    print OUT1 "</ol>\n</div><!-- .col-4 -->\n";
	    if ($book_count++ % 3 == 0) {
		print OUT1 qq{</div><!-- .row -->\n<div class="row">\n};
	    }
	    print OUT1 qq{<div class="col-4">\n<h4 id="$book">$book</h4>\n<ol class="list-unstyled">\n};
	}
	$prev_book = $book;

	my $anchor = lc($h);
	$anchor =~ s/[^\w]//g;
	print OUT1 qq{<li><a href="$anchor">$h</a>\n};
    }

    print OUT1 <<EOHTML;
</ol>
</div><!-- .col-4 -->
<div class="col-4">
<h4 id="DoubledParshiyot">Doubled Parshiyot</h4>
<ol class="list-unstyled">
EOHTML
;

    foreach my $h (@combined) {
	my $anchor = lc($h);
	$anchor =~ s/[^\w]//g;
	print OUT1 qq{<li><a href="$anchor">$h</a>\n};
    }

    print OUT1 <<EOHTML;
</ol>
</div><!-- .col-4 -->
</div><!-- .row -->
<div class="row">
<div class="col-sm-12">
<h4>Parashat ha-Shavua by Hebrew year</h4>
<nav>
<ul class="pagination pagination-sm">
<li class="page-item disabled"><a class="page-link" href="#">Diaspora</a></li>
EOHTML
;
    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
	my $nofollow = $i > 3 ? qq{ rel="nofollow"} : "";
	print OUT1 qq{<li class="page-item"><a$nofollow class="page-link" href="/hebcal/?year=$yr&amp;v=1&amp;month=x&amp;yt=H&amp;s=on&amp;i=off&amp;set=off">$yr</a></li>\n};
    }

    print OUT1 <<EOHTML;
</ul><!-- .pagination -->
</nav>
<nav>
<ul class="pagination pagination-sm">
<li class="page-item disabled"><a class="page-link" href="#">Israel</a></li>
EOHTML
;

    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
	my $nofollow = $i > 3 ? qq{ rel="nofollow"} : "";
	print OUT1 qq{<li class="page-item"><a$nofollow class="page-link" href="/hebcal/?year=$yr&amp;v=1&amp;month=x&amp;yt=H&amp;s=on&amp;i=on&amp;set=off">$yr</a></li>\n};
    }

    print OUT1 <<EOHTML;
</ul><!-- .pagination -->
</nav>
EOHTML
;

    my $full_kriyah_download_html = action_button_download_html("Full Kriyah (Diaspora)");
    $full_kriyah_download_html .= qq{<li><a class="dropdown-item" href="https://drive.google.com/folderview?id=0B3OlPVknpjg7VDc0TWp2cDdvQU0">Google Drive spreadsheets</a>};
    $full_kriyah_download_html .= qq{<li class="dropdown-divider"></li>};

    my $fk_israel_download_html = action_button_download_html("Full Kriyah (Israel)");
    $fk_israel_download_html .= qq{<li><a class="dropdown-item" href="https://drive.google.com/folderview?id=0B3OlPVknpjg7aUxXSXZiY3FTNDA">Google Drive spreadsheets</a>};
    $fk_israel_download_html .= qq{<li class="dropdown-divider"></li>};
    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
	my $basename = "fullkriyah-$yr.csv";
        $full_kriyah_download_html .= qq{<li><a class="dropdown-item download" id="leyning-fullkriyah-$yr" href="$basename" download="$basename">$basename</a>};
        $basename = "fullkriyah-il-$yr.csv";
        $fk_israel_download_html .= qq{<li><a class="dropdown-item download" id="leyning-fullkriyah-il-$yr" href="$basename" download="$basename">$basename</a>};
    }
    $full_kriyah_download_html .= qq{</ul>\n</div>\n};
    $fk_israel_download_html .= qq{</ul>\n</div>\n};

    my $triennial_download_html = action_button_download_html("Triennial (Diaspora)");
    $triennial_download_html .= qq{<li><a class="dropdown-item" href="https://drive.google.com/folderview?id=0B3OlPVknpjg7SXhHUjdXYzM4Y0E">Google Drive spreadsheets</a>};    
    $triennial_download_html .= qq{<li class="dropdown-divider"></li>};

    for (my $i = 0; $i < $max_triennial_cycles; $i++) {
	my $start_year = $cycle_start_years[$i];
	my $triennial_range = triennial_csv_range($start_year);
	my $triennial_basename = triennial_csv_basename($start_year);
	$triennial_download_html .= qq{<li><a class="dropdown-item download" id="leyning-triennial-$start_year" href="$triennial_basename" download="$triennial_basename"> $triennial_basename</a></li>};
    }
    $triennial_download_html .= qq{</ul>\n</div>\n};

    print OUT1 <<EOHTML;
<h4 id="download">Download leyning spreadsheet <small class="text-muted">aliyah-by-aliyah breakdown of Torah readings</small></h4>
<p>Leyning coordinators can download these Comma Separated
Value (CSV) files and import into Microsoft Excel or some other
spreadsheet program.</p>
<div class="btn-toolbar">
$full_kriyah_download_html
$triennial_download_html
$fk_israel_download_html
</div><!-- .btn-toolbar -->
<p> </p>
<p>Example content:</p>
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
</div><!-- .col-sm-12 -->
</div><!-- .row -->
EOHTML
;

    print OUT1 $html_footer;

    close(OUT1);
    rename("$fn.$$", $fn) || croak "$fn: $!\n";

    1;
}

sub download_torah_button {
    my($where,$rss_href,$rss_href2) = @_;

    my $filename = "torah-readings-" . lc($where);
    my $html = action_button_download_html("Download for $where");
    my $feed_title = "Parashat ha-Shavua RSS feed";
    my $rss_html2 = "";
    if ($rss_href2) {
        $rss_html2 = qq{  <li><a class="dropdown-item" href="$rss_href2">$feed_title (Hebrew)</a></li>};
        $feed_title .= " (Translit.)";
    }
    $html .= <<EOHTML;
  <li><a class="dropdown-item download" id="quick-ical-$filename" href="webcal://download.hebcal.com/ical/$filename.ics">iPhone, iPad, Mac OS X</a></li>
  <li><a class="dropdown-item download" id="quick-gcal-$filename" href="http://www.google.com/calendar/render?cid=http%3A%2F%2Fdownload.hebcal.com%2Fical%2F$filename.ics">Google Calendar</a></li>
  <li><a class="dropdown-item download" id="quick-csv-$filename" href="http://download.hebcal.com/ical/$filename.csv" download="$filename.csv">Microsoft Outlook CSV</a>
  <li class="dropdown-divider"></li>
  <li><a class="dropdown-item" href="$rss_href">$feed_title</a></li>
$rss_html2
 </ul>
</div><!-- .btn-group -->
EOHTML
;
    return $html;
}

sub action_button_download_html {
    my($button_title) = @_;
    my $action_button_download_html = <<EOHTML;
<div class="btn-group mr-1">
 <button type="button" class="btn btn-sm btn-secondary dropdown-toggle" data-toggle="dropdown" aria-expanded="false">
  $button_title <span class="caret"></span>
 </button>
 <ul class="dropdown-menu" role="menu">
EOHTML
;
    return $action_button_download_html;
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

	INFO("  $parashah: $pat ($option->{$parashah})");
    }

    $option;
}

sub read_aliyot_metadata
{
    my($parshiot,$aliyot,$aliyot_alt) = @_;

    # build a lookup table so we don't have to follow num/variation/sameas
    foreach my $h (keys %{$parshiot->{'parsha'}}) {
        my $parashah = $parshiot->{'parsha'}->{$h};
        read_aliyot_metadata_inner( $aliyot, $h, $parashah->{'triennial'}->{'year'} );
        my $alt = $parashah->{'triennial-alt'};
        if ( defined $alt ) {
            read_aliyot_metadata_inner( $aliyot_alt, $h, $alt->{'year'} );
        }
    }

    1;
}

sub read_aliyot_metadata_inner {
    my ( $aliyot, $h, $yrs ) = @_;

    foreach my $y ( @{$yrs} ) {
        if ( defined $y->{'num'} ) {
            $aliyot->{$h}->{ $y->{'num'} } = $y->{'aliyah'};
        }
        elsif ( defined $y->{'variation'} ) {
            if ( !defined $y->{'sameas'} ) {
                $aliyot->{$h}->{ $y->{'variation'} } = $y->{'aliyah'};
            }
        }
        else {
            croak "strange data for Parashat $h";
        }
    }

    # second pass for sameas
    foreach my $y ( @{$yrs} ) {
        if ( defined $y->{'variation'} && defined $y->{'sameas'} ) {
            my $sameas = $y->{'sameas'};
            my $src    = $aliyot->{$h}->{$sameas};
            croak "Bad sameas=$sameas for Parashat $h" unless defined $src;
            $aliyot->{$h}->{ $y->{'variation'} } = $src;
        }
    }
}

sub write_sedra_sidebar {
    my($parshiot,$current) = @_;

    print OUT2 <<EOHTML;
<div class="col-sm-2 d-none d-sm-block">
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
</div><!-- .col-sm-2 -->
EOHTML
;
}

sub write_drash_links {
    my($drash,$h) = @_;

    my @sites = qw(ou torg reform jts chabad);
    my $count = 0;
    foreach my $site (@sites) {
        $count++ if $drash->{$site};
    }
    return 0 unless $count;

    print OUT2 qq{<div class="d-print-none">\n<h4 id="drash">Commentary</h4>\n<ul class="bullet-list-inline">\n};

    my %site_name = (
        "ou" => "Orthodox Union",
        "torg" => "Torah.org",
        "reform" => "Reform Judaism",
        "chabad" => "Chabad",
        "uscj" => "United Synagogue of Conservative Judaism",
        "jts" => "Jewish Theological Seminary",
    );

    foreach my $site (@sites) {
        if ($drash->{$site}) {
            my $name = $site_name{$site};
            print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from $name" href="$drash->{$site}">$name</a>\n};
        }
    }

    print OUT2 qq{</ul>\n</div><!-- .d-print-none -->\n};

    return $count;
}

sub aliyot_combine_67 {
    my($aliyot) = @_;
    my %out = map { $_->{"num"} => $_ } @{$aliyot};
    my $a6 = $out{6};
    my $a7 = $out{7};
    my $aa = {
        "book" => $a6->{"book"},
        "parsha" => $a6->{"parsha"},
        "begin" => $a6->{"begin"},
        "end" => $a7->{"end"},
        "num" => "6",
    };
    if ($a6->{"numverses"} && $a7->{"numverses"}) {
        $aa->{"numverses"} = $a6->{"numverses"} + $a7->{"numverses"};
    }
    $out{6} = $aa;
    delete $out{7};
    return \%out;
}

# transform an array of aliyot into a hash-oriented object
# and also handle aliyot 6, 7, 8 and M at the same time
sub remap_aliyot_special_7maf {
    my($aliyot,$dt) = @_;
    my %m = map { $_->{"num"} => $_ } @{$aliyot};
    if (defined $special{$dt}->{"7"}) {
        my $aliyot6 = aliyot_combine_67($aliyot);
        $m{"6"} = $aliyot6->{6};
    }
    foreach my $num (qw(7 8 M)) {
        $m{$num} = $special{$dt}->{$num} if defined $special{$dt}->{$num};
    }
    \%m;
}

sub json_ld_markup {
    my($h,$startDate) = @_;

    my $s = <<EOHTML;
<script type="application/ld+json">
{
  "\@context" : "http://schema.org",
  "\@type" : "Event",
  "name" : "$h Torah Reading",
  "startDate" : "$startDate",
  "location" : {
    "\@type" : "Place",
    "name" : "Diaspora"
  }
}
</script>
EOHTML
;
    return $s;
}

sub sefaria_verse_url {
    my($bookverse) = @_;
    if ($bookverse =~ /^([^\d]+)(\d.+)$/) {
        my $book = $1;
        my $verses = $2;
        $book =~ s/\s+$//;
        $book =~ s/ /_/g;
        $verses =~ s/\;.+//;  # discard second part of Haftarah
        $verses =~ s/ - /-/;
        return Hebcal::get_sefaria_url($book, $verses);
    } else {
        die "Can't parse bookverse '$bookverse'";
    }
}

sub write_sedra_page
{
    my($parshiot,$h,$prev,$next,$triennial_readings) = @_;

    my($hebrew,$torah,$haftarah,$haftarah_seph,
       $torah_href,$haftarah_href,
       $drash) = get_parashah_info($parshiot,$h);

    if ($hebrew) {
	$hebrew = Hebcal::hebrew_strip_nikkud($hebrew);
    }

    my $seph = '';
    my $ashk = '';

    if (defined($haftarah_seph) && ($haftarah_seph ne $haftarah))
    {
        my $seph_href = sefaria_verse_url($haftarah_seph);
        $seph = qq{\n<br>Haftarah for Sephardim: <a href="$seph_href">$haftarah_seph</a>};
	$ashk = " for Ashkenazim";
    }

    my $anchor = lc($h);
    $anchor =~ s/[^\w]//g;
    my $fn = "$outdir/$anchor";
    INFO("write_sedra_page: $fn");
    open(OUT2, ">$fn.$$") || croak "$fn.$$: $!\n";

    my $keyword = $h;
    $keyword .= ",$seph2ashk{$h}" if defined $seph2ashk{$h};

    my $description = "Parashat $h ($torah). ";
    my $default_intro_summary = qq{<p>};
    my $intro_summary = $default_intro_summary;
    if ($next_reading{$h}) {
	my $dt = date_sql_to_dd_MMM_yyyy($next_reading{$h});
	$intro_summary .= "Next read in the Diaspora on $dt.";
	$description .= "Read on $dt in the Diaspora.";
    } else {
	$description .= "List of dates when read in the Diaspora.";
    }

    if (defined $parashah2id{$h}) {
	$intro_summary .= "\nParashat $h is the " . Hebcal::ordinate($parashah2id{$h})
	    . " weekly Torah portion in the annual Jewish cycle of Torah reading."
    }

    if ($intro_summary eq $default_intro_summary) {
	$intro_summary = "";
    } else {
	$intro_summary .= "</p>";
    }

    $description .= " Torah reading, Haftarah, links to audio and commentary.";

    my $xtra_head = qq{<meta name="description" content="$description">\n};
    if ($next_reading{$h}) {
        $xtra_head .= json_ld_markup($h, $next_reading{$h});
    }

    print OUT2 HebcalHtml::header_bootstrap3(
        "$h - Torah Portion - $hebrew", "/sedrot/$anchor", "",
        $xtra_head, 0, 1);

    my $amazon_link2 =
	"https://www.amazon.com/o/ASIN/0899060145/hebcal-20";

#    write_sedra_sidebar($parshiot,$h);


    my $ort_tikkun = "";
    if (defined $parashah2id{$h}) {
        my($c1,$v1) = ($torah =~ /^\w+\s+(\d+):(\d+)/);
        my $url = Hebcal::get_bible_ort_org_url($torah, $c1, $v1, $parashah2id{$h});
        $url =~ s/&/&amp;/g;
        #my $img = qq{<img src="/i/glyphicons_pro_1.7/glyphicons/png/glyphicons_184_volume_up.png" width="24" height="26" alt="Audio from ORT">};
        #my $img = qq{<i class="icon-volume-up icon-large"></i> Audio from ORT &raquo;};
        $ort_tikkun = qq{ &nbsp;<small><a class="outbound d-print-none" data-toggle="tooltip" id="ort-audio" rel="nofollow" href="$url" title="Tikkun &amp; audio from World ORT"><i class="glyphicons glyphicons-volume-up"></i></a></small>};
    }

    my($torah_book,undef) = split(/ /, $torah, 2);

    print OUT2 <<EOHTML;
<div class="row">
<div class="col-sm-12">
<div class="d-print-none">
<div class="d-none d-sm-block">
<nav>
<ol class="breadcrumb">
  <li class="breadcrumb-item"><a href="/sedrot/">Torah Readings</a></li>
  <li class="breadcrumb-item"><a href="/sedrot/#$torah_book">$torah_book</a></li>
  <li class="breadcrumb-item active">$h</li>
</ol>
</nav>
</div><!-- .d-none d-sm-block -->
</div><!-- .d-print-none -->
<h2><span class="d-none d-sm-inline">Parashat</span> $h / <bdo dir="rtl"><span class="d-none d-sm-inline" lang="he" dir="rtl">$parashat_hebrew</span> <span lang="he" dir="rtl">$hebrew</span></bdo></h2>
$intro_summary
<h4 id="torah"><span class="d-none d-sm-inline">Torah Portion:</span>
<a class="outbound" href="$torah_href"
title="English translation from JPS Tanakh">$torah</a>$ort_tikkun</h4>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<div class="row">
<div class="col-12 col-sm-3">
<h5>Full Kriyah</h5>
<ol class="list-unstyled">
EOHTML
;

    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
    my %fk_aliyot;
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$aliyot})
    {
	print OUT2 "<li>", format_aliyah($aliyah,$h,$torah);
        $fk_aliyot{$aliyah->{'num'}} = $aliyah;
    }

    print OUT2 "</ol>\n</div><!-- fk -->\n";

    write_sedra_tri_cells($h,$torah,$triennial_readings->[1]);

    print OUT2 qq{</div><!-- .row -->\n};

    if (defined $parashah_date_sql{$h}) {
	my %sp_dates;
	foreach my $dt (@{$parashah_date_sql{$h}}) {
            if (defined $dt && (defined $special{$dt}->{"M"}
                || defined $special{$dt}->{"7"}
                || defined $special{$dt}->{"8"})) {
		my $reason = $special{$dt}->{"reason"};
		push(@{$sp_dates{$reason}}, $dt);
	    }
	}

	if (keys %sp_dates) {
            print OUT2 qq{<div class="row">\n<div class="col-sm-12">\n};
	    print OUT2 qq{<h5>Special Readings</h5>\n};
	    foreach my $reason (sort keys %sp_dates) {
		my $info = "";
		my $count = 0;
                # combine 6th + 7th aliyah if there's a special 7th aliyah
                if (defined $special{$sp_dates{$reason}->[0]}->{"7"}) {
                    my $aliyot6 = aliyot_combine_67($aliyot);
                    foreach my $num (1..6) {
                        my $aa = $aliyot6->{$num};
                        $info .= "<br>\n" if $num != 1;
                        $info .= format_aliyah($aa, $h, $torah, 1);
                    }
                    $count = 6;
                }
		foreach my $aliyah (qw(7 8 M)) {
		  my $aa = $special{$sp_dates{$reason}->[0]}->{$aliyah};
		  if ($aa) {
		    my $aa_parashah = $all_inorder[$aa->{'parsha'} - 1];
		    $info .= "<br>\n" if $count++;
		    $info .= format_aliyah($aa, $aa_parashah, undef, 1);
		  }
		}
#		print OUT2 "<br>\n" if $count++;

                my @sp_date_html = map {
                    my $dt0 = $_;
                    my $dt1 = date_sql_to_dd_MMM_yyyy($dt0);
                    qq{<time datetime="$dt0" class="text-muted">$dt1</time>};
                } @{$sp_dates{$reason}};
                my $sp_date_html_comma_list = join(", ", @sp_date_html);
                print OUT2 <<EOHTML;
<p>On <strong>$reason</strong> -
<small>$sp_date_html_comma_list</small>
<br>
$info
</p>
EOHTML
;
	    }
            print OUT2 qq{</div><!-- .col-sm-12 -->\n</div><!-- .row -->\n};
	}
    }

    print OUT2 <<EOHTML;
<div class="row">
<div class="col-sm-12">
<h4 id="haftarah">Haftarah$ashk: <a class="outbound"
href="$haftarah_href"
title="English translation from JPS Tanakh">$haftarah</a>$seph</h4>
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
#		my $sp_href = $fxml->{'festival'}->{$sp_festival}->{'kriyah'}->{'haft'}->{'href'};
                my $sp_href = sefaria_verse_url($sp_verse);

		if ($h eq "Pinchas" && ! defined $sp_href) {
#		  $sp_href = "http://www.jtsa.edu/PreBuilt/ParashahArchives/jpstext/mattot_haft.shtml";
                  $sp_href = sefaria_verse_url("Jeremiah 1:1 - 2:3");
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

    write_drash_links($drash,$h);

    if (defined $parashah_date_sql{$h}) {
        my $list_style = $combined{$h} ? "list-unstyled" : "bullet-list-inline";
	print OUT2 <<EOHTML;
<h4 id="dates">List of Dates</h4>
Parashat $h is read in the Diaspora on:
<ul class="$list_style">
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
	print OUT2 qq{<h4>Triennial readings for previous and future cycles</h4>\n};
	print OUT2 qq{<div class="row">\n};
	write_sedra_tri_cells($h,$torah,$triennial_readings->[0]);
	print OUT2 qq{</div><!-- .row -->\n};
	print OUT2 qq{<div class="row">\n};
	write_sedra_tri_cells($h,$torah,$triennial_readings->[2]);
	print OUT2 qq{</div><!-- .row -->\n};
    }

    print OUT2 <<EOHTML;
<h4 id="ref">References</h4>
<dl>
<dt><em><a class="amzn" id="chumash-2"
href="$amazon_link2">The
Chumash: The Stone Edition (Artscroll Series)</a></em>
<dd>Nosson Scherman, Mesorah Publications, 1993
<dt><em><a class="outbound"
href="https://www.rabbinicalassembly.org/sites/default/files/public/halakhah/teshuvot/19861990/eisenberg_triennial.pdf">A
Complete Triennial System for Reading the Torah</a></em>
<dd>Committee on Jewish Law and Standards of the Rabbinical Assembly
</dl>
EOHTML
;

    print OUT2 <<EOHTML;
</div><!-- .col-sm-12 -->
</div><!-- .row -->
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
        my $read_on_html = $tri_date[$yr] ? qq{\n<br><span class="h6 small text-muted">$tri_date[$yr]</span>} : "";
	print OUT2 <<EOHTML;
<div class="col-4 col-sm-3">
<h5>Triennial Year&nbsp;$yr$read_on_html</h5>
EOHTML
;
	print_tri_cell($triennial_readings,$h,$yr,$torah);
        print OUT2 qq{</div><!-- tri$yr -->\n};
    }
    1;
}

sub format_html_date {
  my($gy,$gm,$gd) = @_;
  $gm =~ s/^0//;
  $gd =~ s/^0//;
  my $nofollow = $gy > $this_year + 2 ? qq{ rel="nofollow"} : "";
  my $args = "";
  foreach my $opt (qw(s maj min mod mf ss nx)) {
    $args .= join("", "&amp;", $opt, "=on");
  }
  sprintf "<a title=\"%s %d holiday calendar\"%s href=\"/hebcal/?v=1&amp;year=%d&amp;month=%d" .
    $args . "&amp;set=off#hebcal-results\">%02d %s %d</a>",
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

	print OUT2 qq{<p>Read separately. See:</p>\n<ul class="list-unstyled">\n};

	my($anchor) = lc($p1);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor\">$p1</a>\n";
	print OUT2 qq{- <span class="text-muted">},
	    $triennial_readings->{$p1}->[$yr]->[1], qq{</span>\n};

	$anchor = lc($p2);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor\">$p2</a>\n";
	print OUT2 qq{- <span class="text-muted">},
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

    print OUT2 qq{<ul class="list-unstyled">\n};
    my $dt = $triennial->[$yr]->[3];
    my $mapped_aliyot = remap_aliyot_special_7maf($triennial->[$yr]->[0],$dt);

    my @sorted_aliyot = sort { $a->{'num'} cmp $b->{'num'} } values %{$mapped_aliyot};
    foreach my $aliyah (@sorted_aliyot) {
        my $show_book = defined $aliyah->{'book'} ? 1 : 0;
        my $torah0 = $show_book ? $aliyah->{'book'} : $torah;
        print OUT2 "<li>", format_aliyah($aliyah,$h,$torah0,$show_book,1);
    }
    print OUT2 "</ul>\n";
}

sub format_aliyah
{
    my($aliyah,$h,$torah,$show_book,$is_triennial) = @_;

    my($book,$verses) = Hebcal::get_book_and_verses($aliyah, $torah);
    my $sefaria_url = Hebcal::get_sefaria_url($book,$verses);
    $sefaria_url =~ s/&/&amp;/g;

    my $tri_sefaria = $is_triennial ? "0" : "1";
    $sefaria_url .= "&amp;aliyot=$tri_sefaria";

    my $info = $verses;

    if ($show_book) {
        $info = "$book $info";
    }

    $info = qq{<a class="outbound" title="Hebrew-English text and commentary from Sefaria.org" href="$sefaria_url">$info</a>};

    my $label = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    $info = "$label: $info\n";

    if ($aliyah->{'numverses'}) {
	$info .= qq{<small class="muted">(} . $aliyah->{'numverses'} .
	    "&nbsp;p'sukim)</small>\n";
    }

    $info;
}

sub most_recent_past_reading {
    my($h) = @_;
    my $latest_before_now;
    foreach my $dt (@{$past_readings->{$h}}) {
        my($year,$month,$day) = split(/-/, $dt);
        my $time = Date::Calc::Date_to_Time($year,$month,$day,12,59,59);
        if ($time < $NOW) {
            $latest_before_now = $dt;
        }
    }
    return $latest_before_now;
}

sub get_parashah_links {
    my($h,$parashah) = @_;
    my $out = {};
    my $links = $parashah->{'links'}->{'link'};
    $links = [ $links ] unless ref($links) eq "ARRAY";
    foreach my $l (@{$links}) {
        if ($l->{'rel'} eq 'drash:ou.org') {
            my $target = $l->{'target'};
            $target =~ s/ /\%20/g;
            $target =~ s/\'/\%27/g;
            $out->{ou} = "https://www.ou.org/torah/parsha/#?post_terms.parshiot.name.unanalyzed=$target";
        } elsif ($l->{'rel'} eq 'drash:torah.org') {
            my $href = $l->{'href'};
            $href =~ s/&/&amp;/g;
            $out->{torg} = $href;
        } elsif ($l->{'rel'} eq 'drash:reformjudaism.org') {
            my $target = $l->{'target'};
            $out->{reform} = "http://www.reformjudaism.org/learning/torah-study/$target";
        } elsif ($l->{'rel'} eq 'drash:jtsa.edu') {
            my $cid = $l->{'cid'};
            my $cid2 = $l->{'cid2'};
            if ($cid && $cid2 && $cid2 lt $cid) {
                my $tmp = $cid;
                $cid = $cid2;
                $cid2 = $tmp;
            }
            my $url = "http://www.jtsa.edu/jts-torah-online?parashah=$cid";
            if ($cid2) {
                $url .= "&amp;parashah=$cid2";
            }
            $out->{jts} = $url;
        } elsif ($l->{'rel'} eq 'drash:uscj.org') {
            my $target = $l->{'target'};
            my $dt = most_recent_past_reading($h);
            if ($target && $dt) {
                my($year,$month,$day) = split(/-/, $dt);
                my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
                my $hyear = $hebdate->{"yy"};
                $out->{uscj} = "http://uscj.org/JewishLivingandLearning/WeeklyParashah/TorahSparks/Archive/_$hyear/$target$hyear.aspx";
            }
#        } elsif ($l->{'rel'} eq 'torah') {
#            $out->{torah} = $l->{'href'};
        } elsif ($l->{'rel'} eq 'drash:chabad.org') {
            my $target = $l->{'target'};
            $out->{chabad} = "http://www.chabad.org/article.asp?aid=$target";
        }
    }

    $out->{torah} = sefaria_verse_url($parashah->{'verse'});

    return $out;
}

sub get_parashah_info
{
    my($parshiot,$h) = @_;


    my($hebrew);
    my($torah,$haftarah,$haftarah_seph);
    my($torah_href,$haftarah_href);
    my $links;
    if ($h =~ /^([^-]+)-(.+)$/ &&
	defined $combined{$1} && defined $combined{$2})
    {
	my($p1,$p2) = ($1,$2);

	# HEBREW PUNCTUATION MAQAF (U+05BE)
        $hebrew = join("", $parshiot->{'parsha'}->{$p1}->{'hebrew'},
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

        my $links0 = get_parashah_links($ph,$parshiot->{'parsha'}->{$ph});
        my $torah_href0 = $links0->{torah};

#	$haftarah_href = $torah_href0;
#	$haftarah_href =~ s/.shtml$/_haft.shtml/;
        $haftarah_href = sefaria_verse_url($haftarah);

	# for now, link torah reading to first part
        my $links1 = get_parashah_links($p1,$parshiot->{'parsha'}->{$p1});
        $torah_href = $links1->{torah};

	# grab drash for the combined reading
        $links = get_parashah_links($h,$parshiot->{'parsha'}->{$h});
    }
    else
    {
        $hebrew = $parshiot->{'parsha'}->{$h}->{'hebrew'};
	$torah = $parshiot->{'parsha'}->{$h}->{'verse'};
	$haftarah = $parshiot->{'parsha'}->{$h}->{'haftara'};
	$haftarah_seph = $parshiot->{'parsha'}->{$h}->{'sephardic'};

        $links = get_parashah_links($h,$parshiot->{'parsha'}->{$h});
        $torah_href = $links->{torah};

#	$haftarah_href = $torah_href;
#	$haftarah_href =~ s/.shtml$/_haft.shtml/;
        $haftarah_href = sefaria_verse_url($haftarah);
    }

    ($hebrew,$torah,$haftarah,$haftarah_seph,
     $torah_href,$haftarah_href,$links);
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
    my($special, $events) = @_;
    foreach my $evt (@{$events}) {
        next unless "Parashat Pinchas" eq $evt->{subj};
	my($year,$month,$day) = Hebcal::event_ymd($evt);
	my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
	# check to see if it's after the 17th of Tammuz
	if ($hebdate->{"mm"} > 4
	    || ($hebdate->{"mm"} == 4 && $hebdate->{"dd"} > 17)) {
	    my $dt = Hebcal::date_format_sql($year, $month, $day);
	    $special->{$dt}->{"H"} = "Jeremiah 1:1 - 2:3";
	    $special->{$dt}->{"reason"} = "Pinchas occurring after 17 Tammuz";
	}
    }
}

sub special_readings
{
    my($special, $events) = @_;

    for (my $i = 0; $i < @{$events}; $i++) {
	my($year,$month,$day) = Hebcal::event_ymd($events->[$i]);
	my $dt = Hebcal::date_format_sql($year, $month, $day);
	next if defined $special->{$dt};

	my $dow = Date::Calc::Day_of_Week($year, $month, $day);

        my $h = $events->[$i]->{subj};
	my $chanukah_day = 0;
	# hack! for Shabbat Rosh Chodesh
	if ($dow == 6 && $h =~ /^Rosh Chodesh/
            && $events->[$i+1]->{subj} =~ /^Chanukah: (\d) Candles/
	    && $1 > 1
	    && defined $events->[$i+1]
	    && Hebcal::event_dates_equal($events->[$i], $events->[$i+1])) {
	    $h = "Shabbat Rosh Chodesh Chanukah"; # don't set $chanukah_day = 6
	} elsif ($dow == 6 && $h =~ /^Rosh Chodesh/
            && $events->[$i+1]->{subj} =~ /^Shabbat HaChodesh/
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
	    next if defined $special->{$dt};
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
		$special->{$dt}->{"H"} = $haft;
		$special->{$dt}->{"reason"} = $h;
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
		    $special->{$dt}->{"reason"} = $h;
		}
		my $maftir_reading = sprintf("%s %s - %s",
					     $a->{'book'},
					     $a->{'begin'},
					     $a->{'end'});
		$special->{$dt}->{"M"} = $a;
	    }
            foreach my $num (1..8) {
                my $aa = get_special_aliyah($h, $num);
                $special->{$dt}->{$num} = $aa if $aa;
            }
	}
    }

    1;
}

# write all of the aliyot for Shabbat to CSV file.
# if $dbh is defined (for fullkriyah), also write to the leyning DB.
sub csv_parasha_event_inner
{
    my($evt,$h,$verses,$aliyot,$dbh,$tri) = @_;

    my($year,$month,$day) = Hebcal::event_ymd($evt);
    my $stime2 = Hebcal::date_format_csv($year, $month, $day);
    my $dt = Hebcal::date_format_sql($year, $month, $day);

    my $sth;
    if (defined $dbh) {
      $sth = $dbh->prepare($SQL_INSERT_INTO_LEYNING);
      if (!$tri) {
        my $rv = $sth->execute($dt, $h, "T", $verses)
          or croak "can't execute the query: " . $sth->errstr;
      }
    }

    my $book = $verses;
    $book =~ s/\s+.+$//;

    my $mapped_aliyot = remap_aliyot_special_7maf($aliyot,$dt);

    my @sorted_aliyot = sort { $a->{'num'} cmp $b->{'num'} } values %{$mapped_aliyot};
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
          my $aliyah_num = $tri
                ? "Tri" . $aliyah->{'num'}
                : $aliyah->{'num'};
	  my $rv = $sth->execute($dt, $h, $aliyah_num, $aliyah_text)
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

    my $h = $evt->{subj};
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
        if ($evt->{subj} eq "Chanukah: 8th Day") {
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
		csv_parasha_event_inner($evt,$h,$verses,$aliyot,$DBH,0);
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

sub readings_for_past_years {
    my $past = {};
    foreach my $i (0 .. 18) {
        my $yr = $hebrew_year - 18 + $i;
        INFO("readings_for_past_years: $yr");
        my @events = Hebcal::invoke_hebcal_v2("$HEBCAL_CMD -s -x -h -H $yr", "", 0);
        foreach my $evt (@events) {
            next unless $evt->{subj} =~ /^Parashat (.+)/;
            my $h = $1;
            my($year,$month,$day) = Hebcal::event_ymd($evt);
            my $dt = Hebcal::date_format_sql($year, $month, $day);
            push(@{$past->{$h}}, $dt);
        }
    }
    return $past;
}

sub readings_for_current_year
{
    my($parshiot) = @_;

    my %wrote_csv;
    foreach my $i (0 .. $extra_years) {
	my $yr = $hebrew_year - 1 + $i;
        my $basename = "fullkriyah";
        $basename .= "-il" if $opt_israel;
        $basename .= "-$yr.csv";
	my $filename = "$outdir/$basename";
	my $tmpfile = "$outdir/.$basename.$$";
	if ($opt_csv_fk) {
	    INFO("readings_for_current_year: $filename");
	    open(CSV, ">$tmpfile") || croak "$tmpfile: $!\n";
	    print CSV qq{"Date","Parashah","Aliyah","Reading","Verses"\015\012};
	}
        my @events = Hebcal::invoke_hebcal_v2("$HEBCAL_CMD -s -H $yr", "", 0);
	foreach my $evt (@events) {
	    my($year,$month,$day) = Hebcal::event_ymd($evt);
	    my $dt = Hebcal::date_format_sql($year, $month, $day);
            if ($evt->{subj} =~ /^Parashat (.+)/) {
		my $h = $1;
		$parashah_date_sql{$h}->[$i] = $dt;
		$parashah_time{$h} = Hebcal::event_to_time($evt)
		    if $i == 1;	# second year in array

		if ($opt_csv_fk) {
		    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
		    my $verses = $parshiot->{'parsha'}->{$h}->{'verse'};
		    csv_parasha_event_inner($evt,$h,$verses,$aliyot,$DBH,0);
		    csv_haftarah_event($evt,$h,$parshiot,$DBH);
		    csv_extra_newline();
		    $wrote_csv{$dt} = 1;
		}
	    } elsif ($opt_csv_fk && ! defined $wrote_csv{$dt}) {
		# write out non-sedra (holiday) event to DB and CSV
		write_holiday_event_to_csv_and_db($evt);
	    }
	}
	if ($opt_csv_fk) {
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
    INFO("triennial_csv: $filename");
    open(CSV, ">$tmpfile") || croak "$tmpfile: $!\n";
    print CSV qq{"Date","Parashah","Aliyah","Triennial Reading"\015\012};

    my $yr = 1;
    for (my $i = $bereshit_idx; $i < @{$events}; $i++)
    {
	my $evt = $events->[$i];
        my $subj = $evt->{subj};
	if ($subj eq "Parashat Bereshit" && $i != $bereshit_idx) {
	    $yr++;
	    last if ($yr == 4);
	}

	if ($subj =~ /^Parashat (.+)/) {
	    my $h = $1;
	    my $aliyot = $readings->{$h}->[$yr]->[0];
	    my $verses = $parshiot->{'parsha'}->{$h}->{'verse'};
	    csv_parasha_event_inner($evt,$h,$verses,$aliyot,$DBH,1);
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
