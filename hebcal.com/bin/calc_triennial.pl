#!/usr/local/bin/perl -w

########################################################################
# Generates the Torah Readings for http://www.hebcal.com/sedrot/
#
# Calculates full kriyah according to standard tikkun
#
# Calculates triennial according to
#   A Complete Triennial System for Reading the Torah
#   http://learn.jtsa.edu/topics/diduknow/responsa/trichart.shtml
#
# $Id$
#
# Copyright (c) 2003  Michael J. Radwin.
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

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use Hebcal;
use Getopt::Std;
use XML::Simple;
use Time::Local;
use POSIX qw(strftime);
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] [-H <year>] aliyah.xml festival.xml output-dir
    -h        Display usage information.
    -H <year> Start with hebrew year <year> (default this year)
    -t t.csv  Dump triennial readings to comma separated values
    -f f.csv  Dump full kriyah readings to comma separated values
";

my(%opts);
getopts('hH:c:t:f:', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 3) || die "$usage";

my($aliyah_in) = shift;
my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

## load 4 years of hebcal event data
my($hebrew_year);
if ($opts{'H'}) {
    $hebrew_year = $opts{'H'};
} else {
    $hebrew_year = `./hebcal -t -x -h | grep -v Omer`;
    chomp($hebrew_year);
    $hebrew_year =~ s/^.+, (\d\d\d\d)/$1/;
}

# year I in triennial cycle was 5756
my $year_num = (($hebrew_year - 5756) % 3) + 1;
my $start_year = $hebrew_year - ($year_num - 1);
print "Current Hebrew year $hebrew_year is year $year_num.  3-cycle started at year $start_year.\n";

my(@events);
foreach my $cycle (0 .. 3)
{
    my($yr) = $start_year + $cycle;
    my(@ev) = Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '', 0);
    push(@events, @ev);
}

my $bereshit_idx;
for (my $i = 0; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit')
    {
	$bereshit_idx = $i;
	last;
    }
}

die "can't find Bereshit for Year I" unless defined $bereshit_idx;

## load aliyah.xml data to get parshiot
my $axml = XMLin($aliyah_in);
my $fxml = XMLin($festival_in);

my(@all_inorder,@combined,%combined,%parsha2id);
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
	$parsha2id{$h} = $num;
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

# determine triennial year patterns
my(%pattern);
for (my $i = $bereshit_idx; $i < @events; $i++)
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

my %cycle_option;
calc_variation_options($axml, \%cycle_option);
my %triennial_aliyot;
read_aliyot_metadata($axml, \%triennial_aliyot);

my %readings;
my $year = 1;
for (my $i = $bereshit_idx; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit' &&
	$i != $bereshit_idx)
    {
	$year++;
	last if ($year == 4);
    }

    next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
    my $h = $1;

    my $month = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
    my $stime = sprintf("%02d %s %04d",
			$events[$i]->[$Hebcal::EVT_IDX_MDAY],
			$Hebcal::MoY_long{$month},
			$events[$i]->[$Hebcal::EVT_IDX_YEAR]);

    if (defined $combined{$h})
    {
	my $variation = $cycle_option{$h} . "." . $year;
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

triennial_csv($axml,$opts{'t'},\@events,$bereshit_idx)
    if $opts{'t'};

my(%parsha_dates);
my(%parsha_time);
my(%parsha_time_prev);
my($saturday) = get_saturday();
readings_for_current_year($axml, \%parsha_dates, \%parsha_time);

# init global vars needed for html
my %seph2ashk = reverse %Hebcal::ashk2seph;
my $html_footer = html_footer($aliyah_in);

foreach my $h (keys %readings)
{
    write_sedra_page($axml,\%parsha_dates,$h,$prev{$h},$next{$h},$readings{$h});
}
{
    my $h = "Vezot Haberakhah";
    write_sedra_page($axml,\%parsha_dates,$h,$prev{$h},$next{$h},$readings{$h});
}

write_index_page($axml,\%parsha_dates);

exit(0);

sub write_index_page
{
    my($parshiot,$read_on) = @_;

    open(OUT1, ">$outdir/index.html") || die "$outdir/index.html: $!\n";

    my $hy1 = $hebrew_year + 1;
    my $hy2 = $hebrew_year + 2;
    my $hy3 = $hebrew_year + 3;

    print OUT1 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Hebcal: Torah Readings</title>
<base href="http://www.hebcal.com/sedrot/" target="_top">
<link rel="stylesheet" href="/style.css" type="text/css">
</head>
<body>
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
Torah Readings
</small></td>
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>
<h1>Torah Readings</h1>
<p>Readings for future years:
<a href="/hebcal/?year=$hy1;v=1;month=x;yt=H;s=on">$hy1</a> -
<a href="/hebcal/?year=$hy2;v=1;month=x;yt=H;s=on">$hy2</a> -
<a href="/hebcal/?year=$hy3;v=1;month=x;yt=H;s=on">$hy3</a></p>
<h3>Genesis</h3>
<dl>
EOHTML
    ;

    my($prev_book) = 'Genesis';
    foreach my $h (@all_inorder)
    {
	my($book) = $parshiot->{'parsha'}->{$h}->{'verse'};
	$book =~ s/\s+.+$//;

	my($anchor) = lc($h);
	$anchor =~ s/[^\w]//g;

	print OUT1 "</dl>\n<h3>$book</h3>\n<dl>\n"
	    if ($prev_book ne $book);
	$prev_book = $book;

	print OUT1 qq{<dt><a name="$anchor" },
	qq{href="$anchor.html">Parashat\n$h</a>\n};
	if (defined $read_on->{$h} && defined $read_on->{$h}->[1])
	{
	    print OUT1 qq{ - <small>$read_on->{$h}->[1]</small>\n};
	}
    }

    print OUT1 "</dl>\n<h3>Doubled Parshiyot</h3>\n<dl>\n";

    foreach my $h (@combined)
    {
	my($anchor) = lc($h);
	$anchor =~ s/[^\w]//g;

	print OUT1 qq{<dt><a name="$anchor" },
	qq{href="$anchor.html">Parashat\n$h</a>\n};
	if (defined $read_on->{$h} && defined $read_on->{$h}->[1])
	{
	    print OUT1 qq{ - <small>$read_on->{$h}->[1]</small>\n};
	}
    }

    print OUT1 "</dl>\n";
    print OUT1 $html_footer;

    close(OUT1);

    1;
}

sub calc_variation_options
{
    my($parshiot,$option) = @_;

    foreach my $parsha (@combined)
    {
	my($p1,$p2) = split(/-/, $parsha);
	my $pat = '';
	foreach my $yr (0 .. 2) {
	    $pat .= $pattern{$p1}->[$yr];
	}

	if ($pat eq 'TTT')
	{
	    $option->{$parsha} = 'all-together';
	}
	else
	{
	    my $vars =
		$parshiot->{'parsha'}->{$parsha}->{'variations'}->{'cycle'};
	    foreach my $cycle (@{$vars}) {
		if ($cycle->{'pattern'} eq $pat) {
		    $option->{$parsha} = $cycle->{'option'};
		    $option->{$p1} = $cycle->{'option'};
		    $option->{$p2} = $cycle->{'option'};
		    last;
		}
	    }

	    die "can't find option for $parsha (pat == $pat)"
		unless defined $option->{$parsha};
	}

	print "$parsha: $pat ($option->{$parsha})\n";
    }

    1;
}

sub read_aliyot_metadata
{
    my($parshiot,$aliyot) = @_;

    # build a lookup table so we don't have to follow num/variation/sameas
    foreach my $parsha (keys %{$parshiot->{'parsha'}}) {
	my $val = $parshiot->{'parsha'}->{$parsha};
	my $yrs = $val->{'triennial'}->{'year'};
	
	foreach my $y (@{$yrs}) {
	    if (defined $y->{'num'}) {
		$aliyot->{$parsha}->{$y->{'num'}} = $y->{'aliyah'};
	    } elsif (defined $y->{'variation'}) {
		if (! defined $y->{'sameas'}) {
		    $aliyot->{$parsha}->{$y->{'variation'}} = $y->{'aliyah'};
		}
	    } else {
		die "strange data for Parashat $parsha";
	    }
	}

	# second pass for sameas
	foreach my $y (@{$yrs}) {
	    if (defined $y->{'variation'} && defined $y->{'sameas'}) {
		my $sameas = $y->{'sameas'};
		die "Bad sameas=$sameas for Parashat $parsha"
		    unless defined $aliyot->{$parsha}->{$sameas};
		$aliyot->{$parsha}->{$y->{'variation'}} =
		    $aliyot->{$parsha}->{$sameas};
	    }
	}
    }

    1;
}

sub write_sedra_page
{
    my($parshiot,$read_on,$h,$prev,$next,$triennial) = @_;

    my($hebrew,$torah,$haftarah,$haftarah_seph,
       $torah_href,$haftarah_href,$drash_jts,$drash_ou,
       $drash_reform,$drash_torah) = get_parsha_info($parshiot,$h);

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

	my $title = "Previous Parsha";
	$prev_link = qq{<a name="prev" href="$prev_anchor"\n} .
	    qq{title="$title">&laquo;&nbsp;$prev</a>};
    }

    my($next_link) = '';
    my($next_anchor);
    if ($next)
    {
	$next_anchor = lc($next);
	$next_anchor =~ s/[^\w]//g;
	$next_anchor .= ".html";

	my $title = "Next Parsha";
	$next_link = qq{<a name="next" href="$next_anchor"\n} .
	    qq{title="$title">$next&nbsp;&raquo;</a>};
    }

    open(OUT2, ">$outdir/$anchor.html") || die "$outdir/$anchor.html: $!\n";

    my $keyword = $h;
    $keyword .= ",$seph2ashk{$h}" if defined $seph2ashk{$h};

    print OUT2 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Torah Readings: $h</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/sedrot/$anchor.html" target="_top">
<meta name="keywords" content="$keyword,parsha,parshat,parashat,parshas,hashavua,hashavuah,leyning,aliya,aliyah,aliyot,torah,haftarah,haftorah,drash">
<link rel="stylesheet" href="/style.css" type="text/css">
EOHTML
;

    print OUT2 qq{<link rel="prev" href="$prev_anchor" title="Parashat $prev">\n}
    	if $prev_anchor;
    print OUT2 qq{<link rel="next" href="$next_anchor" title="Parashat $next">\n}
    	if $next_anchor;

    my @tri_date;
    my $fk_date;
    if ($h eq 'Vezot Haberakhah')
    {
	$tri_date[1] = $tri_date[2] = $tri_date[3] =
	$fk_date =
	    "To be read on Simchat Torah.<br>\nSee holiday readings.";
    }
    else
    {
	foreach (1 .. 3)
	{
	    $tri_date[$_] = (defined $triennial->[$_]) ?
		$triennial->[$_]->[1] : '(read separately)';
	}

	$fk_date = '&nbsp;';
    }

    my($amazon_link) =
	"http://www.amazon.com/exec/obidos/ASIN/0827607121/hebcal-20";

    print OUT2 <<EOHTML;
</head>
<body>
<!--htdig_noindex-->
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/sedrot/">Torah Readings</a> <tt>-&gt;</tt>
$h
</small></td>
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>
<!--/htdig_noindex-->
<br>
<table width="100%">
<tr>
<td align="left" width="15%">
$prev_link
</td>
<td align="center" width="70%">
<h1><a name="top">Parashat $h</a><br><span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>
</td>
<td align="right" width="15%">
$next_link
</td>
</tr>
</table>
<h3>Torah Portion: <a name="torah"
href="$torah_href"
title="Translation from JPS Tanakh">$torah</a></h3>
<a href="$amazon_link"><img
src="/i/0827607121.01.MZZZZZZZ.jpg" width="95" height="140" border="0"
hspace="3" vspace="3"
alt="Etz Hayim: Torah and Commentary" align="right"></a>
&nbsp;
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
<td valign="top">
EOHTML
;

    my $aliyot = $parshiot->{'parsha'}->{$h}->{'fullkriyah'}->{'aliyah'};
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			@{$aliyot})
    {
	my($c1,$v1) = ($aliyah->{'begin'} =~ /^(\d+):(\d+)$/);
	my($c2,$v2) = ($aliyah->{'end'}   =~ /^(\d+):(\d+)$/);
	my($info);
	if ($c1 == $c2) {
	    $info = "$c1:$v1-$v2";
	} else {
	    $info = "$c1:$v1-$c2:$v2";
	}

	if (defined $parsha2id{$h})
	{
	    my $book = lc($torah);
	    $book =~ s/\s+.+$//;

	    my $bid = 0;
	    if ($book eq 'genesis') { $bid = 1; } 
	    elsif ($book eq 'exodus') { $bid = 2; }
	    elsif ($book eq 'leviticus') { $bid = 3; }
	    elsif ($book eq 'numbers') { $bid = 4; }
	    elsif ($book eq 'deuteronomy') { $bid = 5; }

	    $info = qq{<a title="Audio from ORT"\nhref="http://www.bible.ort.org/books/torahd5.asp?action=displaypage&amp;book=$bid&amp;chapter=$c1&amp;verse=$v1&amp;portion=$parsha2id{$h}">$info</a>};
	}

	my($label) = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
	print OUT2 qq{<a name="fk-$label">$label:</a> $info\n};

	if ($aliyah->{'numverses'}) {
	    print OUT2 "<span class=\"tiny\">(",
		$aliyah->{'numverses'}, "&nbsp;p'sukim)</span><br>\n";
	}
    }

    print OUT2 "</td>\n";

    foreach my $yr (1 .. 3)
    {
	print OUT2 "<td valign=\"top\">\n";

	if ($h eq 'Vezot Haberakhah')
	{
	    print OUT2 "&nbsp;</td>\n";
	    next;
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
	    next;
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
	    next;
	}

	die "no aliyot array for $h (year $yr)"
	    unless defined $triennial->[$yr]->[0];

	foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			    @{$triennial->[$yr]->[0]})
	{
	    my($c1,$v1) = ($aliyah->{'begin'} =~ /^(\d+):(\d+)$/);
	    my($c2,$v2) = ($aliyah->{'end'}   =~ /^(\d+):(\d+)$/);
	    my($info);
	    if ($c1 == $c2) {
		$info = "$c1:$v1-$v2";
	    } else {
		$info = "$c1:$v1-$c2:$v2";
	    }

	    if (defined $parsha2id{$h})
	    {
		my $book = lc($torah);
		$book =~ s/\s+.+$//;

		my $bid = 0;
		if ($book eq 'genesis') { $bid = 1; } 
		elsif ($book eq 'exodus') { $bid = 2; }
		elsif ($book eq 'leviticus') { $bid = 3; }
		elsif ($book eq 'numbers') { $bid = 4; }
		elsif ($book eq 'deuteronomy') { $bid = 5; }

		$info = qq{<a title="Audio from ORT"\nhref="http://www.bible.ort.org/books/torahd5.asp?action=displaypage&amp;book=$bid&amp;chapter=$c1&amp;verse=$v1&amp;portion=$parsha2id{$h}">$info</a>};
	    }

	    my($label) = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
	    print OUT2 qq{<a name="tri-$yr-$label">$label:</a> $info<br>\n};
	}
	print OUT2 "</td>\n";
    }

    print OUT2 <<EOHTML;
</tr>
</table>
<h3>Haftarah$ashk: <a name="haftara" href="$haftarah_href"
title="Translation from JPS Tanakh">$haftarah</a>$seph</h3>
EOHTML
;

    print OUT2 <<EOHTML;
<small>NOTE: This site does not yet indicate special maftir or haftarah
when they occur. Always check a luach or consult with your rabbi to
determine if this Shabbat has a special maftir and/or a special
haftarah.</small>
EOHTML
;

    if ($drash_jts || $drash_ou || $drash_reform || $drash_torah)
    {
	print OUT2 qq{<h3><a name="drash">Commentary</a></h3>\n<ul>\n};
    }

    if ($drash_jts)
    {
	print OUT2 qq{<li><a title="Parashat $h commentary from JTS"\nhref="$drash_jts">};
	if ($drash_jts =~ /learn.jtsa.edu/)
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
	print OUT2 qq{<li><a title="Parashat $h commentary from Orthodox Union"\nhref="$drash_ou">OU\nTorah Insights</a>\n};
    }

    if ($drash_reform)
    {
	print OUT2 qq{<li><a title="Parashat $h commentary from Union for Reform Judaism"\nhref="$drash_reform">URJ\nTorat Hayim</a>\n};
    }

    if ($drash_torah)
    {
	print OUT2 qq{<li><a title="Parashat $h commentary from Project Genesis"\nhref="$drash_torah">Torah.org</a>\n};
    }

    if ($drash_jts || $drash_ou || $drash_reform || $drash_torah)
    {
	print OUT2 qq{</ul>\n};
    }

    if (defined $read_on->{$h})
    {
	print OUT2 <<EOHTML;
<h3><a name="dates">List of Dates</a></h3>
Parashat $h is read in the Diaspora on:
<ul>
EOHTML
	;
	foreach my $stime (@{$read_on->{$h}}) {
	    next unless defined $stime;
	    print OUT2 "<li>$stime\n";
	}
	print OUT2 "</ul>\n";
    }
    
    print OUT2 <<EOHTML;
<h3><a name="ref">References</a></h3>
<dl>
<dt><em><a href="$amazon_link">Etz
Hayim: Torah and Commentary</a></em>
<dd>David L. Lieber et. al., Jewish Publication Society, 2001.
<dt><em><a
href="http://learn.jtsa.edu/topics/diduknow/responsa/trichart.shtml">A
Complete Triennial System for Reading the Torah</a></em>
<dd>Committee on Jewish Law and Standards of the Rabbinical Assembly
<dt><em><a href="http://www.bible.ort.org/">Navigating the Bible II</a></em>
<dd>World ORT
</dl>
EOHTML
;

    if ($prev_link || $next_link)
    {
	print OUT2 <<EOHTML;
<p>
<hr noshade size="1"><p>
<table width="100%">
<tr>
<td align="left" width="50%">
$prev_link
</td>
<td align="right" width="50%">
$next_link
</td>
</tr>
</table>
EOHTML
;
    }

    print OUT2 $html_footer;

    close(OUT2);
}

sub get_parsha_info
{
    my($parshiot,$h) = @_;

    my $parashat = "\xD7\xA4\xD7\xA8\xD7\xA9\xD7\xAA";  # UTF-8 for "parashat"

    my($hebrew);
    my($torah,$haftarah,$haftarah_seph);
    my($torah_href,$haftarah_href,$drash1);
    my $drash2 = '';
    my $drash3 = '';
    if ($h =~ /^([^-]+)-(.+)$/ &&
	defined $combined{$1} && defined $combined{$2})
    {
	my($p1,$p2) = ($1,$2);

	# UTF-8 for HEBREW PUNCTUATION MAQAF (U+05BE)
	$hebrew = sprintf("%s %s%s%s",
			  $parashat,
			  $parshiot->{'parsha'}->{$p1}->{'hebrew'},
			  "\xD6\xBE", 
			  $parshiot->{'parsha'}->{$p2}->{'hebrew'});

	my $torah_end = $parshiot->{'parsha'}->{$p2}->{'verse'};
	$torah_end =~ s/^.+\s+(\d+:\d+)\s*$/$1/;

	$torah = $parshiot->{'parsha'}->{$p1}->{'verse'};
	$torah =~ s/\s+\d+:\d+\s*$/ $torah_end/;

	# on doubled parshiot, read only the second Haftarah
	$haftarah = $parshiot->{'parsha'}->{$p2}->{'haftara'};
	$haftarah_seph = $parshiot->{'parsha'}->{$p2}->{'sephardic'};

	my $links = $parshiot->{'parsha'}->{$p2}->{'links'}->{'link'};
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
	    }
	    elsif ($l->{'rel'} eq 'drash2')
	    {
		$drash2 = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'drash3')
	    {
		$drash3 = $l->{'href'};
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
	    }
	    elsif ($l->{'rel'} eq 'drash2')
	    {
		$drash2 = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'drash3')
	    {
		$drash3 = $l->{'href'};
	    }
	    elsif ($l->{'rel'} eq 'torah')
	    {
		$torah_href = $l->{'href'};
	    }
	}

	$haftarah_href = $torah_href;
	$haftarah_href =~ s/.shtml$/_haft.shtml/;
    }

    if ($drash1 =~ m,/\d\d\d\d/,) {
	if (defined $parsha_time{$h} && $parsha_time{$h} < $saturday) {
	    $drash1 =~ s,/\d\d\d\d/,/$hebrew_year/,;
	}
    }

    if ($drash2 =~ m,/\d\d\d\d/, && 
	defined $parsha_time{$h} && $parsha_time{$h} < $saturday)
    {
	$drash2 =~ s,/\d\d\d\d/,/$hebrew_year/,;
	if ($hebrew_year =~ /^\d\d(\d\d)$/) {
	    my $last2 = $1;
	    $drash2 =~ s/\d\d\.htm$/$last2.htm/;
	}
    }

    my $drash4t = (defined $parsha_time{$h} && $parsha_time{$h} < $saturday) ?
	$parsha_time{$h} : $parsha_time_prev{$h};
    my $drash4 = '';
    if ($drash4t)
    {
	$drash4 = "http://urj.org/torah/issue/" .
	    strftime("%y%m%d", localtime($drash4t)) . ".shtml";
    }

    ($hebrew,$torah,$haftarah,$haftarah_seph,
     $torah_href,$haftarah_href,$drash1,$drash2,$drash4,$drash3);
}

sub special_readings
{
    my($events,$maftir,$haftara) = @_;

    for (my $i = 0; $i < @{$events}; $i++) {
	my $h = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	# hack! for Shabbat Rosh Chodesh
	if ($h =~ /^Rosh Chodesh/) {
	    $h = 'Shabbat Rosh Chodesh';
	}
	if (defined $fxml->{'festival'}->{$h}) {
	    my $stime2 = sprintf("%02d-%s-%04d",
				 $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
				 $Hebcal::MoY_short[$events->[$i]->[$Hebcal::EVT_IDX_MON]],
				 $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);
	    if (defined $fxml->{'festival'}->{$h}->{'haftara'}) {
		my $reading = $fxml->{'festival'}->{$h}->{'haftara'};
		$haftara->{$stime2} = "$reading ($h)";
	    }

	    if (defined $fxml->{'festival'}->{$h}->{'kriyah'}->{'aliyah'}) {
		my $a = $fxml->{'festival'}->{$h}->{'kriyah'}->{'aliyah'};
		if (ref($a) eq 'HASH') {
		    if ($a->{'num'} eq 'M') {
			$maftir->{$stime2} = sprintf("%s %s - %s (%s)",
						     $a->{'book'},
						     $a->{'begin'},
						     $a->{'end'},
						     $h);
		    }
		} else {
		    foreach my $aliyah (@{$a}) {
			if ($aliyah->{'num'} eq 'M') {
			    $maftir->{$stime2} = sprintf("%s %s - %s (%s)",
							 $aliyah->{'book'},
							 $aliyah->{'begin'},
							 $aliyah->{'end'},
							 $h);
			}
		    }
		}
	    }
	}
    }

    1;
}

sub readings_for_current_year
{
    my($parshiot,$current,$parsha_time) = @_;

    my $heb_yr = `./hebcal -t -x -h | grep -v Omer`;
    chomp($heb_yr);
    $heb_yr =~ s/^.+, (\d\d\d\d)/$1/;
    $heb_yr--;

    my %special_maftir;
    my %special_haftara;

    my $extra_years = 5;
    my @years;
    foreach my $i (0 .. $extra_years)
    {
	my($yr) = $heb_yr + $i;
	my(@ev) = Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '', 0);
	$years[$i] = \@ev;

	my(@ev2) = Hebcal::invoke_hebcal("./hebcal -H $yr", '', 0);
	special_readings(\@ev2, \%special_maftir, \%special_haftara);
    }

    if ($opts{'f'}) {
	open(CSV, ">$opts{'f'}") || die "$opts{'f'}: $!\n";
	print CSV qq{"Date","Parsha","Aliyah","Reading","Verses"\015\012};
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

	$parsha_time->{$h} = Time::Local::timelocal
	    (1,0,0,
	     $events[$i]->[$Hebcal::EVT_IDX_MDAY],
	     $events[$i]->[$Hebcal::EVT_IDX_MON],
	     $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
	     '','','')
		if $yr == 1;	# second year in array

	$parsha_time_prev{$h} = Time::Local::timelocal
	    (1,0,0,
	     $events[$i]->[$Hebcal::EVT_IDX_MDAY],
	     $events[$i]->[$Hebcal::EVT_IDX_MON],
	     $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
	     '','','')
		if $yr == 0;	# second year in array

	next unless $opts{'f'};

	my $stime2 = sprintf("%02d-%s-%04d",
			     $events[$i]->[$Hebcal::EVT_IDX_MDAY],
			     $Hebcal::MoY_short[$month - 1],
			     $events[$i]->[$Hebcal::EVT_IDX_YEAR]);

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
	    $haft = $parshiot->{'parsha'}->{$p2}->{'haftara'};
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
    }
}

sub triennial_csv
{
    my($parshiot,$fn,$events,$bereshit_idx) = @_;

    open(CSV, ">$fn") || die "$fn: $!\n";
    print CSV qq{"Date","Parsha","Aliyah","Triennial Reading"\015\012};

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
			    @{$readings{$h}->[$year]->[0]})
	{
	    printf CSV
		qq{%s,"%s",%s,"$book %s - %s"\015\012},
		$stime2,
		$h,
		($aliyah->{'num'} eq 'M' ? '"maf"' : $aliyah->{'num'}),
		$aliyah->{'begin'},
		$aliyah->{'end'};
	}

	print CSV "\015\012";
    }

    close(CSV);
}

sub get_saturday
{
    my($now) = time();
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($now);

    ($wday == 6) ? $now + (60 * 60 * 24) :
	$now + ((6 - $wday) * 60 * 60 * 24);
}

sub html_footer
{
    my($aliyah_in) = @_;

    my($rcsrev) = '$Revision$'; #'
    $rcsrev =~ s/\s*\$//g;

    my($mtime) = (stat($aliyah_in))[9];
    my($hhmts) = "Last modified:\n" . localtime($mtime);

    my($copyright) = Hebcal::html_copyright2('',0,undef);
    my($html_footer) = <<EOHTML;
<p>
<hr noshade size="1">
<span class="tiny">$copyright
<br>
$hhmts
($rcsrev)
</span>
</body></html>
EOHTML
;
    $html_footer;
}
