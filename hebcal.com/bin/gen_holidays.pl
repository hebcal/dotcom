#!/usr/local/bin/perl -w

# $Id$

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use Hebcal;
use Getopt::Std;
use Config::IniFiles;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] holidays.ini holidays.html
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

my($holidays) = new Config::IniFiles(-file => $infile);
$holidays || die "$infile: $!\n";

my(%out);
foreach my $h ($holidays->Sections())
{
    next unless defined $holidays->val($h, 'ord') &&
	defined $holidays->val($h, 'class');
    $out{$holidays->val($h, 'class')}->{$holidays->val($h, 'ord')} = $h;
}

open(OUT, ">$outfile") || die "$outfile: $!\n";

print OUT <<EOHTML;
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>Hebcal Jewish Holidays</title>
<base href="http://www.hebcal.com/help/holidays.html" target="_top">
<link rel="stylesheet" href="/style.css" type="text/css">
</head>
<body>
<!--htdig_noindex-->
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/help/">Help</a> <tt>-&gt;</tt>
Holidays
</small></td>
<td align="right"><small><a
href="/search/">Search</a></small>
</td></tr></table>

<h1><a name="top" href="./">Hebcal Help</a>: Holidays</a></h1>
<!--/htdig_noindex-->
EOHTML
;

my($strassfeld_link) =
    "http://www.amazon.com/exec/obidos/ASIN/0062720082/ref=nosim/hebcal-20";
print OUT qq{<h2>Major Holidays</h2>
<p><a
href="$strassfeld_link"><img
src="/i/0062720082.01.TZZZZZZZ.jpg" border="0" hspace="5"
alt="The Jewish Holidays: A Guide &amp; Commentary"
vspace="5" width="75" height="90" align="right"></a>
For a good reference book on the major Jewish Holidays, I'd suggest
Michael Strassfeld's <em><a
href="$strassfeld_link">The
Jewish Holidays: A Guide &amp; Commentary</a></em>.</p>
};
&do_section('major');

print OUT "\n<h3>Special Shabbatot</h3>\n";
&do_section('shabbat');

print OUT "\n<h3>Minor Fast Days</h3>\n";
&do_section('fast');

print OUT "\n<h3>New Holidays</h3>\n";
&do_section('modern');

print OUT "\n<h2>Rosh Chodesh</h2>\n";
&do_section('rc');

my($mtime) = (stat($infile))[9];
my($hhmts) = "Last modified:\n" . localtime($mtime);
my($copyright) = Hebcal::html_copyright2('',0);

print OUT <<EOHTML;

<h2>Other Hebcal Holidays</h2>
<dl>
<dt><a name="omer"
href="http://www.jewfaq.org/holidayb.htm">Days of the Omer</a>
<dd>7 weeks from the second night of Pesach to the day before Shavuot
</dl>

<a name="faq"></a>
<h2>Frequently Asked Questions</h2>

<h3><a name="begin">When do the Holidays begin?</a></h3>

<p>All Jewish Holidays begin the evening before the date specified.  This
is because the Jewish day actually begins at sundown on the previous
night.  Sometimes, for clarity, the Erev Holiday is also included.</p>

<h3><a name="shabbat">When does Shabbat begin?</a></h3>

<p>Shabbat begins 18 minutes before sundown on Friday night.  In Jerusalem,
Shabbat begins 40 minutes before sundown.</p>

<h3><a name="chol">What does CH''M mean?</a></h3>

<p><strong>CH''M</strong> is an abbreviation for Chol Ha-Mo'ed.  Chol
Ha-Mo'ed are the intermediate days of Passover and Sukkot, when work is
permitted.</p>

<h3><a name="sedrot">What are the weekly sedrot?</a></h3>

<p>See the <a href="/sedrot/">Torah Readings</a> page.</p>
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

close(OUT);
exit(0);

sub do_section
{
    my($class) = @_;

    print OUT "<dl>\n";
    foreach my $ord (sort {$a <=> $b} keys %{$out{$class}})
    {
	my($h) = $out{$class}->{$ord};
	my($anchor) = $holidays->val($h, 'anchor');
	my($href) = $holidays->val($h, 'href');
	my($descr) = $holidays->val($h, 'descr');

	if (defined $href) {
	    $href = "\nhref=\"$href\"";
	} else {
	    $href = '';
	}

	if (defined $descr) {
	    $descr = "<dd>$descr\n";
	} else {
	    $descr = '';
	}

	$h =~ s/\s+I$//;	# Pesach I, Sukkot I, etc.
	$h =~ s/:\s+\d+.+$//;	# Chanukah: 1 Candle

	print OUT qq{<dt><a name="$anchor"$href>$h</a>\n$descr};
    }
    print OUT "</dl>\n";
}
