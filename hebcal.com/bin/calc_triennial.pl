#!/usr/local/bin/perl -w -I/pub/p/e/perl/lib/site_perl:/home/mradwin/local/lib/perl5:/home/mradwin/local/lib/perl5/site_perl

# $Id$

use Hebcal;
use Getopt::Std;
use XML::Simple;
use Data::Dumper;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] [-H <year>]
    -h        Display usage information.
    -H <year> Start with hebrew year <year> (default this year)
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

# year I in triennial cycle was 5756
my $year_num = (($hebrew_year - 5756) % 3) + 1;
my $start_year = $hebrew_year - ($year_num - 1);
print "$hebrew_year is year $year_num.  cycle starts at year $start_year\n";

my(@events);
foreach my $cycle (0 .. 3)
{
    my($yr) = $start_year + $cycle;
    my(@ev) = &Hebcal::invoke_hebcal("./hebcal -s -h -x -H $yr", '');
    push(@events, @ev);
}

my $bereshit_idx;
for (my $i = 0; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit')
    {
	$bereshit_idx = $i;
	last;
    }
}

die "can't find Bereshit for Year I" unless defined $bereshit_idx;

my(%pattern);
for (my $i = $bereshit_idx; $i < @events; $i++)
{
    next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
    my $subj = $1;

#    print "idx=$i, subj=$subj\n";

    if ($subj =~ /^([^-]+)-(.+)$/ &&
	defined $combined{$1} && defined $combined{$2})
    {
	push(@{$pattern{$1}}, 'T');
	push(@{$pattern{$2}}, 'T');
    }
    else
    {
	push(@{$pattern{$subj}}, 'S');
    }
}

my $parshiot = XMLin('/pub/m/r/mradwin/hebcal.com/dist/aliyah.xml');

my %triennial_aliyot;
foreach my $key (keys %{$parshiot->{'parsha'}}) {
    my $val = $parshiot->{'parsha'}->{$key};
    my $yrs = $val->{'triennial'}->{'year'};
#    print "\n\n", $key, "\n", "-" x 72, "\n";
#    print Dumper($yrs);

    foreach my $y (@{$yrs}) {
	if (defined $y->{'num'}) {
	    $triennial_aliyot{$key}->{$y->{'num'}} = $y->{'aliyah'};
	    print "1: t{$key}{", $y->{'num'}, "} = ",
	    	$triennial_aliyot{$key}->{$y->{'num'}},
	    	"\n";
	} elsif (defined $y->{'variation'}) {
	    if (! defined $y->{'sameas'}) {
		$triennial_aliyot{$key}->{$y->{'variation'}} = $y->{'aliyah'};
		print "2: t{$key}{", $y->{'variation'}, "} = ",
			$triennial_aliyot{$key}->{$y->{'variation'}},
			"\n";
	    } else {
		print "2: t{$key}{", $y->{'variation'}, "} = skipped\n";
	    }
	} else {
	    warn "strange data for $key";
	    die Dumper($y);
	}
    }

    # second pass for sameas
    foreach my $y (@{$yrs}) {
	if (defined $y->{'variation'} && defined $y->{'sameas'}) {
	    die "missing sameas $key"
		unless defined $triennial_aliyot{$key}->{$y->{'sameas'}};
	    $triennial_aliyot{$key}->{$y->{'variation'}} =
		$triennial_aliyot{$key}->{$y->{'sameas'}};
	    print "3: t{$key}{", $y->{'variation'}, "} = ",
	    $triennial_aliyot{$key}->{$y->{'variation'}},
	    " (sameas ", $y->{'sameas'}, ")\n";
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
    my $pat = '';
    foreach my $yr (0 .. 2) {
	$pat .= $pattern{$p1}->[$yr];
    }

    my $option;
    if ($pat eq 'TTT') {
	$option = 'all-together';
    } else {
	my $vars = $parshiot->{'parsha'}->{$h}->{'variations'}->{'cycle'};
	foreach my $cycle (@{$vars}) {
	    if ($cycle->{'pattern'} eq $pat) {
		$option = $cycle->{'option'};
		last;
	    }
	}

	die "can't find pattern for $h (pat == $pat)"
	    unless defined $option;
    }

    print "$p1-$p2: $pat ($option)";
    print "\n";

    foreach my $yr (1 .. 3) {
	if ($pattern{$p1}->[$yr - 1] eq 'T') {
	    my $yrs = $parshiot->{'parsha'}->{$h}->{'triennial'}->{'year'};
	    print "$h for year $yr\n";

	    foreach my $y (@{$yrs}) {
		if ($y->{'num'} == $yr) {
		    print Dumper($y);
		    last;
		}
	    }

	    my $a = $triennial_aliyot{$h}->{$yr};
	    die unless defined $a;
	    print Dumper($a);

	} else {
	    my $yrs = $parshiot->{'parsha'}->{$p1}->{'triennial'}->{'year'};
	    print "$p1 for year $yr\n";

	    foreach my $y (@{$yrs}) {
		if ($y->{'variation'} eq "$option.$yr") {
		    print Dumper($y);
#		    my $a = $y->{'aliyah'};
		    last;
		}
	    }

	    my $a = $triennial_aliyot{$p1}->{"$option.$yr"};
	    die unless defined $a;
	    print Dumper($a);

	    $yrs = $parshiot->{'parsha'}->{$p2}->{'triennial'}->{'year'};
	    print "$p2 for year $yr\n";

	    foreach my $y (@{$yrs}) {
		if ($y->{'variation'} eq "$option.$yr") {
		    print Dumper($y);
#		    my $a = $y->{'aliyah'};
		    last;
		}
	    }

	    $a = $triennial_aliyot{$p2}->{"$option.$yr"};
	    die unless defined $a;
	    print Dumper($a);

	}
    }
}
