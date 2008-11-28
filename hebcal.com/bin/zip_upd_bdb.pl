#!/usr/bin/perl -w

use strict;
use XML::Simple;
use DB_File;

print STDERR "load tz...";

my %TZ;
open(F, $ENV{"HOME"} . "/zip_tz.log") || die;
while (<F>) {
    chop;
    my($zip,$tz) = split(/\t/);
    $TZ{$zip} = $tz;
}
close(F);

print STDERR " done\n";

#my $dbmfile = "/home/hebcal/web/hebcal.com/hebcal/zips99.db";
my $dbmfile = "/tmp/zips99.db";
my %DB;
tie(%DB, 'DB_File', $dbmfile, O_RDWR, 0644, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";

for (my $i = 0; $i < 10; $i++) {
    my $dir = sprintf("%02d", $i);
    foreach my $f (glob("~/zips/$dir/*.xml")) {
    my $x = XMLin($f);
    my $lat = $x->{"Result"}->{"Latitude"};
    my $long = $x->{"Result"}->{"Longitude"};
    my $zip = $x->{"Result"}->{"Zip"};
    my $city = $x->{"Result"}->{"City"};
    my $state = $x->{"Result"}->{"State"};

    next unless defined $zip && defined $lat && defined $long;

    $zip =~ s/-0001$//;

    if (defined $DB{$zip}) {
	my($db_latitude,$db_longitude,$db_tz,$db_dst,$db_city,$db_state)
	    = split(/,/, $DB{$zip});
	if ($lat eq $db_latitude && $long eq $db_longitude) {
	    print STDERR ".";
	    next;
	} else {
	    print STDERR " $zip";
	    $DB{$zip} = join(",",$lat,$long,$db_tz,$db_dst,$db_city,$db_state);
	}
    } else {
#	next if ref($city) || ref($state);
	$city = "UNKNOWN" if ref($city);
	$state = "--" if ref($state);

	my $tz = $TZ{$zip};
	unless (defined $tz) {
	    warn "no tz for $zip";
	    next;
	}

	print STDERR " *$zip*";
	my $dst;
	if ($tz == "-10" || $tz == "-4") {
	    $dst = 0;
	} elsif ($state eq "AP" || $state eq "AZ" || $state eq "HI") {
	    $dst = 0;
	} else {
	    $dst = 1;
	}

	$DB{$zip} = join(",",$lat,$long,$tz,$dst,$city,$state);
    }
}
}

untie(%DB);
    
