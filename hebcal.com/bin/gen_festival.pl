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
my($usage) = "usage: $0 [-h] festival.xml festival.csv output-dir
    -h        Display usage information.
";

my(%opts);
getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 3) || die "$usage";

my($festival_in) = shift;
my($outfile) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

my $fxml = XMLin($festival_in);
open(CSV, ">$outfile") || die "$outfile: $!\n";

my $html_footer = html_footer($festival_in);

foreach my $f (sort keys %{$fxml->{'festival'}})
{
    if ($f !~ /\(on Shabbat\)$/) {
	write_festival_page($fxml,$f);
    }

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

close(CSV);
exit(0);

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
		if ($book && $aliyah->{'book'} eq $book) {
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
	    $torah = "special maftir: $maftir";
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
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>
<!--/htdig_noindex-->
<br>
<h1 align="center"><a name="top">$f</a><br><span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>

<p>$descr. [<a title="Detailed information about holiday"
href="$about_href">more...</a>]</p>
EOHTML
;

    if ($torah || $maftir) {
	print OUT2 <<EOHTML;

<h3>Torah Portion: <a name="torah"
href="$torah_href"
title="Translation from JPS Tanakh">$torah</a></h3>
<p>
EOHTML
;

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
	print OUT2 <<EOHTML;
<h3>Haftara: <a name="haftara"
href="$haftara_href"
title="Translation from JPS Tanakh">$haftara</a></h3>
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

    $info = qq{<a title="Audio from ORT"\nhref="http://www.bible.ort.org/books/torahd5.asp?action=displaypage&amp;book=$bid&amp;chapter=$c1&amp;verse=$v1&amp;portion=} .
    $aliyah->{'parsha'} . qq{">$info</a>};

    my($label) = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    print OUT2 qq{$label: $info};

    if ($aliyah->{'numverses'}) {
	print OUT2 " <span class=\"tiny\">(",
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
