#!/usr/local/bin/perl -w -I/pub/p/e/perl/lib/site_perl:/home/mradwin/local/lib/perl5:/home/mradwin/local/lib/perl5/site_perl

# $Id$

use Hebcal;
use Getopt::Std;
use Config::IniFiles;
use POSIX qw(strftime);
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] sedrot.ini output-dir
    -h        Display usage information.
";

my(%opts);
&getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($infile) = shift;
my($outdir) = shift;

my($sedrot) = new Config::IniFiles(-file => $infile);
$sedrot || die "$infile: $!\n";

my($mtime) = (stat($infile))[9];
my($hhmts) = "Last modified:\n" . localtime($mtime);

#my($hebrew_year) = `./hebcal -t`;
#chomp($hebrew_year);
#$hebrew_year =~ s/^.+, (\d{4})/$1/;

my(%read_on);
my(@events) = &Hebcal::invoke_hebcal('./hebcal -s -h -x -H', '');
my($i);
for ($i = 0; $i < @events; $i++)
{
    # holiday is at 12:00:01 am
    my($time) = &Time::Local::timelocal(1,0,0,
		       $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events[$i]->[$Hebcal::EVT_IDX_MON],
		       $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
    my($stime) = strftime("%A, %d %B %Y", localtime($time));

    my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];

    $subj =~ s/^Parashat //;

    $read_on{$subj} = $stime;

    if ($subj =~ /^([^-]+)-(.+)$/ &&
	defined $sedrot->Parameters($1) &&
	defined $sedrot->Parameters($2))
    {
	$read_on{$1} = $read_on{$2} = $stime;
    }
}

open(OUT, ">$outdir/index.html") || die "$outdir/index.html: $!\n";

print OUT <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Hebcal: Torah Readings</title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/sedrot/" target="_top">
<link rev="made" href="mailto:webmaster\@hebcal.com">
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

<dl>
EOHTML
;

my(%prev,%next,$h2);
foreach my $h ($sedrot->Sections())
{
    next if $h =~ /^Combined /;
    $prev{$h} = $h2;
    $h2 = $h;
}

$h2 = undef;
foreach my $h (reverse $sedrot->Sections())
{
    next if $h =~ /^Combined /;
    $next{$h} = $h2;
    $h2 = $h;
}

my($prev_book);
foreach my $h ($sedrot->Sections())
{
    &write_sedra_page($h,$prev{$h},$next{$h});

    my($book) = $sedrot->val($h, 'verse');
    if ($book) {
	$book =~ s/\s+.+$//;
    } else {
	$book = "Doubled Parshiyot";
    }

    $h =~ s/^Combined //;
    my($anchor) = lc($h);
    $anchor =~ s/[^\w]//g;

    print OUT "<h3>$book</h3>\n" if (!$prev_book || $prev_book ne $book);
    $prev_book = $book;

    print OUT qq{<dt><a name="$anchor" href="$anchor.html">Parashat\n$h</a>\n};
    if (defined $read_on{$h})
    {
	my $date = $read_on{$h};
	$date =~ s/^Saturday, //;
	print OUT qq{ - (<small>$date</small>)\n};
    }
}

print OUT <<EOHTML;
</dl>
<p>
<hr noshade size="1">
<font size=-2 face=Arial>Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a>
<br>
$hhmts
($rcsrev)
</font>
</body></html>
EOHTML
;

close(OUT);
exit(0);

sub write_sedra_page {
    my($h,$prev,$next) = @_;

    my($sedrot_h) = $h;
    $h =~ s/^Combined //;

    my $date = defined $read_on{$h} ? $read_on{$h} : '';

    my(undef,$hebrew,$memo,$torah_href,$haftarah_href,$drash_href) =
	&Hebcal::get_holiday_anchor("Parashat $h", 0);
    my($memo2) = (&Hebcal::get_holiday_anchor("Parashat $h", 1))[2];

    $memo =~ /Torah: (.+) \/ Haftarah: (.+)$/;
    my($torah,$haftarah) = ($1,$2);

    $memo2 =~ /Torah: .+ \/ Haftarah: (.+)$/;
    my($haftarah_seph) = $1;

    my $seph = '';
    my $ashk = '';

    if ($haftarah_seph ne $haftarah)
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
	if (defined $read_on{$prev})
	{
	    $title = "Torah Reading for " . $read_on{$prev};
	}
	$prev_link = qq{<a name="prev" href="$prev_anchor"\n} .
	    qq{title="$title">&lt;&lt; $prev</a>};
    }

    my($next_link) = '';
    my($next_anchor);
    if ($next)
    {
	$next_anchor = lc($next);
	$next_anchor =~ s/[^\w]//g;
	$next_anchor .= ".html";

	my $title = "Next Parsha";
	if (defined $read_on{$next})
	{
	    $title = "Torah Reading for " . $read_on{$next};
	}
	$next_link = qq{<a name="next" href="$next_anchor"\n} .
	    qq{title="$title">$next &gt;&gt;</a>};
    }

    open(OUT2, ">$outdir/$anchor.html") || die "$outdir/$anchor.html: $!\n";

    print OUT2 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Torah Readings: $h</title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/sedrot/$anchor.html" target="_top">
<link rev="made" href="mailto:webmaster\@hebcal.com">
<link rel="stylesheet" href="/style.css" type="text/css">
<link rel="p3pv1" href="http://www.hebcal.com/w3c/p3p.xml">
EOHTML
;

    print OUT2 qq{<link rel="prev" href="$prev_anchor" title="Parashat $prev">\n}
    	if $prev_anchor;
    print OUT2 qq{<link rel="next" href="$next_anchor" title="Parashat $next">\n}
    	if $next_anchor;

    print OUT2 <<EOHTML;
</head>
<body>
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/sedrot/">Torah Readings</a> <tt>-&gt;</tt>
$h
</small></td>
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>

<br>
<table width="100%">
<tr>
<td><h1>Parashat $h</h1>
$date</td>
<td><h1 dir="rtl" class="hebrew" name="hebrew"
lang="he">$hebrew</h1></td>
</tr>
</table>
<h3><a name="torah">Torah Portion:</a>
<a href="$torah_href"\ntitle="Translation from JPS Tanakh">$torah</a></h3>
<a name="aliyot">Shabbat aliyot (full kriyah):</a>
<dl compact>
EOHTML
;

    foreach (1 .. 7, 'M')
    {
	my($aliyah) = $sedrot->val($sedrot_h, "aliyah$_");
	next if (!defined $aliyah && $_ eq 'M');
	die "no aliyah $_ defined for $h" unless defined $aliyah;
	my($c1,$v1,$c2,$v2) = ($aliyah =~ /^(\d+):(\d+)-(\d+):(\d+)/);
	my($aliyah_range);
	if ($c1 == $c2) {
	    $aliyah_range = "$c1:$v1-$v2";
	} else {
	    $aliyah_range = "$c1:$v1-$c2:$v2";
	}

	my($label) = ($_ eq 'M') ? 'maf' : $_;
	if ($aliyah =~ /\s+\((\d+)\)\s*$/) {
	    my $p = $1;
	    $aliyah_range .= qq{\n<font size="-2" face="Arial">($p p'sukim)</font>};
	}
	print OUT2 qq{<dt><a name="aliyah-$label">$label:</a>\n}, 
		qq{<dd>$aliyah_range\n};
    }

    print OUT2 <<EOHTML;
</dl>
<h3><a name="haftarah">Haftarah$ashk:</a>
<a href="$haftarah_href"
title="Translation from JPS Tanakh">$haftarah</a>$seph</h3>
EOHTML
;

    my $c_year = '';
    if ($drash_href =~ m,/(\d{4})/,) {
	$c_year = " for $1";
    }

    print OUT2 
	qq{<h3><a name="drash"\nhref="$drash_href">Commentary$c_year</a></h3>\n}
    if $drash_href;

    if ($prev_link || $next_link)
    {
	print OUT2 <<EOHTML;
<p>
<table width="100%">
<tr>
<td align="left" width="33%">
$prev_link
</td>
<td align="center" width="33%">
Reference: <em><a
href="http://www.amazon.com/exec/obidos/ASIN/0827607121/hebcal-20">Etz
Hayim: Torah and Commentary</a></em>,
David L. Lieber et. al., Jewish Publication Society, 2001.
</td>
<td align="right" width="33%">
$next_link
</td>
</tr>
</table>
EOHTML
;
    }

    print OUT2 <<EOHTML;
<p>
<hr noshade size="1">
<font size=-2 face=Arial>Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a>
<br>
$hhmts
($rcsrev)
</font>
</body></html>
EOHTML
;

}
