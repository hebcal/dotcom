#!/usr/local/bin/perl -w

# $Id$

use Hebcal;
use Getopt::Std;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] [-H <year>] [-c <cnt>]
    -h        Display usage information.
    -H <year> Start with hebrew year <year> (default this year)
    -c <cnt>  Go for <cnt> years (default 3)
";

my(%opts);
&getopts('hH:c:', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 0) || die "$usage";

my(%combined) = 
    (
     'Vayakhel' => 'Vayakhel-Pekudei',
     'Pekudei' => 'Vayakhel-Pekudei',
     'Tazria' => 'Tazria-Metzora',
     'Metzora' => 'Tazria-Metzora',
     'Achrei Mot' => 'Achrei Mot-Kedoshim',
     'Kedoshim' => 'Achrei Mot-Kedoshim',
     'Behar' => 'Behar-Bechukotai',
     'Bechukotai' => 'Behar-Bechukotai',
     'Chukat' => 'Chukat-Balak',
     'Balak' => 'Chukat-Balak',
     'Matot' => 'Matot-Masei',
     'Masei' => 'Matot-Masei',
     'Nitzavim' => 'Nitzavim-Vayeilech',
     'Vayeilech' => 'Nitzavim-Vayeilech',
     );

my($hebrew_year);
if ($opts{'H'}) {
    $hebrew_year = $opts{'H'};
} else {
    $hebrew_year = `./hebcal -t`;
    chomp($hebrew_year);
    $hebrew_year =~ s/^.+, (\d{4})/$1/;
}

my $count = 3;
if ($opts{'c'}) {
    $count = $opts{'c'};
}

my(%pattern);
foreach my $cycle (0 .. ($count-1))
{
    my($yr) = $hebrew_year + $cycle;
    my(@events) = &Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '');

    for (my $i = 0; $i < @events; $i++)
    {
	my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	$subj =~ s/^Parashat //;

	if ($subj =~ /^([^-]+)-(.+)$/ &&
	    defined $combined{$1} && defined $combined{$2})
	{
	    $pattern{$1}->[$cycle] = 'T';
	    $pattern{$2}->[$cycle] = 'T';
	}
	else
	{
	    $pattern{$subj}->[$cycle] = 'S';
	}
    }
}

foreach my $h (
	       'Vayakhel-Pekudei',
	       'Tazria-Metzora',
	       'Achrei Mot-Kedoshim',
	       'Behar-Bechukotai',
	       'Chukat-Balak',
	       'Matot-Masei',
	       'Nitzavim-Vayeilech',
	       )
{
    my($p1,$p2) = split(/-/, $h);

    print "$p1-$p2: ";
    foreach my $cycle (0 .. ($count-1)) {
	print $pattern{$p1}->[$cycle];
    }
    print "\n";
}
