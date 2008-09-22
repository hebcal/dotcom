#!/usr/local/bin/perl -w

########################################################################
#
# Generates the festival pages for http://www.hebcal.com/holidays/
#
# $Id$
#
# Copyright (c) 2008  Michael J. Radwin.
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

require 5.008_001;

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use utf8;
use open ":utf8";
use Getopt::Std ();
use XML::Simple ();
use LWP::UserAgent;
use HTTP::Request;
use Image::Magick;
use Hebcal ();
use Date::Calc;
use HebcalGPL ();
use strict;

$0 =~ s,.*/,,;  # basename
my($usage) = "usage: $0 [-h] festival.xml output-dir
    -h        Display usage information.
    -f f.csv  Dump full kriyah readings to comma separated values
";

my(%opts);
Getopt::Std::getopts('hf:', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

my $fxml = XML::Simple::XMLin($festival_in);

if ($opts{'f'}) {
    my $fn = $opts{"f"};
    open(CSV, ">$fn.$$") || die "$fn.$$: $!\n";
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

my($this_year,$this_mon,$this_day) = Date::Calc::Today();
my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
my $HEB_YR = $hebdate->{"yy"};
$HEB_YR++ if $hebdate->{"mm"} == 6; # Elul
my %GREG2HEB;
my $NUM_YEARS = 5;
foreach my $i (0 .. $NUM_YEARS) {
    my $yr = $HEB_YR + $i - 1;
    my @events = Hebcal::invoke_hebcal("./hebcal -d -x -h -H $yr", '', 0);

    for (my $i = 0; $i < @events; $i++) {
	my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	if ($subj =~ /^\d+\w+ of [^,]+, \d+$/) {
	    my $isotime = sprintf("%04d%02d%02d",
				  $events[$i]->[$Hebcal::EVT_IDX_YEAR],
				  $events[$i]->[$Hebcal::EVT_IDX_MON] + 1,
				  $events[$i]->[$Hebcal::EVT_IDX_MDAY]);
	    $GREG2HEB{$isotime} = $subj;
	}
    }
}

my %OBSERVED;
holidays_observed(\%OBSERVED);

my %seph2ashk = reverse %Hebcal::ashk2seph;

my $ua;
foreach my $f (@FESTIVALS)
{
    write_festival_page($fxml,$f);
    write_csv($fxml,$f) if $opts{'f'};
}

if ($opts{'f'}) {
    close(CSV);
    rename("$opts{'f'}.$$", $opts{'f'}) || die "$opts{'f'}: $!\n";
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

    my $subf = $SUBFESTIVALS{$f}->[0];
    my $value = $festivals->{'festival'}->{$subf}->{$name};

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

    my $fn = "$outdir/index.html";
    open(OUT3, ">$fn.$$") || die "$fn.$$: $!\n";

    print OUT3 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Hebcal Jewish Holidays</title>
<base href="http://www.hebcal.com/holidays/" target="_top">
<link rel="stylesheet" href="/style.css" type="text/css">
</head>
<body>
<!--htdig_noindex-->
<table width="100%" class="navbar"><tr><td><strong><a
href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
Jewish Holidays
</td><td align="right"><a href="/help/">Help</a> - <a
href="/search/">Search</a></td></tr></table>
<!--/htdig_noindex-->
<a name="top"></a>
<h1>Jewish Holidays</h1>
<a title="Jewish Museum 2009 Wall Calendar from Amazon.com"
class="amzn" id="h1-calendar-1"
href="http://www.amazon.com/o/ASIN/0764943537/hebcal-20"><img
src="http://www.hebcal.com/i/0764943537.01.TZZZZZZZ.jpg" border="0"
width="110" height="102" hspace="8" vspace="8" align="right"
alt="Jewish Museum 2009 Wall Calendar from Amazon.com"></a>
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

	if (defined $OBSERVED{$f} && defined $OBSERVED{$f}->[1]) {
	    my $evt = $OBSERVED{$f}->[1];
	    my($gy,$gm,$gd,$rise_or_set);
	    if ($f =~ /^(Tzom|Asara|Ta\'anit) /) {
		($gy,$gm,$gd) =
		    ($evt->[$Hebcal::EVT_IDX_YEAR],
		     $evt->[$Hebcal::EVT_IDX_MON] + 1,
		     $evt->[$Hebcal::EVT_IDX_MDAY]);
		$rise_or_set = "dawn";
	    } else {
		($gy,$gm,$gd) = Date::Calc::Add_Delta_Days
		    ($evt->[$Hebcal::EVT_IDX_YEAR],
		     $evt->[$Hebcal::EVT_IDX_MON] + 1,
		     $evt->[$Hebcal::EVT_IDX_MDAY],
		     -1);
		$rise_or_set = "sundown";
	    }
	    my $dow = Hebcal::get_dow($gy,$gm,$gd);
	    printf OUT3 "- %s, %02d %s %04d at %s\n",
		$Hebcal::DoW[$dow],
	    	$gd, $Hebcal::MoY_long{$gm}, $gy, $rise_or_set;
	}

	print OUT3 qq{<dd>$descr\n} unless $descr eq $prev_descr;
	$prev_descr = $descr;
    }

    print OUT3 "</dl>\n";
    print OUT3 $html_footer;

    close(OUT3);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
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

#	print OUT2 "</p>\n";
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

    my $fn = "$outdir/$anchor";
    open(OUT2, ">$fn.$$") || die "$fn.$$: $!\n";

    my $short_descr = $descr;
    $short_descr =~ s/\..*//;

    my $page_title = "$f - $short_descr";

    my $keyword = $f;
    $keyword .= ",$seph2ashk{$f}" if defined $seph2ashk{$f};

    my $hebrew = get_var($festivals, $f, 'hebrew');
    if ($hebrew) {
	$hebrew = Hebcal::hebrew_strip_nikkud($hebrew);
	$page_title .= " - $hebrew";
    } else {
	$hebrew = "";
    }

    print OUT2 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>$page_title</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/holidays/$anchor" target="_top">
<meta name="keywords" content="$keyword,jewish,holidays,holiday,festival,chag,hag">
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

#    print OUT2 qq{<link rel="prev" href="$prev_anchor" title="$prev">\n}
#    	if $prev_anchor;
#    print OUT2 qq{<link rel="next" href="$next_anchor" title="$next">\n}
#    	if $next_anchor;

    my($strassfeld_link) =
	"http://www.amazon.com/o/ASIN/0062720082/hebcal-20";

    print OUT2 <<EOHTML;
</head>
<body>
<!--htdig_noindex-->
<table width="100%" class="navbar"><tr><td><strong><a
href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/holidays/">Jewish Holidays</a> <tt>-&gt;</tt>
$f
</td><td align="right"><a href="/help/">Help</a> - <a
href="/search/">Search</a></td></tr></table>
<!--/htdig_noindex-->
<br>
<table width="100%">
<tr>
<td align="left" width="15%">
$prev_link
</td>
<td align="center" width="70%">
<h1 align="center"><a name="top"></a>$f<br><span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>
</td>
<td align="right" width="15%">
$next_link
</td>
</tr>
</table>
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
		} elsif ($more eq "en.wikipedia.org") {
		    $more = " from Wikipedia";
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
#    	    warn "$f: missing About href\n";
	}
    }

    if (defined $OBSERVED{$f})
    {
	my $rise_or_set = ($f =~ /^(Tzom|Asara|Ta\'anit) /) ?
	    "dawn" : "sundown";

	print OUT2 <<EOHTML;
<h3><a name="dates"></a>List of Dates</h3>
$f begins at $rise_or_set in the Diaspora on:
<ul>
EOHTML
	;
	foreach my $evt (@{$OBSERVED{$f}}) {
	    next unless defined $evt;
	    my $isotime = sprintf("%04d%02d%02d",
				  $evt->[$Hebcal::EVT_IDX_YEAR],
				  $evt->[$Hebcal::EVT_IDX_MON] + 1,
				  $evt->[$Hebcal::EVT_IDX_MDAY]);
	    my($gy,$gm,$gd);
	    if ($f =~ /^(Tzom|Asara|Ta\'anit) /) {
		($gy,$gm,$gd) =
		    ($evt->[$Hebcal::EVT_IDX_YEAR],
		     $evt->[$Hebcal::EVT_IDX_MON] + 1,
		     $evt->[$Hebcal::EVT_IDX_MDAY]);
	    } else {
		($gy,$gm,$gd) = Date::Calc::Add_Delta_Days
		    ($evt->[$Hebcal::EVT_IDX_YEAR],
		     $evt->[$Hebcal::EVT_IDX_MON] + 1,
		     $evt->[$Hebcal::EVT_IDX_MDAY],
		     -1);
	    }
	    my $dow = Hebcal::get_dow($gy,$gm,$gd);
	    printf OUT2 "<li><a href=\"/hebcal/?v=1;year=%d;month=%d" .
		";nx=on;nh=on;vis=on;tag=hol.obs\">%s, %02d %s %04d</a> (%s)\n",
		$gy, $gm,
		$Hebcal::DoW[$dow],
		$gd, $Hebcal::MoY_long{$gm}, $gy, $GREG2HEB{$isotime};
	}
	print OUT2 <<EOHTML;
</ul>
EOHTML
    ;
    }

    if (1)
    {
	my $subf = $SUBFESTIVALS{$f}->[0];
	my $books = $festivals->{"festival"}->{$subf}->{"books"}->{"book"};
	if ($books) {
	    if (ref($books) eq 'HASH') {
		$books = [ $books ];
	    }

	    print OUT2 qq{<h3><a name="books"></a>Recommended Books</h3>\n<table border="0" cellpadding="6"><tr>\n};
	    foreach my $book (@{$books}) {
		my $asin = $book->{"ASIN"};
		my $img;
		my $filename;
		foreach my $type (qw(T M)) {
		    $img = "$asin.01.${type}ZZZZZZZ.jpg";
		    $filename = $outdir . "/../i/" . $img;
		    if (! -e $filename) {
			$ua = LWP::UserAgent->new unless $ua;
			$ua->timeout(10);
			$ua->mirror("http://images.amazon.com/images/P/$img",
				    $filename);
		    }
		}

		my $image = new Image::Magick;
		$image->Read($filename);
		my($width,$height) = $image->Get("width", "height");

		my $bktitle = $book->{"content"};
		my $author = $book->{"author"};

		if (!$bktitle)
		{
		    $ua = LWP::UserAgent->new unless $ua;
		    $ua->timeout(10);
		    my $url = "http://webservices.amazon.com/onca/xml?Service=AWSECommerceService&AWSAccessKeyId=15X7F0YJNN5FCYC7CGR2&Operation=ItemLookup&ItemId=$asin&Version=2005-10-13";
		    my $request = HTTP::Request->new("GET", $url);
		    my $response = $ua->request($request);
		    my $rxml = XML::Simple::XMLin($response->content);

		    if (defined $rxml->{"Items"}->{"Item"}->{"ASIN"}
			&& $rxml->{"Items"}->{"Item"}->{"ASIN"} eq $asin)
		    {
			my $attrs = $rxml->{"Items"}->{"Item"}->{"ItemAttributes"};
			$bktitle = $attrs->{"Title"};
			if (ref($attrs->{"Author"}) eq "ARRAY") {
			    $author = $attrs->{"Author"}->[0];
			} elsif (defined $attrs->{"Author"}) {
			    $author = $attrs->{"Author"};
			}
		    }
		}
		else
		{
		    $author = trim($author) if $author;
		    $bktitle = trim($bktitle);
		    $bktitle =~ s/\n/ /g;
		    $bktitle =~ s/\s+/ /g;
		}

		my $shorttitle = $bktitle;
		$shorttitle =~ s/\s*:.+//;
		my $link = "http://www.amazon.com/o/ASIN/$asin/hebcal-20";
		print OUT2 qq{<td width="200" align="center" valign="top"><a class="amzn" id="bk-$asin-1" title="$bktitle" href="$link"><img src="/i/$img"\nalt="$bktitle"\nwidth="$width" height="$height" border="0" hspace="4" vspace="4"></a><br><a class="amzn" id="bk-$asin-2" title="$bktitle" href="$link">$shorttitle</a>};
		print OUT2 qq{<br>by $author} if $author;
		print OUT2 qq{</td>\n};
	    }

	    print OUT2 qq{</tr></table>\n};
	}
    }


    if (@{$SUBFESTIVALS{$f}} == 1)
    {
	write_festival_part($festivals, $SUBFESTIVALS{$f}->[0]);
    }
    else
    {
	foreach my $part (@{$SUBFESTIVALS{$f}})
	{
	    my $part2;
	    if ($part =~ /^$f(.*)/i) {
		$part2 = "reading$1";
	    } else {
		$part2 = $part;
	    }

	    my $anchor = Hebcal::make_anchor($part2);
	    $anchor =~ s/\.html$//;

	    print OUT2 qq{\n<h2><a name="$anchor"></a>$part};
	    my $part_hebrew = $festivals->{'festival'}->{$part}->{'hebrew'};
	    if ($part_hebrew)
	    {
		$part_hebrew = Hebcal::hebrew_strip_nikkud($part_hebrew);
		print OUT2 qq{\n- <span dir="rtl" class="hebrew"\nlang="he">$part_hebrew</span>};
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
<a title="The Jewish Holidays: A Guide &amp; Commentary"
class="amzn" id="strassfeld-1"
href="$strassfeld_link"><img
src="/i/0062720082.01.TZZZZZZZ.jpg" border="0" hspace="5"
alt="The Jewish Holidays: A Guide &amp; Commentary"
vspace="5" width="75" height="90" align="right"></a>
<h3><a name="ref"></a>References</h3>
<dl>
<dt><em><a class="amzn" id="strassfeld-2"
href="$strassfeld_link">The
Jewish Holidays: A Guide &amp; Commentary</a></em>
<dd>Rabbi Michael Strassfeld
<dt><em><a class="amzn" id="jps-tanakh-1"
title="Tanakh: The Holy Scriptures, The New JPS Translation According to the Traditional Hebrew Text" 
href="http://www.amazon.com/o/ASIN/0827602529/hebcal-20">Tanakh:
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
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}

sub print_aliyah
{
    my($aliyah) = @_;

    my($c1,$v1) = ($aliyah->{'begin'} =~ /^([^:]+):([^:]+)$/);
    my($c2,$v2) = ($aliyah->{'end'}   =~ /^([^:]+):([^:]+)$/);
    my($info) = $aliyah->{'book'} . " ";
    if ($c1 eq $c2) {
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
    my $mtime = (stat($file))[9];
    return Hebcal::html_footer_lite($rcsrev,$mtime);
}

sub holidays_observed
{
    my($current) = @_;

    my @years;
    foreach my $i (0 .. $NUM_YEARS)
    {
	my $yr = $HEB_YR + $i - 1;
	my @ev = Hebcal::invoke_hebcal("./hebcal -H $yr", '', 0);
	$years[$i] = \@ev;
    }

    for (my $yr = 0; $yr < $NUM_YEARS; $yr++)
    {
	my @events = @{$years[$yr]};
	for (my $i = 0; $i < @events; $i++)
	{
	    my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	    next if $subj =~ /^Erev /;

	    # Since Chanukah doesn't have an Erev, skip a day
	    next if $subj =~ /^Chanukah: 1 Candle$/;

	    my $subj_copy = $subj;
	    $subj_copy =~ s/ \d{4}$//;
	    $subj_copy =~ s/ \(CH\'\'M\)$//;
	    $subj_copy =~ s/ \(Hoshana Raba\)$//;
	    $subj_copy =~ s/ [IV]+$//;
	    $subj_copy =~ s/: \d Candles?$//;
	    $subj_copy =~ s/: 8th Day$//;

	    $current->{$subj_copy}->[$yr] = $events[$i]
		unless (defined $current->{$subj_copy} &&
			defined $current->{$subj_copy}->[$yr]);
	}
    }
}
