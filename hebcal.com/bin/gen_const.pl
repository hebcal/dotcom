#!/usr/bin/perl -w

use strict;
use XML::Simple;
use utf8;

my $dir = $0;
$dir =~ s,/[^/]+$,,;

my $outfile = shift;
die "usage: $0 outfile.pm\n" unless $outfile;

my $SEDROT_XML = "/home/hebcal/web/hebcal.com/dist/aliyah.xml";
my $HOLIDAYS_XML = "/home/hebcal/web/hebcal.com/dist/festival.xml";
my $CITIES_TXT = "/home/hebcal/web/hebcal.com/dist/capitals.txt";

my $axml = XMLin($SEDROT_XML);
$axml || die $SEDROT_XML;

my $fxml = XMLin($HOLIDAYS_XML);
$fxml || die $HOLIDAYS_XML;

open(CITIES, $CITIES_TXT) || die $CITIES_TXT;
binmode(CITIES, ":utf8");

open(O,">$outfile.$$") || die "$outfile.$$: $!\n";
binmode(O, ":utf8");

print O "package HebcalConst;\n\n";

print O "use utf8;\n\n";

print O "\@HebcalConst::CITIES = (\n";
while(<CITIES>) {
    chomp;
    my($country,$city,$latitude,$longitude,$tzName,$tzOffset,$dst) = split(/\t/);
    $city =~ s/\'/\\\'/g;
    print O "['$country','$city',$latitude,$longitude,'$tzName',$tzOffset,$dst],\n";
}
close(CITIES);
print O ");\n\n";

print O "%HebcalConst::SEDROT = (\n";
foreach my $h (sort keys %{$axml->{"parsha"}})
{
    if (defined $axml->{"parsha"}->{$h}->{"hebrew"})
    {
	my $k = $h;
	$k =~ s/\'/\\\'/g;
	print O "'$k' => '", $axml->{"parsha"}->{$h}->{"hebrew"}, "',\n";
    }
}
print O ");\n\n";

print O "%HebcalConst::HOLIDAYS = (\n";
foreach my $f (sort keys %{$fxml->{"festival"}})
{
    if (defined $fxml->{"festival"}->{$f}->{"hebrew"})
    {
	my $k = $f;
	$k =~ s/\'/\\\'/g;
	print O "'$k' => '", $fxml->{"festival"}->{$f}->{"hebrew"}, "',\n";
    }
}
print O ");\n\n";

print O "%HebcalConst::YOMTOV = (\n";
foreach my $f (sort keys %{$fxml->{"festival"}})
{
    if (defined $fxml->{"festival"}->{$f}->{"yomtov"}
	&& $fxml->{"festival"}->{$f}->{"yomtov"} eq "1")
    {
	my $k = $f;
	$k =~ s/\'/\\\'/g;
	print O "'$k' => 1,\n";
    }
}
print O ");\n\n";

print O "%HebcalConst::CITIES = (\n";
open(HEBCAL,"$dir/hebcal cities |") || die;
while(<HEBCAL>)
{
    chop;
    if (/^(.+) \(\d+d\d+\' . lat, \d+d\d+\' . long, GMT (.)(\d+):00, (.+)\)/)
    {
	my($city,$sign,$tz,$dst) = ($1,$2,$3,$4);
	$sign = "" if $sign eq "+";
	print O "'$city' => [$sign$tz,'$dst'],\n";
    }
}
close(HEBCAL);

print O ");\n\n";

print O "1;\n";

close(O);
rename("$outfile.$$", $outfile) || die "$outfile: $!\n";

exit(0);


