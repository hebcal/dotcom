#!/usr/bin/perl -w

use strict;
use utf8;
use XML::Simple;

my $dir = $0;
$dir =~ s,/[^/]+$,,;

my $citiesTxt = shift;
my $countryXml = shift;
my $outfile = shift;
die "usage: $0 cities.txt opencountrycodes.xml outfile.js\n" unless $outfile;

open(CITIES, $citiesTxt) || die $citiesTxt;
binmode(CITIES, ":utf8");

my $axml = XMLin($countryXml, KeyAttr => [ "code" ]);
$axml || die $countryXml;

open(O,">$outfile.$$") || die "$outfile.$$: $!\n";
binmode(O, ":utf8");

print O <<EOJS;
if(typeof HEBCAL=="undefined"||!HEBCAL){var HEBCAL={};}
EOJS
;
print O "HEBCAL.cities={";
my $first = 1;
while(<CITIES>) {
    chomp;
    print O "," unless $first;
    $first = 0;
    my($woeid,$country,$city,$latitude,$longitude,$tzName,$tzOffset,$dst) = split(/\t/);
    $woeid =~ s/^woe//;
    print O "\"$woeid\":[\"$country\",\"$city\",$latitude,$longitude,\"$tzName\"]";
}
close(CITIES);

print O "\n};\n";

print O "HEBCAL.countries={";
$first = 1;
foreach my $cc (keys %{$axml->{"country"}}) {
    my $name = $axml->{"country"}->{$cc}->{"name"};
    $name =~ s/,\s+.+$//;
    $name = "Laos" if $cc eq "LA";
    $name = "Vietnam" if $cc eq "VN";
    $name = "Democratic Congo" if $cc eq "CD";
    $name = "North Korea" if $cc eq "KP";
    $name = "Russia" if $cc eq "RU";
    $name = "U.S. Virgin Islands" if $cc eq "VI";
    $name = "British Virgin Islands" if $cc eq "VG";
    print O "," unless $first;
    $first = 0;
    printf O "\"%s\":\"%s\"", uc($cc), $name;
}
print O "};\n";

close(O);
rename("$outfile.$$", $outfile) || die "$outfile: $!\n";

exit(0);
