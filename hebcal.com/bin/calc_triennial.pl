#!/usr/local/bin/perl -w

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
# $Id$
#
# Copyright (c) 2012  Michael J. Radwin.
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
use utf8;
use open ":utf8";
use Hebcal ();
use HebcalGPL ();
use Date::Calc ();
use Getopt::Std ();
use XML::Simple ();
use Time::Local ();
use POSIX qw(strftime);
use Carp;
use DBI;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] [-H <year>] [-t t.csv] [-f f.csv] [-d d.sqlite3] aliyah.xml festival.xml output-dir
    -h        Display usage information.
    -H <year> Start with hebrew year <year> (default this year)
    -t t.csv  Dump triennial readings to comma separated values
    -f f.csv  Dump full kriyah readings to comma separated values
    -d DBFILE Write state to SQLite3 file 
";

my(%opts);
Getopt::Std::getopts('hH:c:t:f:d:', \%opts) || croak "$usage\n";
$opts{'h'} && croak "$usage\n";
(@ARGV == 3) || croak "$usage";

my($aliyah_in) = shift;
my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    croak "$outdir: $!\n";
}

$| = 1;
print "Loading XML...";

## load aliyah.xml data to get parshiot
my $axml = XML::Simple::XMLin($aliyah_in);
my $fxml = XML::Simple::XMLin($festival_in);

my %triennial_aliyot;
read_aliyot_metadata($axml, \%triennial_aliyot);

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

print " done.\n";

## load 4 years of hebcal event data
my($hebrew_year);
if ($opts{'H'}) {
    $hebrew_year = $opts{'H'};
} else {
    my($this_year,$this_mon,$this_day) = Date::Calc::Today();
    my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
    $hebrew_year = $hebdate->{'yy'};
    $hebrew_year++ if $hebdate->{"mm"} == 6; # Elul
}

# year I in triennial cycle was 5756
my $year_num = (($hebrew_year - 5756) % 3) + 1;
my $start_year = $hebrew_year - ($year_num - 1);
print "Current Hebrew year $hebrew_year is year $year_num.  3-cycle started at year $start_year.\n";

my($bereshit_idx1,$pattern1,$events1) = get_tri_events($start_year);
my %cycle_option1;
calc_variation_options($axml, \%cycle_option1, $pattern1);

$start_year += 3;
print "\n3-cycle started at year $start_year.\n";
my($bereshit_idx2,$pattern2,$events2) = get_tri_events($start_year);
my %cycle_option2;
calc_variation_options($axml, \%cycle_option2, $pattern2);

my %readings1 = cycle_readings($bereshit_idx1,$events1,\%cycle_option1);
my %readings2 = cycle_readings($bereshit_idx2,$events2,\%cycle_option2);

my %special;
foreach my $yr (($start_year - 3) .. ($start_year + 10))
{
    my(@ev) = Hebcal::invoke_hebcal("./hebcal -H $yr", '', 0);
    special_readings(\@ev);

    # hack for Pinchas
    my @ev2 = Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '', 0);
    special_pinchas(\@ev2);
}

if ($opts{'t'})
{
    my $fn = $opts{'t'};
    open(CSV, ">$fn.$$") || croak "$fn.$$: $!\n";
    print CSV qq{"Date","Parashah","Aliyah","Triennial Reading"\015\012};

    triennial_csv($axml,$events1,$bereshit_idx1,\%readings1);
    triennial_csv($axml,$events2,$bereshit_idx2,\%readings2);

    close(CSV);
    rename("$fn.$$", $fn) || croak "$fn: $!\n";
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
foreach my $h (keys %readings1, "Vezot Haberakhah") {
    foreach my $dt (@{$parashah_date_sql{$h}}) {
	next unless $dt;
	my($year,$month,$day) = split(/-/, $dt);
	my $time = Date::Calc::Date_to_Time($year,$month,$day,12,59,59);
	if ($time >= $NOW) {
	    $next_reading{$h} = $dt;
	    last;
	}
    }
}

# init global vars needed for html
my %seph2ashk = reverse %Hebcal::ashk2seph;

my $REVISION = '$Revision$'; #'
my $html_footer = Hebcal::html_footer_bootstrap(undef, $REVISION, 0);
my $mtime_aliyah = (stat($aliyah_in))[9];
my $mtime_script = (stat($0))[9];
my $MTIME = $mtime_script > $mtime_aliyah ? $mtime_script : $mtime_aliyah;
my $MTIME_FORMATTED = strftime("%d %B %Y", localtime($MTIME));

foreach my $h (keys %readings1, "Vezot Haberakhah")
{
    write_sedra_page($axml,$h,$prev{$h},$next{$h},
		     $readings1{$h},$readings2{$h});
}

write_index_page($axml);

if ($opts{'d'}) {
  $DBH->commit;
  $DBH->disconnect;
  $DBH = undef;
}


exit(0);

sub event_ymd {
  my($evt) = @_;
  my $year = $evt->[$Hebcal::EVT_IDX_YEAR];
  my $month = $evt->[$Hebcal::EVT_IDX_MON] + 1;
  my $day = $evt->[$Hebcal::EVT_IDX_MDAY];
  ($year,$month,$day);
}

sub event_dates_equal {
  my($evt1,$evt2) = @_;
  my($year1,$month1,$day1) = event_ymd($evt1);
  my($year2,$month2,$day2) = event_ymd($evt2);
  $year1 == $year2 && $month1 == $month2 && $day1 == $day2;
}

sub date_format_sql {
  my($year,$month,$day) = @_;
  sprintf("%04d-%02d-%02d", $year, $month, $day);
}

sub date_format_csv {
  my($year,$month,$day) = @_;
  sprintf("%02d-%s-%04d", $day, $Hebcal::MoY_short[$month - 1], $year);
}

sub get_tri_events
{
    my($start) = @_;

    my @events;
    foreach my $cycle (0 .. 3)
    {
	my($yr) = $start + $cycle;
	my @ev = Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '', 0);
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

	my($year,$month,$day) = event_ymd($events->[$i]);
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

    %readings;
}

sub write_index_page
{
    my($parshiot) = @_;

    my $fn = "$outdir/index.html";
    open(OUT1, ">$fn.$$") || croak "$fn.$$: $!\n";

    my $hy0 = $hebrew_year - 1;
    my $hy1 = $hebrew_year + 1;
    my $hy2 = $hebrew_year + 2;
    my $hy3 = $hebrew_year + 3;

    my $xtra_head = <<EOHTML;
<link rel="alternate" type="application/rss+xml" title="RSS" href="index.xml">
<style type="text/css">
#hebcal-sedrot ol { list-style: none }
</style>
EOHTML
;
    print OUT1 Hebcal::html_header_bootstrap("Torah Readings",
				   "/sedrot/",
				   "single single-post",
				   $xtra_head);
    print OUT1 <<EOHTML;
<div class="span9">
<div class="page-header">
<h1>Torah Readings</h1>
</div>
<div class="pagination"><ul>
<li class="disabled"><a href="#">Diaspora</a></li>
<li><a href="/hebcal/?year=$hy0;v=1;month=x;yt=H;s=on;i=off;set=off">$hy0</a></li>
<li><a href="/hebcal/?year=$hebrew_year;v=1;month=x;yt=H;s=on;i=off;set=off">$hebrew_year</a></li>
<li><a href="/hebcal/?year=$hy1;v=1;month=x;yt=H;s=on;i=off;set=off">$hy1</a></li>
<li><a href="/hebcal/?year=$hy2;v=1;month=x;yt=H;s=on;i=off;set=off">$hy2</a></li>
<li><a href="/hebcal/?year=$hy3;v=1;month=x;yt=H;s=on;i=off;set=off">$hy3</a></li>
</ul></div>
<div class="pagination"><ul>
<li class="disabled"><a href="#">Israel</a></li>
<li><a href="/hebcal/?year=$hy0;v=1;month=x;yt=H;s=on;i=on;set=off">$hy0</a></li>
<li><a href="/hebcal/?year=$hebrew_year;v=1;month=x;yt=H;s=on;i=on;set=off">$hebrew_year</a></li>
<li><a href="/hebcal/?year=$hy1;v=1;month=x;yt=H;s=on;i=on;set=off">$hy1</a></li>
<li><a href="/hebcal/?year=$hy2;v=1;month=x;yt=H;s=on;i=on;set=off">$hy2</a></li>
<li><a href="/hebcal/?year=$hy3;v=1;month=x;yt=H;s=on;i=on;set=off">$hy3</a></li>
</ul></div>
<p>Leyning coordinators:
<a title="Can I download the aliyah-by-aliyah breakdown of Torah readings for Shabbat?"
href="/home/48/can-i-download-the-aliyah-by-aliyah-breakdown-of-torah-readings-for-shabbat">download
Parashat ha-Shavua spreadheet</a> with aliyah-by-aliyah breakdowns.</p>
<div id="hebcal-sedrot">
<h3 id="Genesis">Genesis</h3>
<ol>
EOHTML
    ;

    my($prev_book) = 'Genesis';
    foreach my $h (@all_inorder)
    {
	my($book) = $parshiot->{'parsha'}->{$h}->{'verse'};
	$book =~ s/\s+.+$//;

	my($anchor) = lc($h);
	$anchor =~ s/[^\w]//g;

	print OUT1 "</ol>\n<h3 id=\"$book\">$book</h3>\n<ol>\n"
	    if ($prev_book ne $book);
	$prev_book = $book;

	print OUT1 qq{<li><a id="$anchor" },
	qq{href="$anchor">Parashat $h</a>};
	if ($next_reading{$h}) {
	    print OUT1 " - <small>", date_sql_to_dd_MMM_yyyy($next_reading{$h}),
		"</small>";
	}
	print OUT1 qq{\n};
    }

    print OUT1 "</ol>\n<h3 id=\"DoubledParshiyot\">Doubled Parshiyot</h3>\n<ol>\n";

    foreach my $h (@combined)
    {
	my($anchor) = lc($h);
	$anchor =~ s/[^\w]//g;

	print OUT1 qq{<li><a id="$anchor" },
	qq{href="$anchor">Parashat $h</a>};
	if ($next_reading{$h}) {
	    print OUT1 " - <small>", date_sql_to_dd_MMM_yyyy($next_reading{$h}),
		"</small>";
	}
	print OUT1 qq{\n};
    }

    print OUT1 "</ol>\n</div><!-- #hebcal-sedrot -->\n";
    print OUT1 <<EOHTML;
</div><!-- .span9 -->
<div class="span3">
<h4>Torah Reading RSS feeds</h4>
<ul class="nav nav-list">
<li><a href="index.xml"><img src="/i/feed-icon-14x14.png" style="border:none"
alt="View the raw XML source" width="14" height="14"> Parashat ha-Shavua RSS</a>
</ul>
<h4>Advertisement</h4>
<script type="text/javascript"><!--
google_ad_client = "ca-pub-7687563417622459";
/* skyscraper text only */
google_ad_slot = "7666032223";
google_ad_width = 160;
google_ad_height = 600;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>
</div><!-- .span3 -->
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
    my($parshiot,$option,$patterns) = @_;

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

	print "$parashah: $pat ($option->{$parashah})\n";
    }

    1;
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

sub write_sedra_page
{
    my($parshiot,$h,$prev,$next,$tri1,$tri2) = @_;

    my($hebrew,$torah,$haftarah,$haftarah_seph,
       $torah_href,$haftarah_href,$drash_jts,$drash_ou,
       $drash_reform,$drash_torah,$drash_uj,
       $drash_ajr) = get_parashah_info($parshiot,$h);

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

    print OUT2 Hebcal::html_header_bootstrap("$h - Torah Portion - $hebrew",
				   "/sedrot/$anchor",
				   "single single-post",
				   qq{<meta name="description" content="$description">\n},
				   0);

    my @tri_date;
    my @tri_date2;
    if ($h eq 'Vezot Haberakhah')
    {
	$tri_date[1] = $tri_date[2] = $tri_date[3] =
	    "To be read on Simchat Torah.<br>\nSee holiday readings.";
	@tri_date2 = @tri_date;
    }
    else
    {
	foreach (1 .. 3)
	{
	    $tri_date[$_] = (defined $tri1->[$_]) ?
		$tri1->[$_]->[1] : '(read separately)';
	    $tri_date2[$_] = (defined $tri2->[$_]) ?
		$tri2->[$_]->[1] : '(read separately)';
	}
    }

    my $amazon_link2 =
	"http://www.amazon.com/o/ASIN/0899060145/hebcal-20";

    print OUT2 <<EOHTML;
<div class="span10">
<div class="page-header">
<h1 class="entry-title">Parashat $h / <span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>
</div>
$intro_summary
<h3 id="torah">Torah Portion: <a class="outbound"
href="$torah_href"
title="Translation from JPS Tanakh">$torah</a></h3>
<div class="row-fluid">
<div class="span3">
<h4>Full Kriyah</h4>
EOHTML
;

    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$aliyot})
    {
	print OUT2 format_aliyah($aliyah,$h,$torah), "<br>\n";
    }

    print OUT2 "</div><!-- .span3 fk -->\n";

    foreach my $yr (1 .. 3)
    {
	print OUT2 <<EOHTML;
<div class="span3">
<h4>Triennial Year $yr</h4>
<span class="muted">$tri_date[$yr]</span>
EOHTML
;
	print_tri_cell($tri1,$h,$yr,$torah);
	print OUT2 qq{</div><!-- .span3 tri$yr -->\n};
    }

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

    undef $drash_jts;

    my $has_drash = $drash_jts || $drash_ou ||
	$drash_torah || $drash_uj || $drash_ajr;

    if ($has_drash)
    {
	print OUT2 qq{<h3 id="drash">Commentary</h3>\n<ul class="gtl">\n};
    }

    if ($drash_jts)
    {
	print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from JTS"\nhref="$drash_jts">};
	if ($drash_jts =~ /jtsa\.edu/)
	{
	    print OUT2 qq{Jewish\nTheological Seminary</a>\n};
	}
	else
	{
	    print OUT2 qq{Commentary</a>\n};
	}
    }

    if ($drash_ou)
    {
	print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from Orthodox Union"\nhref="$drash_ou">OU\nTorah Insights</a>\n};
    }

    if ($drash_torah)
    {
	print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from Project Genesis"\nhref="$drash_torah">Torah.org</a>\n};
    }

    if ($drash_uj)
    {
	print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from AJULA"\nhref="$drash_uj">American Jewish University</a>\n};
    }

    if ($drash_ajr)
    {
	print OUT2 qq{<li><a class="outbound" title="Parashat $h commentary from AJR"\nhref="$drash_ajr">Academy for Jewish Religion</a>\n};
    }

    if ($has_drash)
    {
	print OUT2 qq{</ul>\n};
    }

    if (defined $parashah_date_sql{$h}) {
	print OUT2 <<EOHTML;
<h3 id="dates">List of Dates</h3>
Parashat $h is read in the Diaspora on:
<ul class="gtl">
EOHTML
	;
	foreach my $dt (@{$parashah_date_sql{$h}}) {
	    next unless $dt;
	    my($year,$month,$day) = split(/-/, $dt);
	    print OUT2 "<li>", format_html_date($year,$month,$day), "\n";
	}
	print OUT2 "</ul>\n";
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

    my $prev_nav = "";
    if ($prev) {
	my $prev_anchor = lc($prev);
	$prev_anchor =~ s/[^\w]//g;
	$prev_nav = qq{<li><a title="Previous Parashah" href="$prev_anchor" rel="prev"><i class="icon-arrow-left"></i> $prev</a></li>};
    }

    my $next_nav = "";
    if ($next) {
	my $next_anchor = lc($next);
	$next_anchor =~ s/[^\w]//g;
	$next_nav = qq{<li><a title="Next Parashah" href="$next_anchor" rel="prev"><i class="icon-arrow-right"></i> $next</a></li>};
    }

    print OUT2 <<EOHTML;
</div><!-- .span10 -->
<div class="span2">
<h4>Torah Readings</h4>
<ul class="nav nav-list">
<li><a href="."><i class="icon-book"></i> Torah Readings</a>
$prev_nav
$next_nav
</ul>
</div><!-- .span2 -->
EOHTML
;
    print OUT2 $html_footer;

    close(OUT2);
    rename("$fn.$$", $fn) || croak "$fn: $!\n";
}

sub format_html_date {
  my($gy,$gm,$gd) = @_;
  $gm =~ s/^0//;
  $gd =~ s/^0//;
  sprintf "<a title=\"%s %d holiday calendar\" href=\"/hebcal/?v=1;year=%d;month=%d" .
    ";s=on;nx=on;mf=on;ss=on;nh=on;vis=on;set=off;tag=sedrot#hebcal-results\">%02d %s %d</a>",
    $Hebcal::MoY_long{$gm}, $gy,
    $gy, $gm,
    $gd, $Hebcal::MoY_long{$gm}, $gy;
}

sub print_tri_cell
{
    my($triennial,$h,$yr,$torah) = @_;

    if ($h eq 'Vezot Haberakhah')
    {
	print OUT2 "&nbsp;\n";
	return;
    }
    elsif (! defined $triennial->[$yr])
    {
	my($p1,$p2) = split(/-/, $h);

	print OUT2 "Read separately.  See:\n<ul>\n";

	my($anchor) = lc($p1);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor\">$p1</a>\n";

	$anchor = lc($p2);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor\">$p2</a>\n";
	print OUT2 "</ul>\n";
	return;
    }
    elsif ($triennial->[$yr]->[2] ne $h)
    {
	my($h_combined) = $triennial->[$yr]->[2];
	my($p1,$p2) = split(/-/, $h_combined);

	my($other) = ($p1 eq $h) ? $p2 : $p1;

	print OUT2 "Read together with<br>\nParashat $other.<br>\n";

	my($anchor) = lc($h_combined);
	$anchor =~ s/[^\w]//g;
	print OUT2 "See <a href=\"$anchor\">$h_combined</a>\n";
	return;
    }

    croak "no aliyot array for $h (year $yr)"
	unless defined $triennial->[$yr]->[0];

    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$triennial->[$yr]->[0]})
    {
	print OUT2 format_aliyah($aliyah,$h,$torah), "<br>\n";
    }
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
	$info .= "<small>(" . $aliyah->{'numverses'} .
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
    my($torah_href,$haftarah_href,$drash1);
    my $drash1_auto = 1;
    my $drash2 = '';
    my $drash2_auto = 1;
    my $drash3 = '';
    my $drash_uj = '';
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
	foreach my $l (@{$links})
	{
	    if ($l->{'rel'} eq 'drash')
	    {
		$drash1 = $l->{'href'};
		$drash1_auto = $l->{'auto'} if defined $l->{'auto'};
	    }
	    elsif ($l->{'rel'} eq 'drash2')
	    {
		$drash2 = $l->{'href'};
		$drash2_auto = $l->{'auto'} if defined $l->{'auto'};
	    }
	    elsif ($l->{'rel'} eq 'drash3')
	    {
		$drash3 = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'drash4')
	    {
		$drash_uj = $l->{'href'};
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
	    if ($l->{'rel'} eq 'drash')
	    {
		$drash1 = $l->{'href'};
		$drash1_auto = $l->{'auto'} if defined $l->{'auto'};
	    }
	    elsif ($l->{'rel'} eq 'drash2')
	    {
		$drash2 = $l->{'href'};
		$drash2_auto = $l->{'auto'} if defined $l->{'auto'};
	    }
	    elsif ($l->{'rel'} eq 'drash3')
	    {
		$drash3 = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'drash4')
	    {
		$drash_uj = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'torah')
	    {
		$torah_href = $l->{'href'};
	    }
	}

	$haftarah_href = $torah_href;
	$haftarah_href =~ s/.shtml$/_haft.shtml/;
    }

    if ($drash1 =~ m,/\d\d\d\d/, && $drash1_auto) {
	if (defined $parashah_time{$h} && $parashah_time{$h} < $saturday) {
	    $drash1 =~ s,/\d\d\d\d/,/$hebrew_year/,;
	}
    }

    if ($drash2 =~ m,/\d\d\d\d/, && $drash2_auto &&
	defined $parashah_time{$h} && $parashah_time{$h} < $saturday)
    {
	$drash2 =~ s,/\d\d\d\d/,/$hebrew_year/,;
	if ($hebrew_year =~ /^\d\d(\d\d)$/) {
	    my $last2 = $1;
	    $drash2 =~ s/\d\d\.htm$/$last2.htm/;
	}
    }

    # urj site still broken. :-(
    my $drash4 = '';

    my $anchor = lc($h);
    $anchor =~ s/[^\w]//g;
    my $drash_ajr = "http://ajrsem.org/$anchor";
    if (defined $parashah_time{$h} && $parashah_time{$h} < $saturday) {
	$drash_ajr .= $hebrew_year;
    } else {
	$drash_ajr .= $hebrew_year - 1;
    }

    ($hebrew,$torah,$haftarah,$haftarah_seph,
     $torah_href,$haftarah_href,$drash1,$drash2,$drash4,$drash3,$drash_uj,
     $drash_ajr);
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
	my($year,$month,$day) = event_ymd($evt);
	my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
	# check to see if it's after the 17th of Tammuz
	if ($hebdate->{"mm"} > 4
	    || ($hebdate->{"mm"} == 4 && $hebdate->{"dd"} > 17)) {
	    my $dt = date_format_sql($year, $month, $day);
	    $special{$dt}->{"H"} = "Jeremiah 1:1 - 2:3";
	    $special{$dt}->{"reason"} = "Pinchas occurring after 17 Tammuz";
	}
    }
}

sub special_readings
{
    my($events) = @_;

    for (my $i = 0; $i < @{$events}; $i++) {
	my($year,$month,$day) = event_ymd($events->[$i]);
	my $dt = date_format_sql($year, $month, $day);
	next if defined $special{$dt};
	
	my $dow = Date::Calc::Day_of_Week($year, $month, $day);

	my $h = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $chanukah_day = 0;
	# hack! for Shabbat Rosh Chodesh
	if ($dow == 6 && $h =~ /^Rosh Chodesh/
	    && $events->[$i+1]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Chanukah: (\d) Candles/
	    && $1 > 1
	    && defined $events->[$i+1]
	    && event_dates_equal($events->[$i], $events->[$i+1])) {
	    $h = "Shabbat Rosh Chodesh Chanukah"; # don't set $chanukah_day = 6
	} elsif ($dow == 6 && $h =~ /^Rosh Chodesh/
	    && $events->[$i+1]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Shabbat HaChodesh/
	    && defined $events->[$i+1]
	    && event_dates_equal($events->[$i], $events->[$i+1])) {
	    $h = "Shabbat HaChodesh (on Rosh Chodesh)";
	} elsif ($dow == 6 && $h =~ /^Rosh Chodesh/) {
	    $h = 'Shabbat Rosh Chodesh';
	} elsif ($dow == 7 && $h =~ /^Rosh Chodesh/) {
	    # even worse hack!
	    $h = 'Shabbat Machar Chodesh';
	    my($year0,$month0,$day0) =
		Date::Calc::Add_Delta_Days($year, $month, $day, -1);
	    $dt = date_format_sql($year0, $month0, $day0);
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

# write full kryiyah to CSV & leyning DB
sub csv_parasha_event
{
    my($evt,$h,$parshiot) = @_;

    my($year,$month,$day) = event_ymd($evt);
    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
    csv_parasha_event_inner($h,$year,$month,$day,$parshiot,$aliyot,$DBH);
}

# write all of the aliyot for Shabbat to CSV file.
# if $dbh is defined (for fullkriyah), also write to the leyning DB.
sub csv_parasha_event_inner
{
    my($h,$year,$month,$day,$parshiot,$aliyot,$dbh) = @_;

    my $stime2 = date_format_csv($year, $month, $day);
    my $dt = date_format_sql($year, $month, $day);

    my $verses = $parshiot->{'parsha'}->{$h}->{'verse'};
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
				  $book, $aliyah->{'begin'}, $aliyah->{'end'});
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

    print CSV "\015\012";
}

sub readings_for_current_year
{
    my($parshiot) = @_;

    my $heb_yr = $hebrew_year - 1;

    my $extra_years = 10;
    my @years;
    foreach my $i (0 .. $extra_years)
    {
	my($yr) = $heb_yr + $i;
	my(@ev) = Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '', 0);
	$years[$i] = \@ev;
    }

    if ($opts{'f'}) {
	open(CSV, ">$opts{'f'}.$$") || croak "$opts{'f'}.$$: $!\n";
	print CSV qq{"Date","Parashah","Aliyah","Reading","Verses"\015\012};
    }

    for (my $yr = 0; $yr < $extra_years; $yr++) {
	my @events = @{$years[$yr]};
	for (my $i = 0; $i < @events; $i++) {
	    next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
	    my $h = $1;
	    my($year,$month,$day) = event_ymd($events[$i]);
	    $parashah_date_sql{$h}->[$yr] = date_format_sql($year, $month, $day);
	    $parashah_time{$h} = Time::Local::timelocal
	      (1,0,0,
	       $day,
	       $month - 1,
	       $year - 1900,
	       '','','')
		if $yr == 1;	# second year in array

	    if ($opts{'f'}) {
		csv_parasha_event($events[$i], $h, $parshiot);
	    }
	}
    }

    if ($opts{'f'}) {
	close(CSV);
	rename("$opts{'f'}.$$", $opts{'f'}) || croak "$opts{'f'}: $!\n";
    }
}

sub triennial_csv
{
    my($parshiot,$events,$bereshit_idx,$readings) = @_;

    my $yr = 1;
    for (my $i = $bereshit_idx; $i < @{$events}; $i++)
    {
	if ($events->[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit' &&
	    $i != $bereshit_idx)
	{
	    $yr++;
	    last if ($yr == 4);
	}

	next unless ($events->[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
	my $h = $1;

	my($year,$month,$day) = event_ymd($events->[$i]);
	my $aliyot = $readings->{$h}->[$yr]->[0];
	csv_parasha_event_inner($h,$year,$month,$day,$parshiot,$aliyot,undef);
    }
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
