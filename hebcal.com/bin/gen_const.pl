#!/usr/bin/perl -w

use strict;
use XML::Simple;
use utf8;

my $outfile = shift;
die "usage: $0 outfile.pm\n" unless $outfile;

my $SEDROT_XML = "/home/hebcal/web/hebcal.com/dist/aliyah.xml";
my $HOLIDAYS_XML = "/home/hebcal/web/hebcal.com/dist/festival.xml";

my $axml = XMLin($SEDROT_XML);
$axml || die $SEDROT_XML;

my $fxml = XMLin($HOLIDAYS_XML);
$fxml || die $HOLIDAYS_XML;

open(O,">$outfile") || die "$outfile: $!\n";
binmode(O, ":utf8");

print O "package HebcalConst;\n";
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

print O "%HebcalConst::HEBREW = (\n";

foreach my $h (sort keys %{$axml->{"parsha"}})
{
    if (defined $axml->{"parsha"}->{$h}->{"hebrew"})
    {
	my $k = $h;
	$k =~ s/\'/\\\'/g;
	print O "'$k' => '", $axml->{"parsha"}->{$h}->{"hebrew"}, "',\n";
    }
}

print O "\n\n";

foreach my $f (sort keys %{$fxml->{"festival"}})
{
    if (defined $fxml->{"festival"}->{$f}->{"hebrew"})
    {
	my $k = $f;
	$k =~ s/\'/\\\'/g;
	print O "'$k' => '", $fxml->{"festival"}->{$f}->{"hebrew"}, "',\n";
    }
}

print O ");\n";

print O "1;\n";

close(O);


