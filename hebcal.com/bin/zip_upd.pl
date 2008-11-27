#!/usr/bin/perl -w

use strict;
use XML::Simple;
use DBI ();

my $dsn = "DBI:mysql:database=hebcal5;host=mysql5.hebcal.com";
my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

my $sql0 = "SELECT zips_zipcode FROM hebcal_zips";
my $sth0 = $dbh->prepare($sql0) or die $dbh->errstr;
my $rv = $sth0->execute()
    or die "can't execute the query: " . $sth0->errstr;
my %ZIPS;
while (my($z) = $sth0->fetchrow_array) {
    $ZIPS{$z} = 1;
}
$sth0->finish();

my $sql1 = "
UPDATE hebcal_zips
SET zips_latitude = ?
,zips_longitude = ?
WHERE zips_zipcode = ?
";

my $sql2 = "
UPDATE hebcal_zips
SET zips_latitude = ?
,zips_longitude = ?
,zips_city = ?
,zips_state = ?
WHERE zips_zipcode = ?
";

my $sql3 = "
INSERT INTO hebcal_zips VALUES (?,?,?,?,?,?,?)
";

my $sth1 = $dbh->prepare($sql1) or die $dbh->errstr;
my $sth2 = $dbh->prepare($sql2) or die $dbh->errstr;
my $sth3 = $dbh->prepare($sql3) or die $dbh->errstr;

foreach my $f (glob("~/zips/*.xml")) {
    my $x = XMLin($f);
    my $lat = $x->{"Result"}->{"Latitude"};
    my $long = $x->{"Result"}->{"Longitude"};
    my $zip = $x->{"Result"}->{"Zip"};
    my $city = $x->{"Result"}->{"City"};
    my $state = $x->{"Result"}->{"State"};

    next unless defined $zip && defined $lat && defined $long;

    $zip =~ s/-0001$//;

    if ($ZIPS{$zip}) {
	if (ref($city) || ref($state)) {
	    $city = "UNKNOWN";
	    $state = "--";
	    $sth1->execute($lat, $long, $zip)
		or die $dbh->errstr;
	} else {
	    $sth2->execute($lat, $long, $city, $state, $zip)
		or die $dbh->errstr;
	}
    } else {
	$city = "UNKNOWN" if ref($city);
	$state = "--" if ref($state);

	my $tzfile = "/home/mradwin/tz/$zip.xml";
	if (! -e $tzfile) {
	    warn "$tzfile: $!\n";
	    next;
	}
	my $tzinfo = XMLin($tzfile);
	my $tz = $tzinfo->{"offset"};

	my $dst;
	if ($tz == "-10" || $tz == "-4") {
	    $dst = 0;
	} elsif ($state eq "AP") {
	    $dst = 0;
	} else {
	    $dst = 1;
	}

	$sth3->execute($zip, $lat, $long, $tz, $dst, $city, $state)
	    or die $dbh->errstr;
    }

    print STDERR join("\t", $zip, $city, $state, $lat, $long), "\n";
}

$dbh->disconnect();

    

