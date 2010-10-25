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
use utf8;
use open ":utf8";
use Hebcal ();
use HebcalGPL ();
use Date::Calc ();
use Getopt::Std ();
use XML::Simple ();
use Time::Local ();
use POSIX qw(strftime);

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] [-H <year>] aliyah.xml festival.xml output-dir
    -h        Display usage information.
    -2        Display two years of triennial on HTML pages
    -H <year> Start with hebrew year <year> (default this year)
    -t t.csv  Dump triennial readings to comma separated values
    -f f.csv  Dump full kriyah readings to comma separated values
";

my(%opts);
Getopt::Std::getopts('hH:c:t:f:2', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 3) || die "$usage";

my($aliyah_in) = shift;
my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
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

my %special_maftir;
my %special_maftir_anode;
my %special_haftara;
foreach my $yr (($start_year - 3) .. ($start_year + 10))
{
    my(@ev) = Hebcal::invoke_hebcal("./hebcal -H $yr", '', 0);
    special_readings(\@ev, \%special_maftir, \%special_maftir_anode,
		     \%special_haftara);
}

if ($opts{'t'})
{
    my $fn = $opts{'t'};
    open(CSV, ">$fn.$$") || die "$fn.$$: $!\n";
    print CSV qq{"Date","Parashah","Aliyah","Triennial Reading"\015\012};

    triennial_csv($axml,$events1,$bereshit_idx1,\%readings1);
    triennial_csv($axml,$events2,$bereshit_idx2,\%readings2);

    close(CSV);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}

my(%parashah_dates);
my(%parashah_stime2);
my(%parashah_time);
my($saturday) = get_saturday();
readings_for_current_year($axml, \%parashah_dates, \%parashah_time);

# init global vars needed for html
my %seph2ashk = reverse %Hebcal::ashk2seph;

my $REVISION = '$Revision$'; #'
my $html_footer = Hebcal::html_footer_new(undef, $REVISION, 0);
my $MTIME = (stat($aliyah_in))[9];
my $MTIME_FORMATTED = strftime("%d %B %Y", localtime($MTIME));

foreach my $h (keys %readings1, "Vezot Haberakhah")
{
    write_sedra_page($axml,\%parashah_dates,$h,$prev{$h},$next{$h},
		     $readings1{$h},$readings2{$h});
}

write_index_page($axml,\%parashah_dates);

exit(0);

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

    die "can't find Bereshit for Year I" unless defined $idx;

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
    my $year = 1;
    for (my $i = $bereshit_idx; $i < @{$events}; $i++)
    {
	if ($events->[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit' &&
	    $i != $bereshit_idx)
	{
	    $year++;
	    last if ($year == 4);
	}

	next unless $events->[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/;
	my $h = $1;

	my $month = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $stime = sprintf("%02d %s %04d",
			    $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			    $Hebcal::MoY_long{$month},
			    $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);

	if (defined $combined{$h})
	{
	    my $variation = $option->{$h} . "." . $year;
	    my $a = $triennial_aliyot{$h}->{$variation};
	    die unless defined $a;
	    $readings{$h}->[$year] = [$a, $stime, $h];
	}
	elsif (defined $triennial_aliyot{$h}->{$year})
	{
	    my $a = $triennial_aliyot{$h}->{$year};
	    die unless defined $a;

	    $readings{$h}->[$year] = [$a, $stime, $h];

	    if ($h =~ /^([^-]+)-(.+)$/ &&
		defined $combined{$1} && defined $combined{$2})
	    {
		$readings{$1}->[$year] = [$a, $stime, $h];
		$readings{$2}->[$year] = [$a, $stime, $h];
	    }
	}
	elsif (defined $triennial_aliyot{$h}->{"Y.$year"})
	{
	    my $a = $triennial_aliyot{$h}->{"Y.$year"};
	    die unless defined $a;

	    $readings{$h}->[$year] = [$a, $stime, $h];

	    if ($h =~ /^([^-]+)-(.+)$/ &&
		defined $combined{$1} && defined $combined{$2})
	    {
		$readings{$1}->[$year] = [$a, $stime, $h];
		$readings{$2}->[$year] = [$a, $stime, $h];
	    }
	}
	else
	{
	    die "can't find aliyot for $h, year $year";
	}
    }

    %readings;
}

sub write_index_page
{
    my($parshiot,$read_on) = @_;

    my $fn = "$outdir/index.html";
    open(OUT1, ">$fn.$$") || die "$fn.$$: $!\n";

    my $hy0 = $hebrew_year - 1;
    my $hy1 = $hebrew_year + 1;
    my $hy2 = $hebrew_year + 2;
    my $hy3 = $hebrew_year + 3;

    my $xtra_head = <<EOHTML;
<style type="text/css">
#hebcal-sedrot ol { list-style: none }
</style>
EOHTML
;
    print OUT1 Hebcal::html_header("Torah Readings",
				   "/sedrot/",
				   "single single-post",
				   $xtra_head);
    print OUT1 <<EOHTML;
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title"><a href="index.xml"><img
src="/i/xml.gif" border="0" alt="View the raw XML source" align="right"
width="36" height="14"></a>
Torah Readings</h1>
<div class="entry-meta">
<span class="meta-prep meta-prep-author">Last updated on</span> <span class="entry-date">$MTIME_FORMATTED</span>
</div><!-- .entry-meta -->
<div class="entry-content">
<p>Readings for:
<a href="/hebcal/?year=$hy0;v=1;month=x;yt=H;s=on">$hy0</a> -
$hebrew_year -
<a href="/hebcal/?year=$hy1;v=1;month=x;yt=H;s=on">$hy1</a> -
<a href="/hebcal/?year=$hy2;v=1;month=x;yt=H;s=on">$hy2</a> -
<a href="/hebcal/?year=$hy3;v=1;month=x;yt=H;s=on">$hy3</a></p>
<p>Leyning coordinators:
<a title="Can I download the aliyah-by-aliyah breakdown of Torah readings for Shabbat?"
href="/home/48/can-i-download-the-aliyah-by-aliyah-breakdown-of-torah-readings-for-shabbat">download
Parashat ha-Shavua spreadheet</a> with aliyah-by-aliyah breakdowns.</p>
<div id="hebcal-sedrot">
<h3>Genesis</h3>
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

	print OUT1 "</ol>\n<h3>$book</h3>\n<ol>\n"
	    if ($prev_book ne $book);
	$prev_book = $book;

	print OUT1 qq{<li><a name="$anchor" },
	qq{href="$anchor.html">Parashat $h</a>};
	if (defined $read_on->{$h} && defined $read_on->{$h}->[1])
	{
	    print OUT1 qq{ - <small>$read_on->{$h}->[1]</small>};
	}
	print OUT1 qq{\n};
    }

    print OUT1 "</ol>\n<h3>Doubled Parshiyot</h3>\n<ol>\n";

    foreach my $h (@combined)
    {
	my($anchor) = lc($h);
	$anchor =~ s/[^\w]//g;

	print OUT1 qq{<li><a name="$anchor" },
	qq{href="$anchor.html">Parashat $h</a>};
	if (defined $read_on->{$h} && defined $read_on->{$h}->[1])
	{
	    print OUT1 qq{ - <small>$read_on->{$h}->[1]</small>};
	}
	print OUT1 qq{\n};
    }

    print OUT1 "</ol>\n</div><!-- #hebcal-sedrot -->\n";
    print OUT1 <<EOHTML;
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOHTML
;
    print OUT1 $html_footer;

    close(OUT1);
    rename("$fn.$$", $fn) || die "$fn: $!\n";

    1;
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

	    die "can't find option for $parashah (pat == $pat)"
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
		die "strange data for Parashat $parashah";
	    }
	}

	# second pass for sameas
	foreach my $y (@{$yrs}) {
	    if (defined $y->{'variation'} && defined $y->{'sameas'}) {
		my $sameas = $y->{'sameas'};
		die "Bad sameas=$sameas for Parashat $parashah"
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
    my($parshiot,$read_on,$h,$prev,$next,$tri1,$tri2) = @_;

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

    my($anchor) = lc($h);
    $anchor =~ s/[^\w]//g;

    my($prev_link) = '';
    my($prev_anchor);
    if ($prev)
    {
	$prev_anchor = lc($prev);
	$prev_anchor =~ s/[^\w]//g;
	$prev_anchor .= ".html";

	my $title = "Previous Parashah";
	$prev_link = <<EOHTML
<div class="nav-previous"><a title="$title" href="$prev_anchor" rel="prev"><span class="meta-nav">&larr;</span> $prev</a></div>
EOHTML
;
    }

    my($next_link) = '';
    my($next_anchor);
    if ($next)
    {
	$next_anchor = lc($next);
	$next_anchor =~ s/[^\w]//g;
	$next_anchor .= ".html";

	my $title = "Next Parashah";
	$next_link = <<EOHTML
<div class="nav-next"><a title="$title" href="$next_anchor" rel="next">$next <span class="meta-nav">&rarr;</span></a></div>
EOHTML
;
    }

    my $fn = "$outdir/$anchor.html";
    open(OUT2, ">$fn.$$") || die "$fn.$$: $!\n";

    my $keyword = $h;
    $keyword .= ",$seph2ashk{$h}" if defined $seph2ashk{$h};

    print OUT2 Hebcal::html_header("Parashat $h ($torah)",
				   "/sedrot/$anchor.html",
				   "single single-post");

    my @tri_date;
    my @tri_date2;
    my $fk_date;
    if ($h eq 'Vezot Haberakhah')
    {
	$tri_date[1] = $tri_date[2] = $tri_date[3] =
	$fk_date =
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

	$fk_date = '&nbsp;';
    }

    my $amazon_link1 =
	"http://www.amazon.com/o/ASIN/0827607121/hebcal-20";
    my $amazon_link2 =
	"http://www.amazon.com/o/ASIN/0899060145/hebcal-20";

    print OUT2 <<EOHTML;
<div id="container" class="single-attachment">
<div id="content" role="main">
<div id="nav-above" class="navigation">
$prev_link
$next_link
</div><!-- #nav-above -->
<div class="page type-page hentry">
<h1 class="entry-title">Parashat $h / <span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>
<div class="entry-meta">
<span class="meta-prep meta-prep-author">Last updated on</span> <span class="entry-date">$MTIME_FORMATTED</span>
</div><!-- .entry-meta -->
<div class="entry-content">
<h3 id="torah">Torah Portion: <a class="outbound"
href="$torah_href"
title="Translation from JPS Tanakh">$torah</a></h3>
<table border="1" cellpadding="5">
<tr>
<td align="center"><b>Full Kriyah</b>
<br><small>$fk_date</small>
</td>
<td align="center"><b>Triennial Year I</b>
<br><small>$tri_date[1]</small>
</td>
<td align="center"><b>Triennial Year II</b>
<br><small>$tri_date[2]</small>
</td>
<td align="center"><b>Triennial Year III</b>
<br><small>$tri_date[3]</small>
</td>
</tr>
<tr>
EOHTML
;

    if ($opts{'2'})
    {
	print OUT2 qq{<td valign="top" rowspan="3">\n};
    }
    else
    {
	print OUT2 qq{<td valign="top">\n};
    }

    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$aliyot})
    {
	print OUT2 format_aliyah($aliyah,$h,$torah), "<br>\n";
    }

    print OUT2 "</td>\n";

    foreach my $yr (1 .. 3)
    {
	print_tri_cell($tri1,$h,$yr,$torah);
    }

    print OUT2 "</tr>\n";

    if (defined $parashah_stime2{$h}) {
	my %sp_dates;
	foreach my $stime2 (@{$parashah_stime2{$h}}) {
	    if (defined $stime2 && defined $special_maftir_anode{$stime2}) {
		my $fest = $special_maftir_anode{$stime2}->[1];
		push(@{$sp_dates{$fest}}, $stime2);
	    }
	}

	if (keys %sp_dates) {
	    my $count = 0;
	    print OUT2 qq{<tr><td valign="top" colspan="4">\n};
	    foreach my $fest (sort keys %sp_dates) {
		my $aliyah = $special_maftir_anode{$sp_dates{$fest}->[0]}->[0];
		my $info = format_aliyah($aliyah,
					 $all_inorder[$aliyah->{'parsha'}-1],
					 undef,1);
		print OUT2 "<br>\n" if $count++;
		print OUT2 <<EOHTML;
On <b>$fest</b><br>
$info
<ul class="tiny gtl">
EOHTML
;
		foreach my $stime2 (@{$sp_dates{$fest}}) {
		    $stime2 =~ s/-/ /g;
		    print OUT2 "<li>$stime2\n";
		}

		print OUT2 "</ul>\n";
	    }
	    print OUT2 "</td></tr>\n";
	}
    }

    if ($opts{'2'})
    {
	print OUT2 <<EOHTML;
<tr>
<td align="center"><b>Triennial Year I</b>
<br><small>$tri_date2[1]</small>
</td>
<td align="center"><b>Triennial Year II</b>
<br><small>$tri_date2[2]</small>
</td>
<td align="center"><b>Triennial Year III</b>
<br><small>$tri_date2[3]</small>
</td>
</tr>
EOHTML
;

	foreach my $yr (1 .. 3)
	{
	    print_tri_cell($tri2,$h,$yr,$torah);
	}
    }

    print OUT2 <<EOHTML;
</table>
<h3 id="haftarah">Haftarah$ashk: <a class="outbound"
href="$haftarah_href"
title="Translation from JPS Tanakh">$haftarah</a>$seph</h3>
EOHTML
;

    if (defined $parashah_stime2{$h}) {
	my $did_special;
	foreach my $stime2 (@{$parashah_stime2{$h}}) {
	    if (defined $stime2 && defined $special_haftara{$stime2}) {
		if (!$did_special) {
		    print OUT2 <<EOHTML;
When Parashat $h coincides with a special Shabbat, we read a
different Haftarah:
<ul class="gtl">
EOHTML
;
		    $did_special = 1;
		}
		if ($special_haftara{$stime2} =~ /^(.+) \((.+)\)$/) {
		    my $sp_verse = $1;
		    my $sp_festival = $2;
		    my $sp_href = $fxml->{'festival'}->{$sp_festival}->{'kriyah'}->{'haft'}->{'href'};
		    $stime2 =~ s/-/ /g;
		    print OUT2 <<EOHTML;
<li>$stime2 (<b>$sp_festival</b> / <a class="outbound"
title="Special Haftara for $sp_festival"
href="$sp_href">$sp_verse</a>)
EOHTML
;
		}
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

    if (defined $read_on->{$h})
    {
	print OUT2 <<EOHTML;
<h3 id="dates">List of Dates</h3>
Parashat $h is read in the Diaspora on:
<ul class="gtl">
EOHTML
	;
	foreach my $stime (@{$read_on->{$h}}) {
	    next unless defined $stime;
	    print OUT2 "<li>$stime\n";
	}
	print OUT2 "</ul>\n";
    }
    
    print OUT2 <<EOHTML;
<h3 id="ref">References</h3>
<dl>
<dt><a title="The Chumash: The Stone Edition (Artscroll Series)"
class="amzn" id="chumash-1"
href="$amazon_link2"><img
src="/i/0899060145.01.87x110.jpg" width="87" height="110" border="0"
hspace="3" vspace="3" align="right"
alt="The Chumash: The Stone Edition (Artscroll Series)"></a>
<em><a class="amzn" id="chumash-2"
href="$amazon_link2">The
Chumash: The Stone Edition (Artscroll Series)</a></em>
<dd>Nosson Scherman, Mesorah Publications, 1993
<dt><em><a class="outbound"
href="http://www.jtsa.edu/prebuilt/parashaharchives/triennial.shtml">A
Complete Triennial System for Reading the Torah</a></em>
<dd>Committee on Jewish Law and Standards of the Rabbinical Assembly
<dt><a title="Etz Hayim: Torah and Commentary"
class="amzn" id="etz-hayim-1"
href="$amazon_link1"><img
src="/i/0827607121.01.75x110.jpg" width="75" height="110" border="0"
hspace="3" vspace="3" align="right"
alt="Etz Hayim: Torah and Commentary"></a>
<em><a class="amzn" id="etz-hayim-2"
href="$amazon_link1">Etz
Hayim: Torah and Commentary</a></em>
<dd>David L. Lieber et. al., Jewish Publication Society, 2001
<dt><em><a class="outbound" href="http://www.bible.ort.org/">Navigating the Bible II</a></em>
<dd>World ORT
</dl>
EOHTML
;

    if ($prev_link || $next_link)
    {
	print OUT2 <<EOHTML;
<div id="nav-below" class="navigation">
$prev_link
$next_link
</div><!-- #nav-below -->
EOHTML
;
    }

    print OUT2 <<EOHTML;
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOHTML
;
    print OUT2 $html_footer;

    close(OUT2);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}


sub print_tri_cell
{
    my($triennial,$h,$yr,$torah) = @_;

    print OUT2 "<td valign=\"top\">\n";
    print OUT2 "<!-- tri $yr -->\n";

    if ($h eq 'Vezot Haberakhah')
    {
	print OUT2 "&nbsp;</td>\n";
	return;
    }
    elsif (! defined $triennial->[$yr])
    {
	my($p1,$p2) = split(/-/, $h);

	print OUT2 "Read separately.  See:\n<ul>\n";

	my($anchor) = lc($p1);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor.html\">$p1</a>\n";

	$anchor = lc($p2);
	$anchor =~ s/[^\w]//g;
	print OUT2 "<li><a href=\"$anchor.html\">$p2</a>\n";
	print OUT2 "</ul>\n";

	print OUT2 "</td>\n";
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
	print OUT2 "See <a href=\"$anchor.html\">$h_combined</a>\n";

	print OUT2 "</td>\n";
	return;
    }

    die "no aliyot array for $h (year $yr)"
	unless defined $triennial->[$yr]->[0];

    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$triennial->[$yr]->[0]})
    {
	print OUT2 format_aliyah($aliyah,$h,$torah), "<br>\n";
    }
    print OUT2 "</td>\n";
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
	my $book = lc($torah);

	my $bid = 0;
	if ($book eq 'genesis') { $bid = 1; } 
	elsif ($book eq 'exodus') { $bid = 2; }
	elsif ($book eq 'leviticus') { $bid = 3; }
	elsif ($book eq 'numbers') { $bid = 4; }
	elsif ($book eq 'deuteronomy') { $bid = 5; }

	$info = qq{<a class="outbound" title="Audio from ORT"\nhref="http://www.bible.ort.org/books/torahd5.asp?action=displaypage&amp;book=$bid&amp;chapter=$c1&amp;verse=$v1&amp;portion=$parashah2id{$h}">$info</a>};
    }

    my $label = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    $info = "$label: $info\n";

    if ($aliyah->{'numverses'}) {
	$info .= "<span class=\"tiny\">(" . $aliyah->{'numverses'} .
	    "&nbsp;p'sukim)</span>\n";
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

sub get_special_maftir
{
    my($h) = @_;

    if (defined $fxml->{'festival'}->{$h}) {
	if (defined $fxml->{'festival'}->{$h}->{'kriyah'}->{'aliyah'}) {
	    my $a = $fxml->{'festival'}->{$h}->{'kriyah'}->{'aliyah'};
	    if (ref($a) eq 'HASH') {
		if ($a->{'num'} eq 'M') {
		    return $a;
		}
	    } else {
		foreach my $aliyah (@{$a}) {
		    if ($aliyah->{'num'} eq 'M') {
			return $aliyah;
		    }
		}
	    }
	}
    }

    return undef;
}

sub special_readings
{
    my($events,$maftir,$maftir_anode,$haftara) = @_;

    for (my $i = 0; $i < @{$events}; $i++) {
	my $year = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my $month = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $day = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my $stime2 = sprintf("%02d-%s-%04d",
			     $day, $Hebcal::MoY_short[$month - 1], $year);

	next if defined $haftara->{$stime2};
	next if defined $maftir->{$stime2};

	my $dow = Date::Calc::Day_of_Week($year, $month, $day);

	my $h = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $chanukah_day = 0;
	# hack! for Shabbat Rosh Chodesh
	if ($dow == 6 && $h =~ /^Rosh Chodesh/
	    && defined $events->[$i+1]
	    && $events->[$i+1]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Chanukah: (\d) Candles/
	    && $1 > 1
	    && $year == $events->[$i+1]->[$Hebcal::EVT_IDX_YEAR]
	    && $month == $events->[$i+1]->[$Hebcal::EVT_IDX_MON] + 1
	    && $day == $events->[$i+1]->[$Hebcal::EVT_IDX_MDAY]) {
	    $chanukah_day = $1 - 1;
	    $h = "Shabbat Rosh Chodesh Chanukah";
	} elsif ($dow == 6 && $h =~ /^Rosh Chodesh/) {
	    $h = 'Shabbat Rosh Chodesh';
	} elsif ($dow == 7 && $h =~ /^Rosh Chodesh/) {
	    # even worse hack!
	    $h = 'Shabbat Machar Chodesh';
	    ($year,$month,$day) =
		Date::Calc::Add_Delta_Days($year, $month, $day, -1);
	    $stime2 = sprintf("%02d-%s-%04d",
			      $day, $Hebcal::MoY_short[$month - 1], $year);
	    next if defined $haftara->{$stime2};
	    next if defined $maftir->{$stime2};
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
		$haftara->{$stime2} = "$haft ($h)";
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
		$a = get_special_maftir($h);
	    }
	    if ($a) {
		if ($chanukah_day) {
		    $h .= " - Day $chanukah_day";
		}
		$maftir->{$stime2} = sprintf("%s %s - %s (%s)",
					     $a->{'book'},
					     $a->{'begin'},
					     $a->{'end'},
					     $h);
		$maftir_anode->{$stime2} = [$a,$h];
	    }
	}
    }

    1;
}

sub readings_for_current_year
{
    my($parshiot,$current,$parashah_time) = @_;

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
	open(CSV, ">$opts{'f'}.$$") || die "$opts{'f'}.$$: $!\n";
	print CSV qq{"Date","Parashah","Aliyah","Reading","Verses"\015\012};
    }

    for (my $yr = 0; $yr < $extra_years; $yr++)
    {
    my @events = @{$years[$yr]};

    for (my $i = 0; $i < @events; $i++)
    {
	next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
	my $h = $1;

	my $month = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;

	my $stime = sprintf("%02d %s %04d",
			    $events[$i]->[$Hebcal::EVT_IDX_MDAY],
			    $Hebcal::MoY_long{$month},
			    $events[$i]->[$Hebcal::EVT_IDX_YEAR]);

	$current->{$h}->[$yr] = $stime;

	$parashah_time->{$h} = Time::Local::timelocal
	    (1,0,0,
	     $events[$i]->[$Hebcal::EVT_IDX_MDAY],
	     $events[$i]->[$Hebcal::EVT_IDX_MON],
	     $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
	     '','','')
		if $yr == 1;	# second year in array

	next unless $opts{'f'};

	my $stime2 = sprintf("%02d-%s-%04d",
			     $events[$i]->[$Hebcal::EVT_IDX_MDAY],
			     $Hebcal::MoY_short[$month - 1],
			     $events[$i]->[$Hebcal::EVT_IDX_YEAR]);

	$parashah_stime2{$h}->[$yr] = $stime2;

	my($book) = $parshiot->{'parsha'}->{$h}->{'verse'};
	$book =~ s/\s+.+$//;

	my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
	foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			    @{$aliyot})
	{
	    next if $aliyah->{'num'} eq 'M' && defined $special_maftir{$stime2};
	    printf CSV
		qq{%s,"%s",%s,"$book %s - %s",%s\015\012},
		$stime2,
		$h,
		($aliyah->{'num'} eq 'M' ? '"maf"' : $aliyah->{'num'}),
		$aliyah->{'begin'},
		$aliyah->{'end'},
		$aliyah->{'numverses'};
	}

	if (defined $special_maftir{$stime2}) {
	    printf CSV
		qq{%s,"%s","%s","%s",\015\012},
		$stime2,
		$h,
		'maf',
		$special_maftir{$stime2};
	}

	my $haft = (defined $special_haftara{$stime2}) ?
	    $special_haftara{$stime2} : $parshiot->{'parsha'}->{$h}->{'haftara'};

	if (! defined $haft && $h =~ /^([^-]+)-(.+)$/ &&
	    defined $combined{$1} && defined $combined{$2})
	{
	    my($p1,$p2) = ($1,$2);
	    my $ph = ($p1 eq 'Nitzavim') ? $p1 : $p2;
	    $haft = $parshiot->{'parsha'}->{$ph}->{'haftara'};
	}

	printf CSV
	    qq{%s,"%s","%s","%s",\015\012},
	    $stime2,
	    $h,
	    'Haftara',
	    $haft;

	print CSV "\015\012";
    }
    }

    if ($opts{'f'}) {
	close(CSV);
	rename("$opts{'f'}.$$", $opts{'f'}) || die "$opts{'f'}: $!\n";
    }
}

sub triennial_csv
{
    my($parshiot,$events,$bereshit_idx,$readings) = @_;

    my $year = 1;
    for (my $i = $bereshit_idx; $i < @{$events}; $i++)
    {
	if ($events->[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit' &&
	    $i != $bereshit_idx)
	{
	    $year++;
	    last if ($year == 4);
	}

	next unless ($events->[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
	my $h = $1;

	my $month = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $stime2 = sprintf("%02d-%s-%04d",
			     $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			     $Hebcal::MoY_short[$month - 1],
			     $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);

	my($book) = $parshiot->{'parsha'}->{$h}->{'verse'};
	$book =~ s/\s+.+$//;

	foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			    @{$readings->{$h}->[$year]->[0]})
	{
	    next if $aliyah->{'num'} eq 'M' && defined $special_maftir{$stime2};
	    printf CSV
		qq{%s,"%s",%s,"$book %s - %s"\015\012},
		$stime2,
		$h,
		($aliyah->{'num'} eq 'M' ? '"maf"' : $aliyah->{'num'}),
		$aliyah->{'begin'},
		$aliyah->{'end'};
	}

	if (defined $special_maftir{$stime2}) {
	    printf CSV
		qq{%s,"%s","%s","%s",\015\012},
		$stime2,
		$h,
		'maf',
		$special_maftir{$stime2};
	}

	my $haft = (defined $special_haftara{$stime2}) ?
	    $special_haftara{$stime2} : $parshiot->{'parsha'}->{$h}->{'haftara'};

	if (! defined $haft && $h =~ /^([^-]+)-(.+)$/ &&
	    defined $combined{$1} && defined $combined{$2})
	{
	    my($p1,$p2) = ($1,$2);
	    my $ph = ($p1 eq 'Nitzavim') ? $p1 : $p2;
	    $haft = $parshiot->{'parsha'}->{$ph}->{'haftara'};
	}

	printf CSV
	    qq{%s,"%s","%s","%s",\015\012},
	    $stime2,
	    $h,
	    'Haftara',
	    $haft;

	print CSV "\015\012";
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
