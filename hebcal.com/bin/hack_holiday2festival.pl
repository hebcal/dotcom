#!/usr/local/bin/perl -w

# $Id$

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use Getopt::Std;
use Config::IniFiles;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] holidays.ini
    -h        Display usage information.
";

my(%opts);
&getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 1) || die "$usage";

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($infile) = shift;

my($holidays) = new Config::IniFiles(-file => $infile);
$holidays || die "$infile: $!\n";

print "<festivals>\n";
foreach my $h ($holidays->Sections())
{
    print qq{ <festival id="$h"};
    print qq{\nanchor="}, $holidays->val($h, 'anchor'), qq{"};
    print qq{\nhebrew="}, $holidays->val($h, 'hebrew'), qq{"};
    print qq{\ndescr="}, $holidays->val($h, 'descr'), qq{"}
    if defined $holidays->val($h, 'descr');
    print qq{\nyomtov="}, $holidays->val($h, 'yomtov'), qq{">\n};
    if (defined $holidays->val($h, 'href')) {
	print qq{  <link rel="about" href="}, $holidays->val($h, 'href'),
	qq{" />\n}; 
    }
    print qq{ </festival>\n};
}
print "</festivals>\n";
