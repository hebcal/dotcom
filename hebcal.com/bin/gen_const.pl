#!/usr/bin/perl -w

use strict;
use XML::Simple;
use utf8;

my $dir = $0;
$dir =~ s,/[^/]+$,,;

my $outfile = shift;
die "usage: $0 outfile.pm\n" unless $outfile;

my $SEDROT_XML = "../dist/aliyah.xml";
my $HOLIDAYS_XML = "../dist/festival.xml";
my $CITIES_TXT = "../dist/cities.txt";
my $COUNTRIES_TXT = "../dist/countries.txt";
my $ZONE_TAB = "/usr/share/zoneinfo/zone.tab";

my $axml = XMLin($SEDROT_XML);
$axml || die $SEDROT_XML;

my $fxml = XMLin($HOLIDAYS_XML);
$fxml || die $HOLIDAYS_XML;

open(CITIES, $CITIES_TXT) || die "$CITIES_TXT: $!";
binmode(CITIES, ":utf8");

open(COUNTRIES, $COUNTRIES_TXT) || die "$COUNTRIES_TXT: $!";
binmode(COUNTRIES, ":utf8");

open(ZONE_TAB, $ZONE_TAB) || die "$ZONE_TAB: $!";

open(O,">$outfile.$$") || die "$outfile.$$: $!\n";
binmode(O, ":utf8");

print O "package HebcalConst;\n\n";

print O "use utf8;\n\n";

my %zones;
while(<ZONE_TAB>) {
    chomp;
    next if /^\#/;
    my($country,$latlong,$tz,$comments) = split(/\s+/, $_, 4);
    $zones{$tz} = 1;
}
close(ZONE_TAB);
print O "\@HebcalConst::TIMEZONES = ('UTC',\n";
foreach (sort keys %zones) {
    print O "'$_',\n";
}
print O ");\n\n";

print O "\%HebcalConst::COUNTRIES = (\n";
while(<COUNTRIES>) {
    chomp;
    my($code,$name,$full_name,$iso3,$number,$continent_code) = split(/\|/);
    $name =~ s/\'/\\\'/g;
    print O "'$code'=>['$name','$continent_code'],\n";
}
close(COUNTRIES);
print O ");\n\n";

print O "\%HebcalConst::CITIES_NEW = (\n";
while(<CITIES>) {
    chomp;
    my($woeid,$country,$city,$latitude,$longitude,$tzName,$tzOffset,$dst) = split(/\t/);
    $city =~ s/\'/\\\'/g;
    my $id = $country . "-";
    if ($country eq "US") {
	my $id_city = $city;
	$id_city =~ s/, /-/;
	$id .= $id_city;
    } else {
	$id .= $city;
    }
    print O "'$id'=>['$country','$city',$latitude,$longitude,'$tzName',$tzOffset,$dst,'$woeid'],\n";
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
	print O "'$k'=>'", $axml->{"parsha"}->{$h}->{"hebrew"}, "',\n";
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
	print O "'$k'=>'", $fxml->{"festival"}->{$f}->{"hebrew"}, "',\n";
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
	print O "'$k'=>1,\n";
    }
}
print O ");\n\n";

print O "%HebcalConst::HOLIDAY_DESCR = (\n";
foreach my $f (sort keys %{$fxml->{"festival"}})
{
    my $value = $fxml->{"festival"}->{$f}->{"about"};
    if (defined $value)
    {
	my $k = $f;
	$k =~ s/\'/\\\'/g;
	my $descr;
	if (ref($value) eq 'SCALAR') {
	  $descr = trim($value);
	} elsif (defined $value->{"content"}) {
	  $descr = trim($value->{"content"});
	}
	if (defined $descr) {
	  my $short_descr = $descr;
	  $short_descr =~ s/\..*//;
	  $short_descr =~ s/\'/\\\'/g;
	  print O "'$k'=>'", $short_descr, "',\n";
	}
    }
}
print O ");\n\n";

print O "1;\n";

close(O);
rename("$outfile.$$", $outfile) || die "$outfile: $!\n";

exit(0);

sub trim
{
    my($value) = @_;

    if ($value) {
	local($/) = undef;
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
	$value =~ s/\n/ /g;
	$value =~ s/\s+/ /g;
    }

    $value;
}
