#!/usr/bin/perl -w

use strict;
my $dir = $0;
$dir =~ s,/[^/]+$,,;

print "%Hebcal::cities =\n", "    (\n";

open(HEBCAL,"$dir/hebcal cities |") || die;
while(<HEBCAL>)
{
    chop;
    if (/^(.+) \(\d+d\d+\' . lat, \d+d\d+\' . long, GMT (.)(\d+):00, (.+)\)/)
    {
	my($city,$sign,$tz,$dst) = ($1,$2,$3,$4);
	$sign = "" if $sign eq "+";
	my $tabs = "\t";
	$tabs .= "\t" if length($city) < 9;
	print "     '$city'$tabs=>\t[$sign$tz,'$dst'],\n";
    }
}
close(HEBCAL);

print "     );\n";
