#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";
use lib "/pub/p/e/perl/lib/site_perl";

use Getopt::Std;
use XML::Simple;
use strict;

$0 =~ s,.*/,,;  # basename
my($usage) = "usage: $0 festival.xml festival.csv\n";

my(%opts);
getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($festival_in) = shift;
my($outfile) = shift;

my $fxml = XMLin($festival_in);
open(CSV, ">$outfile") || die "$outfile: $!\n";

foreach my $f (sort keys %{$fxml->{'festival'}})
{
    print CSV "$f\n";

    if (defined $fxml->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	my $a = $fxml->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	if (ref($a) eq 'HASH') {
	    printf CSV "Torah Service - Aliyah %s,%s %s - %s\n",
		$a->{'num'},
		$a->{'book'},
		$a->{'begin'},
		$a->{'end'};
	} else {
	    foreach my $aliyah (@{$a}) {
		printf CSV "Torah Service - Aliyah %s,%s %s - %s\n",
		$aliyah->{'num'},
		$aliyah->{'book'},
		$aliyah->{'begin'},
		$aliyah->{'end'};
	    }
	}
    }

    if (defined $fxml->{'festival'}->{$f}->{'haftara'}) {
	print CSV "Torah Service - Haftara,", $fxml->{'festival'}->{$f}->{'haftara'}, "\n";
    }

    print CSV "\n";
}

close(CSV);
exit(0);
