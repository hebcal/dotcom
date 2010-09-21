#!/usr/bin/perl -w

use strict;
use utf8;
use Locale::Country ();

my $dir = $0;
$dir =~ s,/[^/]+$,,;

my $infile = shift;
my $outfile = shift;
die "usage: $0 cities.txt outfile.js\n" unless $outfile;

open(CITIES, $infile) || die $infile;
binmode(CITIES, ":utf8");

open(O,">$outfile.$$") || die "$outfile.$$: $!\n";
binmode(O, ":utf8");

print O <<EOJS;
if (typeof HEBCAL == "undefined" || !HEBCAL) {
   var HEBCAL = {};
}
EOJS
;
print O "HEBCAL.cities={\n";
my $first = 1;
while(<CITIES>) {
    chomp;
    print O ",\n" unless $first;
    $first = 0;
    my($woeid,$country,$city,$latitude,$longitude,$tzName,$tzOffset,$dst) = split(/\t/);
    print O "\"$woeid\":[\"$country\",\"$city\",$latitude,$longitude,\"$tzName\"]";
}
close(CITIES);

print O "\n}\n";

print O "HEBCAL.countries={\n";
$first = 1;
foreach my $cc (Locale::Country::all_country_codes()) {
    my $name = Locale::Country::code2country($cc);
    $name =~ s/,\s+.+$//;
    print O ",\n" unless $first;
    $first = 0;
    printf O "\"%s\":\"%s\"", uc($cc), $name;
}
print O "\n}\n";

close(O);
rename("$outfile.$$", $outfile) || die "$outfile: $!\n";

exit(0);
