#!/usr/bin/perl -w

use strict;
use File::Basename;
use XML::Simple;

die "usage: $0 outfile.pm outfile.php outfile.js\n" unless @ARGV == 3;

my $outfile_pm = shift;
my $outfile_php = shift;
my $outfile_js = shift;

my $SEDROT_XML = "../dist/aliyah.xml";
my $HOLIDAYS_XML = "../dist/festival.xml";
my $CITIES_TXT = "../dist/cities2.txt";
my $podir = "../../hebcal/po";

-d $podir || die "$podir: $!\n";

my $axml = XMLin($SEDROT_XML);
$axml || die $SEDROT_XML;

my $fxml = XMLin($HOLIDAYS_XML);
$fxml || die $HOLIDAYS_XML;

open(CITIES, $CITIES_TXT) || die "$CITIES_TXT: $!";
binmode(CITIES, ":utf8");

open(O,">$outfile_pm.$$") || die "$outfile_pm.$$: $!\n";
binmode(O, ":utf8");
open(OPHP,">$outfile_php.$$") || die "$outfile_php.$$: $!\n";
binmode(OPHP, ":utf8");
open(OJS,">$outfile_js.$$") || die "$outfile_js.$$: $!\n";
binmode(OJS, ":utf8");

print OPHP "<?php\n";
print OJS "if(typeof HEBCAL==\"undefined\"||!HEBCAL){var HEBCAL={};}\n";
print O "package HebcalConst;\n\n";
print O "use utf8;\n\n";

my %seen;
print O "\%HebcalConst::CITIES2 = (\n";
print OPHP "\$hebcal_cities2 = array(\n";
print OJS "HEBCAL.cities2={";
my $first = 1;
while(<CITIES>) {
    chomp;
    my($id,$geonameid) = split(/\|/);
    if (defined $seen{$id} || defined $seen{$geonameid}) {
	die "$CITIES_TXT:$. duplicate $id $geonameid";
    }
    $seen{$id} = 1;
    $seen{$geonameid} = 1;
    print OJS "," unless $first;
    $first = 0;
    print OJS qq{"$id":$geonameid};

    $id =~ s/\'//g;
    print O "'$id'=>$geonameid,\n";
    print OPHP "'$id'=>$geonameid,\n";
}
close(CITIES);
print O ");\n\n";
print OPHP ");\n\n";
print OJS "};\n";

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

my @festivals = sort keys %{$fxml->{"festival"}};
print O "%HebcalConst::HOLIDAYS = (\n";
foreach my $f (@festivals)
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
foreach my $f (@festivals)
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

print O "%HebcalConst::HOLIDAY_TYPE = (\n";
foreach my $f (@festivals) {
    if (defined $fxml->{"festival"}->{$f}->{"type"}) {
        my $k = $f;
        $k =~ s/\'/\\\'/g;
        print O "'$k'=>'", $fxml->{"festival"}->{$f}->{"type"}, "',\n";
    }
}
print O ");\n\n";

print O "%HebcalConst::HOLIDAY_DESCR = (\n";
foreach my $f (@festivals)
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

my $translations = {};
my @pofiles = <$podir/??.po>;
my @langs;
foreach my $infile (@pofiles) {
    my $pofile = basename($infile, ".po");
    open(IN, $infile) || die "$infile: $!";
    binmode(IN, ":utf8");
    my $msgid;
    $translations->{$pofile} = {};
    while(<IN>) {
        if (/^msgid\s+"(.*)"\s*$/) {
            $msgid = $1;
        } elsif (/^msgstr\s+"(.+)"\s*$/) {
            my $msgstr = $1;
            $translations->{$pofile}{$msgid} = $msgstr;
        }
    }
    close(IN);
    push(@langs, $pofile);
}

print O "\$HebcalConst::TRANSLATIONS = {\n";
foreach my $pofile (@langs) {
    print O " '$pofile' => {\n";
    foreach my $msgid (sort keys %{$translations->{$pofile}}) {
        my $msgstr = $translations->{$pofile}{$msgid};
        $msgid =~ s/\'/\\\'/g;
        $msgstr =~ s/\'/\\\'/g;
        print O "  '$msgid'=>'$msgstr',\n";
    }
    print O " },\n";
}
print O "};\n\n";

print O "1;\n";

close(O);
rename("$outfile_pm.$$", $outfile_pm) || die "$outfile_pm: $!\n";

close(OPHP);
rename("$outfile_php.$$", $outfile_php) || die "$outfile_php: $!\n";

close(OJS);
rename("$outfile_js.$$", $outfile_js) || die "$outfile_js: $!\n";

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
