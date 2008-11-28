#!/usr/bin/perl -w

use strict;
use XML::Simple;
use DB_File;

my $dbmfile = "/home/hebcal/web/hebcal.com/hebcal/zips99.db";
my %DB;
tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";

my @z = keys(%DB);
untie(%DB);
my %z;
foreach (@z) {
    $z{$_}=1;
}
undef(@z);

foreach my $f (glob("~/zips/*.xml")) {
    print STDERR ".";
    my $x = XMLin($f);
    my $lat = $x->{"Result"}->{"Latitude"};
    my $long = $x->{"Result"}->{"Longitude"};
    my $zip = $x->{"Result"}->{"Zip"};
    my $city = $x->{"Result"}->{"City"};
    my $state = $x->{"Result"}->{"State"};

    next unless defined $zip && defined $lat && defined $long;

    $zip =~ s/-0001$//;

    if (!$z{$zip}) {
	print "$zip\n";
    }
}

    
