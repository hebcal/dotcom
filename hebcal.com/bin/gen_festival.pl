#!/usr/local/bin/perl -w

########################################################################
# Generates the festival pages for http://www.hebcal.com/holidays/
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

use Getopt::Std;
use XML::Simple;
use Hebcal;
use strict;

$0 =~ s,.*/,,;  # basename
my($usage) = "usage: $0 [-h] festival.xml output-dir
    -h        Display usage information.
    -f f.csv  Dump full kriyah readings to comma separated values
";

my(%opts);
getopts('hf:', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

my $fxml = XMLin($festival_in);

if ($opts{'f'}) {
    open(CSV, ">$opts{'f'}") || die "$opts{'f'}: $!\n";
    print CSV qq{"Date","Parsha","Aliyah","Reading","Verses"\015\012};
}

my $html_footer = html_footer($festival_in);

my @FESTIVALS;
my %SUBFESTIVALS;
foreach my $node (@{$fxml->{'groups'}->{'group'}})
{
    my $f;
    if (ref($node) eq 'HASH') {
	$f = $node->{'content'};
	$f =~ s/^\s+//;
	$f =~ s/\s+$//;
	if (defined $node->{'li'}) {
	    $SUBFESTIVALS{$f} = $node->{'li'};
	} else {
	    $SUBFESTIVALS{$f} = [ $f ];
	}
    } else {
	$f = $node;
	$f =~ s/^\s+//;
	$f =~ s/\s+$//;
	$SUBFESTIVALS{$f} = [ $f ];
    }

    push(@FESTIVALS, $f);
}

my(%PREV,%NEXT);
{
    my $f2;
    foreach my $f (@FESTIVALS)
    {
	$PREV{$f} = $f2;
	$f2 = $f;
    }

    $f2 = undef;
    foreach my $f (reverse @FESTIVALS)
    {
	$NEXT{$f} = $f2;
	$f2 = $f;
    }
}

my %OBSERVED;
holidays_observed(\%OBSERVED);

foreach my $f (@FESTIVALS)
{
    write_festival_page($fxml,$f);
    write_csv($fxml,$f) if $opts{'f'};
}

if ($opts{'f'}) {
    close(CSV);
}

write_index_page($fxml);

exit(0);

sub trim
{
    my($value) = @_;

    if ($value) {
	local($/) = undef;
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
	$value =~ s/\n/ /g;
	$value =~ s/\s+/ /g;
    }

    $value;
}

sub get_var
{
    my($festivals,$f,$name) = @_;

    my $sub = $SUBFESTIVALS{$f}->[0];
    my $value = $festivals->{'festival'}->{$sub}->{$name};

    if (! defined $value) {
	warn "ERROR: no $name for $f";
    }

    if (ref($value) eq 'SCALAR') {
	$value = trim($value);
    }

    $value;
}

sub write_csv
{
    my($festivals,$f) = @_;

    print CSV "$f\n";

    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	my $aliyot = $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	if (ref($aliyot) eq 'HASH') {
	    $aliyot = [ $aliyot ];
	}

	foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}} @{$aliyot}) {
	    printf CSV "Torah Service - Aliyah %s,%s %s - %s\n",
	    $aliyah->{'num'},
	    $aliyah->{'book'},
	    $aliyah->{'begin'},
	    $aliyah->{'end'};
	}
    }

    my $haft = $festivals->{'festival'}->{$f}->{'kriyah'}->{'haft'}->{'reading'};
    if (defined $haft) {
	print CSV "Torah Service - Haftarah,$haft\n",
    }

    print CSV "\n";
}

sub write_index_page
{
    my($festivals) = @_;

    open(OUT3, ">$outdir/index.html") || die "$outdir/index.html: $!\n";

    print OUT3 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Hebcal Jewish Holidays</title>
<base href="http://www.hebcal.com/holidays/" target="_top">
<link rel="stylesheet" href="/style.css" type="text/css">
</head>
<body>
<!--htdig_noindex-->
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
Jewish Holidays
</small></td>
<td align="right"><small><a href="/help/">Help</a> - <a
href="/search/">Search</a></small>
</td></tr></table>

<a name="top"></a>
<!--/htdig_noindex-->
<h1>Jewish Holidays</h1>
<dl>
EOHTML
;

    my $prev_descr = '';
    foreach my $f (@FESTIVALS)
    {
	my($anchor) = Hebcal::make_anchor($f);

	my $descr;
	my $about = get_var($festivals, $f, 'about');
	if ($about) {
	    $descr = trim($about->{'content'});
	}
	die "no descr for $f" unless $descr;

	print OUT3 qq{<dt><a href="$anchor">$f</a>\n};
	print OUT3 qq{<dd>$descr\n} unless $descr eq $prev_descr;
	$prev_descr = $descr;
    }

    print OUT3 "</dl>\n";
    print OUT3 $html_footer;

    close(OUT3);
}

sub write_festival_part
{
    my($festivals,$f) = @_;

    my $anchor = Hebcal::make_anchor($f);
    $anchor =~ s/\.html$//;

    my $torah;
    my $maftir;
    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	my $aliyot = $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	if (ref($aliyot) eq 'HASH') {
	    $aliyot = [ $aliyot ];
	}

	my $book;
	my $begin;
	my $end;
	foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			    @{$aliyot}) {
	    if ($aliyah->{'num'} eq 'M') {
		$maftir = sprintf("%s %s - %s",
				  $aliyah->{'book'},
				  $aliyah->{'begin'},
				  $aliyah->{'end'});
	    }

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
	    if ($maftir) {
		$torah .= " &amp; $maftir";
	    }
	} elsif ($maftir) {
	    $torah = "$maftir (special maftir)";
	}
    }

    if ($torah) {
	my $torah_href = $festivals->{'festival'}->{$f}->{'kriyah'}->{'torah'}->{'href'};

	print OUT2 qq{\n<h3>Torah Portion: };
	print OUT2 qq{<a name="$anchor-torah"\nhref="$torah_href"\ntitle="Translation from JPS Tanakh">}
	    if ($torah_href);
	print OUT2 $torah;
	print OUT2 qq{</a>}
	    if ($torah_href);
	print OUT2 qq{</h3>\n};

	if (! $torah_href) {
	    warn "$f: missing Torah href\n";
	}

	if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	    my $aliyot = $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	    if (ref($aliyot) eq 'HASH') {
		$aliyot = [ $aliyot ];
	    }

	    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}} @{$aliyot}) {
		print_aliyah($aliyah);
	    }
	}

	print OUT2 "</p>\n";
    }

    my $haft = $festivals->{'festival'}->{$f}->{'kriyah'}->{'haft'}->{'reading'};
    if ($haft) {
	my $haft_href = $festivals->{'festival'}->{$f}->{'kriyah'}->{'haft'}->{'href'};

	print OUT2 qq{\n<h3>Haftarah: };
	print OUT2 qq{<a name="$anchor-haft"\nhref="$haft_href"\ntitle="Translation from JPS Tanakh">}
	    if ($haft_href);
	print OUT2 $haft;
	print OUT2 qq{</a>}
	    if ($haft_href);
	print OUT2 qq{</h3>\n};

	if (! $haft_href) {
	    warn "$f: missing Haft href\n";
	}
    }
}

sub write_festival_page
{
    my($festivals,$f) = @_;

    my($anchor) = Hebcal::make_anchor($f);

    my $descr;
    my $about = get_var($festivals, $f, 'about');
    if ($about) {
	$descr = trim($about->{'content'});
    }
    warn "$f: missing About description\n" unless $descr;

    open(OUT2, ">$outdir/$anchor") || die "$outdir/$anchor: $!\n";

    print OUT2 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Jewish Holidays: $f</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/holidays/$anchor" target="_top">
<meta name="description" content="$f: $descr">
<meta name="keywords" content="$f,jewish,holidays,holiday,festival,chag,hag">
<link rel="stylesheet" href="/style.css" type="text/css">
EOHTML
;

    my $prev = $PREV{$f};
    my($prev_link) = '';
    my($prev_anchor);
    if ($prev)
    {
	$prev_anchor = Hebcal::make_anchor($prev);
	my $title = "Previous Holiday";
	$prev_link = qq{<a name="prev" href="$prev_anchor"\n} .
	    qq{title="$title">&laquo;&nbsp;$prev</a>};
    }

    my $next = $NEXT{$f};
    my($next_link) = '';
    my($next_anchor);
    if ($next)
    {
	$next_anchor = Hebcal::make_anchor($next);
	my $title = "Next Holiday";
	$next_link = qq{<a name="next" href="$next_anchor"\n} .
	    qq{title="$title">$next&nbsp;&raquo;</a>};
    }

    print OUT2 qq{<link rel="prev" href="$prev_anchor" title="$prev">\n}
    	if $prev_anchor;
    print OUT2 qq{<link rel="next" href="$next_anchor" title="$next">\n}
    	if $next_anchor;

    my $hebrew = get_var($festivals, $f, 'hebrew');
    $hebrew = '' unless $hebrew;

    my($strassfeld_link) =
	"http://www.amazon.com/exec/obidos/ASIN/0062720082/hebcal-20";

    print OUT2 <<EOHTML;
</head>
<body>
<!--htdig_noindex-->
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/holidays/">Jewish Holidays</a> <tt>-&gt;</tt>
$f
</small></td>
<td align="right"><small><a href="/help/">Help</a> - <a
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
<h1 align="center"><a name="top">$f</a><br><span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>
</td>
<td align="right" width="15%">
$next_link
</td>
</tr>
</table>
<a href="$strassfeld_link"><img
src="/i/0062720082.01.TZZZZZZZ.jpg" border="0" hspace="5"
alt="The Jewish Holidays: A Guide &amp; Commentary"
vspace="5" width="75" height="90" align="right"></a>
<p>$descr.
EOHTML
;

    if ($about) {
	my $about_href = $about->{'href'};
	if ($about_href) {
	    my $more = '';
	    if ($about_href =~ /^http:\/\/([^\/]+)/i) {
		$more = $1;
		$more =~ s/^www\.//i;
		if ($more eq 'hebcal.com') {
		    $more = '';
		} elsif ($more eq 'jewfaq.org') {
		    $more = " from Judaism 101";
		} else {
		    $more = " from $more";
		}
	    }
	    print OUT2 <<EOHTML;
[<a title="Detailed information about holiday"
href="$about_href">more${more}...</a>]</p>
EOHTML
;
	} else {
    	    warn "$f: missing About href\n";
	}
    }

    if (defined $OBSERVED{$f})
    {
	print OUT2 <<EOHTML;
<h3><a name="dates">List of Dates</a></h3>
$f is observed on:
<ul>
EOHTML
	;
	foreach my $stime (@{$OBSERVED{$f}}) {
	    next unless defined $stime;
	    print OUT2 "<li>$stime\n";
	}
	print OUT2 "</ul>\n";
    }

    if (@{$SUBFESTIVALS{$f}} == 1)
    {
	write_festival_part($festivals, $SUBFESTIVALS{$f}->[0]);
    }
    else
    {
	foreach my $part (@{$SUBFESTIVALS{$f}})
	{
	    my $anchor = Hebcal::make_anchor($part);
	    $anchor =~ s/\.html$//;

	    print OUT2 qq{\n<h2><a name="$anchor"></a>$part};
	    my $part_hebrew = $festivals->{'festival'}->{$part}->{'hebrew'};
	    if ($part_hebrew)
	    {
		print OUT2 qq{\n<br><span dir="rtl" class="hebrew"\nlang="he">$part_hebrew</span>};
	    }
	    print OUT2 qq{</h2>\n<div style="padding-left:20px;">};

	    my $part_about = $festivals->{'festival'}->{$part}->{'about'};
	    if ($part_about) {
		my $part_descr = trim($part_about->{'content'});
		if ($part_descr && $part_descr ne $descr) {
		    print OUT2 qq{<p>$part_descr.\n};
		}
	    }

	    write_festival_part($festivals,$part);
	    print OUT2 qq{</div>\n};
	}
    }

    print OUT2 qq{
<h3><a name="ref">References</a></h3>
<dl>
<dt><em><a
href="$strassfeld_link">The
Jewish Holidays: A Guide &amp; Commentary</a></em>
<dd>Rabbi Michael Strassfeld
<dt><em><a
title="Tanakh: The Holy Scriptures, The New JPS Translation According to the Traditional Hebrew Text" 
href="http://www.amazon.com/exec/obidos/ASIN/0827602529/hebcal-20">Tanakh:
The Holy Scriptures</a></em>
<dd>Jewish Publication Society
};

    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	print OUT2 qq{<dt><em><a
href="http://www.bible.ort.org/">Navigating the Bible II</a></em>
<dd>World ORT
};
    }

    print OUT2 "</dl>\n";

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

sub print_aliyah
{
    my($aliyah) = @_;

    my($c1,$v1) = ($aliyah->{'begin'} =~ /^(\d+):(\d+)$/);
    my($c2,$v2) = ($aliyah->{'end'}   =~ /^(\d+):(\d+)$/);
    my($info) = $aliyah->{'book'} . " ";
    if ($c1 == $c2) {
	$info .= "$c1:$v1-$v2";
    } else {
	$info .= "$c1:$v1-$c2:$v2";
    }

    my $book = lc($aliyah->{'book'});
    $book =~ s/\s+.+$//;

    my $bid = 0;
    if ($book eq 'genesis') { $bid = 1; } 
    elsif ($book eq 'exodus') { $bid = 2; }
    elsif ($book eq 'leviticus') { $bid = 3; }
    elsif ($book eq 'numbers') { $bid = 4; }
    elsif ($book eq 'deuteronomy') { $bid = 5; }

    $info = qq{<a title="Hebrew text and audio from ORT"\nhref="http://www.bible.ort.org/books/torahd5.asp?action=displaypage&amp;book=$bid&amp;chapter=$c1&amp;verse=$v1&amp;portion=} .
    $aliyah->{'parsha'} . qq{">$info</a>};

    my($label) = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    print OUT2 qq{$label: $info};

    if ($aliyah->{'numverses'}) {
	print OUT2 "\n<span class=\"tiny\">(",
	$aliyah->{'numverses'}, "&nbsp;p'sukim)</span>";
    }

    print OUT2 qq{<br>\n};
}

sub html_footer
{
    my($file) = @_;

    my($rcsrev) = '$Revision$'; #'
    $rcsrev =~ s/\s*\$//g;

    my($mtime) = (stat($file))[9];
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

sub holidays_observed
{
    my($current) = @_;

    my $heb_yr = `./hebcal -t -x -h | grep -v Omer`;
    chomp($heb_yr);
    $heb_yr =~ s/^.+, (\d\d\d\d)/$1/;

    my $extra_years = 5;
    my @years;
    foreach my $i (0 .. $extra_years)
    {
	my $yr = $heb_yr + $i - 1;
	my @ev = Hebcal::invoke_hebcal("./hebcal -D -H $yr", '', 0);
	$years[$i] = \@ev;
    }

    for (my $yr = 0; $yr < $extra_years; $yr++)
    {
	my %greg2heb;
	my @events = @{$years[$yr]};
	for (my $i = 0; $i < @events; $i++)
	{
	    my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	    next if $subj =~ /^Erev /;

	    my $month = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	    my $stime = sprintf("%02d %s %04d",
				$events[$i]->[$Hebcal::EVT_IDX_MDAY],
				$Hebcal::MoY_long{$month},
				$events[$i]->[$Hebcal::EVT_IDX_YEAR]);

	    # hebcal -D conveniently emits the date before the event name
	    if ($subj =~ /^\d+\w+ of [^,]+, \d+$/)
	    {
		$greg2heb{$stime} = $subj;
		next;
	    }

	    my $subj_copy = $subj;
	    $subj_copy =~ s/ \d{4}$//;
	    $subj_copy =~ s/ \(CH\'\'M\)$//;
	    $subj_copy =~ s/ \(Hoshana Raba\)$//;
	    $subj_copy =~ s/ [IV]+$//;
	    $subj_copy =~ s/: \d Candles?$//;
	    $subj_copy =~ s/: 8th Day$//;
	    $subj_copy =~ s/^Erev //;

	    my $text = $stime;
	    $text .= " ($greg2heb{$stime})"
		if (defined $greg2heb{$stime});

	    $current->{$subj_copy}->[$yr] = $text
		unless (defined $current->{$subj_copy} &&
			defined $current->{$subj_copy}->[$yr]);
	}
    }
}
