#!/usr/local/bin/perl5 -w

# $Id$

use Hebcal;
use Getopt::Std;
use Config::IniFiles;
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

open(OUT, ">$outdir/index.html") || die "$outdir/index.html: $!\n";

print OUT <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Hebcal: Torah Readings</title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<base href="http://www.hebcal.com/sedrot/" target="_top">
<link rev="made" href="mailto:webmaster\@hebcal.com">
<link rel="stylesheet" href="/style.css" type="text/css">
<link rel="p3pv1" href="http://www.hebcal.com/w3c/p3p.xml">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
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

my(%out);
foreach my $h ($sedrot->Sections())
{
    &write_sedra_page($h);

    $h =~ s/^Combined //;
    my($anchor) = $h;
    $anchor = lc($anchor);
    $anchor =~ s/[^\w]//g;

    print OUT qq{<dt><a name="$anchor" href="$anchor.html">Parashat\n$h</a>\n};
}

print OUT <<EOHTML;
</dl>
<p>
<hr noshade size="1">
<font size=-2 face=Arial>Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a>
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
    my($h) = @_;

    my($sedrot_h) = $h;
    $h =~ s/^Combined //;

    my($drash_href,$hebrew,$memo,$torah_href,$haftarah_href) =
	&Hebcal::get_holiday_anchor("Parashat $h", 0);
    my(undef,undef,$memo2) =
	&Hebcal::get_holiday_anchor("Parashat $h", 1);

    $memo =~ /Torah: (.+) \/ Haftarah: (.+)$/;
    my($torah,$haftarah) = ($1,$2);

    $memo2 =~ /Torah: .+ \/ Haftarah: (.+)$/;
    my($haftarah_seph) = $1;

    my($seph) = ($haftarah_seph eq $haftarah) ? '' :
	"<br>Haftarah for Sephardim: $haftarah_seph";

    my($anchor) = $h;
    $anchor = lc($anchor);
    $anchor =~ s/[^\w]//g;

    open(OUT2, ">$outdir/$anchor.html") || die "$outdir/$anchor.html: $!\n";

    print OUT2 <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Torah Readings: $h</title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<base href="http://www.hebcal.com/sedrot/$anchor.html" target="_top">
<link rev="made" href="mailto:webmaster\@hebcal.com">
<link rel="stylesheet" href="/style.css" type="text/css">
<link rel="p3pv1" href="http://www.hebcal.com/w3c/p3p.xml">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
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
<td><h1>Parashat $h</h1></td>
<td><h1 dir="rtl" class="hebrew" name="hebrew"
lang="he">$hebrew</h1></td>
</tr>
</table>
<h3><a name="torah">Torah Portion:</a>
<a href="$torah_href">$torah</a></h3>
Shabbat aliyot (full kriyah):
<ol>
EOHTML
;

    foreach (1 .. 7)
    {
	print OUT2 qq{<li>}, $sedrot->val($sedrot_h, "aliyah$_"), "\n";
    }

    print OUT2 <<EOHTML;
</ol>
<h3><a name="haftarah">Haftarah:</a>
<a href="$haftarah_href">$haftarah</a>$seph</h3>
<h3><a name="drash" href="$drash_href">Commentary</a></h3>

<p>
<hr noshade size="1">
<font size=-2 face=Arial>Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a>
<br>
$hhmts
($rcsrev)
</font>
</body></html>
EOHTML
;

}
