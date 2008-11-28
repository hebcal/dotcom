#!/usr/bin/perl -w

use strict;
use XML::Simple;
use utf8;

my $infile = shift;

die unless $infile;

my $axml = XMLin($infile);
$axml || die "$infile: $!\n";

my $hebout = "he.po";

open(POT,">sedrot.pot") || die "sedrot.pot: $!\n";
open(ENUS,">en_US.po") || die "en_US.po: $!\n";

open(O,">$hebout") || die "$hebout: $!\n";
binmode(O, ":utf8");

foreach my $h (keys %{$axml->{"parsha"}})
{
    if (defined $axml->{"parsha"}->{$h}->{"hebrew"})
    {
	print O "msgid \"$h\"\n";
	print O "msgstr \"" , $axml->{"parsha"}->{$h}->{"hebrew"}, "\"\n";
	print O "\n";

	print POT "msgid \"$h\"\n";
	print POT "msgstr \"\"\n";
	print POT "\n";

	print ENUS "msgid \"$h\"\n";
	print ENUS "msgstr \"$h\"\n";
	print ENUS "\n";
    }
}

close(O);
close(ENUS);
close(POT);

exit(0);

