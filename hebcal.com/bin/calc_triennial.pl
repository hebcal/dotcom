#!/usr/local/bin/perl -w -I/pub/p/e/perl/lib/site_perl:/home/mradwin/local/lib/perl5:/home/mradwin/local/lib/perl5/site_perl

# $Id$

use Hebcal;
use Getopt::Std;
use XML::Simple;
use Data::Dumper;
use POSIX qw(strftime);
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

    foreach my $y (@{$yrs}) {
	if (defined $y->{'num'}) {
	    $triennial_aliyot{$key}->{$y->{'num'}} = $y->{'aliyah'};
	} elsif (defined $y->{'variation'}) {
	    if (! defined $y->{'sameas'}) {
		$triennial_aliyot{$key}->{$y->{'variation'}} = $y->{'aliyah'};
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
	}
    }
}

my %option;
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

    if ($pat eq 'TTT')
    {
	$option{$h} = 'all-together';
    }
    else
    {
	my $vars = $parshiot->{'parsha'}->{$h}->{'variations'}->{'cycle'};
	foreach my $cycle (@{$vars}) {
	    if ($cycle->{'pattern'} eq $pat) {
		$option{$h} = $cycle->{'option'};
		$option{$p1} = $cycle->{'option'};
		$option{$p2} = $cycle->{'option'};
		last;
	    }
	}

	die "can't find option for $h (pat == $pat)"
	    unless defined $option{$h};
    }

    print "$h: $pat ($option{$h})\n";
}


my $year = 1;
for (my $i = $bereshit_idx; $i < @events; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Parashat Bereshit' &&
	$i != $bereshit_idx)
    {
	$year++;
	last if ($year == 4);
    }

    next unless ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)/);
    my $h = $1;

    my($time) = &Time::Local::timelocal(1,0,0,
		       $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events[$i]->[$Hebcal::EVT_IDX_MON],
		       $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
    my($stime) = strftime("%A, %d %B %Y", localtime($time));

    print $events[$i]->[$Hebcal::EVT_IDX_SUBJ], " for Year $year - $stime\n";

    if (defined $combined{$h})
    {
	my $variation = $option{$h} . "." . $year;
	my $a = $triennial_aliyot{$h}->{$variation};
	die unless defined $a;
	print "(#1) - $option{$h}\n";
	print Dumper($a);
    }
    elsif (defined $triennial_aliyot{$h}->{$year})
    {
	my $a = $triennial_aliyot{$h}->{$year};
	print "(#2) - $year\n";
	print Dumper($a);
    }
    elsif (defined $triennial_aliyot{$h}->{"Y.$year"})
    {
	my $a = $triennial_aliyot{$h}->{"Y.$year"};
	print "(#3) - Y.$year\n";
	print Dumper($a);
    }
    else
    {
	die "can't find aliyot for $h, year $year";
    }
}
