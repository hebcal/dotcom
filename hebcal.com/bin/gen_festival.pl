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

my @FESTIVALS = (
"Pesach 1",
"Pesach 1 (on Shabbat)",
"Pesach 2",
"Pesach Chol ha-Moed Day 1",
"Pesach Chol ha-Moed Day 2",
"Pesach Chol ha-Moed Day 3",
"Pesach Chol ha-Moed Day 4",
"Pesach Shabbat Chol ha-Moed",
"Pesach 7",
"Pesach 7 (on Shabbat)",
"Pesach 8",
"Pesach 8 (on Shabbat)",
"Shavuot 1",
"Shavuot 2",
"Shavuot 2 (on Shabbat)",
"Asara B'Tevet",
"Ta'anit Bechorot",
"Ta'anit Esther",
"Tzom Gedaliah",
"Tzom Tammuz",
"Tish'a B'Av",
"Rosh Hashana 1",
"Rosh Hashana 1 (on Shabbat)",
"Rosh Hashana 2",
"Yom Kippur",
"Yom Kippur (on Shabbat)",
"Yom Kippur (Mincha)",
"Sukkot 1",
"Sukkot 1 (on Shabbat)",
"Sukkot 2",
"Sukkot Chol ha-Moed Day 1",
"Sukkot Chol ha-Moed Day 2",
"Sukkot Chol ha-Moed Day 3",
"Sukkot Chol ha-Moed Day 4",
"Sukkot Shabbat Chol ha-Moed",
"Sukkot Chol ha-Moed Day 5 (Hoshana Raba)",
"Shmini Atzeret",
"Shmini Atzeret (on Shabbat)",
"Erev Simchat Torah",
"Simchat Torah",
"Chanukah: 1 Candle",
"Chanukah: 2 Candles",
"Chanukah: 3 Candles",
"Chanukah: 4 Candles",
"Chanukah: 5 Candles",
"Chanukah: 6 Candles",
"Chanukah: 7 Candles",
"Chanukah: 8 Candles",
"Chanukah: 8th Day",
"Purim",
"Purim Katan",
"Shushan Purim",
"Shabbat HaChodesh",
"Shabbat HaChodesh (on Rosh Chodesh)",
"Shabbat HaGadol",
"Shabbat Hazon",
"Shabbat Nachamu",
"Shabbat Parah",
"Shabbat Shekalim",
"Shabbat Shekalim (on Rosh Chodesh)",
"Shabbat Shuva",
"Shabbat Zachor",
"Shabbat Rosh Chodesh",
"Shabbat Machar Chodesh",
"Rosh Chodesh Adar",
"Rosh Chodesh Adar I",
"Rosh Chodesh Adar II",
"Rosh Chodesh Av",
"Rosh Chodesh Cheshvan",
"Rosh Chodesh Elul",
"Rosh Chodesh Iyyar",
"Rosh Chodesh Kislev",
"Rosh Chodesh Nisan",
"Rosh Chodesh Sh'vat",
"Rosh Chodesh Sivan",
"Rosh Chodesh Tamuz",
"Rosh Chodesh Tevet",
"Rosh Chodesh Tishrei",
"Lag B'Omer",
"Tu B'Shvat",
"Yom HaAtzma'ut",
"Yom HaShoah",
"Yom HaZikaron",
"Yom Yerushalayim",
	     );

#foreach my $f (sort keys %{$fxml->{'festival'}})
foreach my $f (@FESTIVALS)
{
    if ($f !~ /\(on Shabbat\)$/) {
	write_festival_page($fxml,$f);
    }

    next unless $opts{'f'};

    print CSV "$f\n";

    if (defined $fxml->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	my $aliyot = $fxml->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
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

    if (defined $fxml->{'festival'}->{$f}->{'haftara'}) {
	print CSV "Torah Service - Haftara,",
	$fxml->{'festival'}->{$f}->{'haftara'}, "\n";
    }

    print CSV "\n";
}

if ($opts{'f'}) {
    close(CSV);
}

write_index_page($fxml);

exit(0);

sub write_index_page
{
    my($festivals) = @_;

#    use Data::Dumper;

#    print Dumper($festivals);

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
	next if $f =~ /\(on Shabbat\)$/;
	my($anchor) = lc($f);
	$anchor =~ s/[^\w]//g;

	my $descr = $festivals->{'festival'}->{$f}->{'descr'};

	print OUT3 qq{<dt><a href="$anchor.html">$f</a>\n};
	print OUT3 qq{<dd>$descr\n} unless $descr eq $prev_descr;
	$prev_descr = $descr;
    }

    print OUT3 "</dl>\n";
    print OUT3 $html_footer;

    close(OUT3);
}

sub write_festival_page
{
    my($festivals,$f) = @_;

    my($anchor) = lc($f);
    $anchor =~ s/[^\w]//g;

    my $descr = $festivals->{'festival'}->{$f}->{'descr'};

    open(OUT2, ">$outdir/$anchor.html") || die "$outdir/$anchor.html: $!\n";

    print OUT2 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Jewish Holidays: $f</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/holidays/$anchor.html" target="_top">
<meta name="description" content="$f: $descr">
<meta name="keywords" content="$f,jewish,holidays,holiday,festival,chag,hag">
<link rel="stylesheet" href="/style.css" type="text/css">
EOHTML
;

    my $hebrew = $festivals->{'festival'}->{$f}->{'hebrew'};

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

    my $haftara;
    if (defined $festivals->{'festival'}->{$f}->{'haftara'}) {
	$haftara =  $fxml->{'festival'}->{$f}->{'haftara'};
    }

    my $torah_href;
    my $haftara_href;
    my $about_href;

    my $links = $festivals->{'festival'}->{$f}->{'links'}->{'link'};
    if (defined $links) {
	if (ref($links) eq 'HASH') {
	    $links = [ $links ];
	}
    } else {
	$links = [];
    }

    foreach my $l (@{$links})
    {
	next unless $l->{'rel'};
	if ($l->{'rel'} eq 'torah')
	{
	    $torah_href = $l->{'href'};
	}
	elsif ($l->{'rel'} eq 'haftara')
	{
	    $haftara_href = $l->{'href'};
	}
	elsif ($l->{'rel'} eq 'about')
	{
	    $about_href = $l->{'href'};
	}
    }

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
<h1 align="center"><a name="top">$f</a><br><span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>

<p>$descr.
EOHTML
;

    if ($about_href) {
    print OUT2 <<EOHTML;
[<a title="Detailed information about holiday"
href="$about_href">more...</a>]</p>
EOHTML
;
    }

    if ($torah) {
	print OUT2 qq{\n<h3>Torah Portion: };
	print OUT2 qq{<a name="torah"\nhref="$torah_href"\ntitle="Translation from JPS Tanakh">}
	    if ($torah_href);
	print OUT2 $torah;
	print OUT2 qq{</a>}
	    if ($torah_href);
	print OUT2 qq{</h3>\n};

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

    if ($haftara) {
	print OUT2 qq{\n<h3>Haftara: };
	print OUT2 qq{<a name="haftara"\nhref="$haftara_href"\ntitle="Translation from JPS Tanakh">}
	    if ($haftara_href);
	print OUT2 $haftara;
	print OUT2 qq{</a>}
	    if ($haftara_href);
	print OUT2 qq{</h3>\n};
    }

    my($strassfeld_link) =
	"http://www.amazon.com/exec/obidos/ASIN/0062720082/hebcal-20";
    print OUT2 qq{<a
href="$strassfeld_link"><img
src="/i/0062720082.01.TZZZZZZZ.jpg" border="0" hspace="5"
alt="The Jewish Holidays: A Guide &amp; Commentary"
vspace="5" width="75" height="90" align="right"></a>
<dl>
<dt><a name="ref">References</a>
<dd><em><a
href="$strassfeld_link">The
Jewish Holidays: A Guide &amp; Commentary</a></em>
by Rabbi Michael Strassfeld</p>
<dd><em><a title="Tanakh: The Holy Scriptures, The New JPS Translation According to the Traditional Hebrew Text" 
href="http://www.amazon.com/exec/obidos/ASIN/0827602529/hebcal-20">Tanakh:
The Holy Scriptures</a></em> by Jewish Publication Society
};

    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	print OUT2 qq{<dd><em><a
href="http://www.bible.ort.org/">Navigating the Bible II</a></em>,
World ORT
};
    }

    print OUT2 "</dl>\n";
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

    $info = qq{<a title="Audio from ORT"\nhref="http://www.bible.ort.org/books/torahd5.asp?action=displaypage&amp;book=$bid&amp;chapter=$c1&amp;verse=$v1&amp;portion=} .
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
