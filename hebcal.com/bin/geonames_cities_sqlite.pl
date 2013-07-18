#!/usr/bin/perl -w

use strict;
use DBI;

my $file = "geonames.sqlite3";
my $dbh = DBI->connect("dbi:SQLite:dbname=$file", "", "",
		       { RaiseError => 1, AutoCommit => 0 })
    or die $DBI::errstr;

$dbh->do(qq{CREATE TABLE geoname ( 
    geonameid int PRIMARY KEY, 
    name nvarchar(200), 
    asciiname nvarchar(200), 
    alternatenames nvarchar(4000), 
    latitude decimal(18,15), 
    longitude decimal(18,15), 
    fclass nchar(1), 
    fcode nvarchar(10), 
    country nvarchar(2), 
    cc2 nvarchar(60), 
    admin1 nvarchar(20), 
    admin2 nvarchar(80), 
    admin3 nvarchar(20), 
    admin4 nvarchar(20), 
    population int, 
    elevation int, 
    gtopo30 int, 
    timezone nvarchar(40), 
    moddate date);});

my $sql = qq{INSERT INTO geoname VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)};
my $sth = $dbh->prepare($sql) or die $dbh->errstr;

binmode(STDIN, ":utf8");
my $i = 0;
while(<>) {
    chomp;
    my @a = split(/\t/);
    next if scalar(@a) != 19;
    my $rv = $sth->execute(@a) or die $dbh->errstr;
    if (0 == $i++ % 1000) {
	$dbh->commit;
    }
}
$sth->finish;
undef $sth;
$dbh->commit;
$dbh->disconnect();
undef $dbh;
