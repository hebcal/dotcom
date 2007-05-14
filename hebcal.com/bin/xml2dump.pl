#!/usr/bin/perl -w

use strict;
use XML::Simple;
use Data::Dumper;

die unless @ARGV == 2;

my $infile = shift;
my $outfile = shift;

#$Data::Dumper::Varname = "_";
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse = 1;

my $xml = XMLin($infile);
$xml || die "$infile: $!\n";

open(O,">$outfile") || die "$outfile: $!\n";
print O Dumper($xml), "\n";
close(O);

exit(0);

