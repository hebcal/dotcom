#!/usr/local/bin/perl5 -w

# $Id$

use Hebcal;
use Getopt::Std;
use Config::IniFiles;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] sedrot.ini sedrot.html
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
my($outfile) = shift;

my($sedrot) = new Config::IniFiles(-file => $infile);
$sedrot || die "$infile: $!\n";

open(OUT, ">$outfile") || die "$outfile: $!\n";

print OUT <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Hebcal: Torah Readings</title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<base href="http://www.hebcal.com/help/sedrot.html" target="_top">
<link rev="made" href="mailto:webmaster\@hebcal.com">
<link rel="stylesheet" href="/style.css" type="text/css">
<link rel="p3pv1" href="http://www.hebcal.com/w3c/p3p.xml">
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
</head>
<body>
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/help/">Help</a> <tt>-&gt;</tt>
Torah Readings
</small></td>
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>
<h1>Torah Readings</h1>

<p>
<table border="1" cellpadding="4">
<tr><th>Parashat</th><th>Torah + Aliyot</th><th>Haftarah</th></tr>
EOHTML
;

my(%out);
foreach my $h ($sedrot->Sections())
{
    next if $h =~ /^Combined /;

    my($href,$hebrew,$memo,$torah_href,$haftarah_href) =
	&Hebcal::get_holiday_anchor("Parashat $h", 0);
    my(undef,undef,$memo2) =
	&Hebcal::get_holiday_anchor("Parashat $h", 1);

    $memo =~ /Torah: (.+) \/ Haftarah: (.+)$/;
    my($torah,$haftarah) = ($1,$2);

    $memo2 =~ /Torah: .+ \/ Haftarah: (.+)$/;
    my($haftarah_seph) = $1;

    my($seph) = ($haftarah_seph eq $haftarah) ? '' : "<br>($haftarah_seph)";

    my($anchor) = $h;
    $anchor = lc($anchor);
    $anchor =~ s/[^\w]//g;

    print OUT qq{<tr><td><big><a name="$anchor">$h</a><br>\n},
    qq{<span dir="rtl" class="hebrew"\n},
    qq{lang="he">$hebrew</span></big></td>\n},
    qq{<td><a href="$torah_href">$torah</a>\n},
    qq{<small><ol>};

    foreach (1 .. 7)
    {
	print OUT qq{<li>}, $sedrot->val($h, "aliyah$_"), "\n";
    }

    print OUT qq{</ol></small></td>\n},
    qq{<td><a href="$haftarah_href">$haftarah</a>$seph</td></tr>\n};
}

my($mtime) = (stat($infile))[9];
my($hhmts) = "Last modified:\n" . localtime($mtime);

print OUT <<EOHTML;
</table>
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
