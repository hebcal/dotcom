#!/usr/bin/perl -w

use strict;
use Text::CSV;
use Try::Tiny;
use DBI;
use Carp;

my $dbfile = "canada_postal.sqlite3";
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "",
		       { RaiseError => 1, AutoCommit => 0 })
    or croak $DBI::errstr;
my @sql = ("DROP TABLE IF EXISTS canada_postal",
	   "CREATE TABLE canada_postal (
  postal CHAR(6) NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  city VARCHAR(64) NOT NULL,
  province CHAR(2) NOT NULL,
  PRIMARY KEY (postal)
)",
	  );

foreach my $sql (@sql) {
    $dbh->do($sql)
	or croak $DBI::errstr;
}

my $sth = $dbh->prepare("INSERT INTO canada_postal (postal, latitude, longitude, city, province) VALUES (?, ?, ?, ?, ?)");

my $csvfile = "Canada.csv";
my $csv = Text::CSV->new({ binary => 1,
			   allow_loose_quotes => 1,
			   allow_loose_escapes => 1 })
    or die "Cannot use CSV: " . Text::CSV->error_diag();
 
open my $fh, "<:encoding(Latin1)", $csvfile or die "$csvfile: $!";
my %postal_seen;
my $i = 0;
while (my $row = $csv->getline($fh)) {
    next if $postal_seen{$row->[0]};
    $postal_seen{$row->[0]} = 1;
    my @args;
    if (scalar(@{$row}) == 6) {
	@args = ($row->[0], $row->[1], $row->[2],
		 $row->[3] . ", " . $row->[4],
		 $row->[5]);
    } elsif (scalar(@{$row}) == 7) {
	@args = ($row->[0], $row->[1], $row->[2],
		 $row->[3] . ", " . $row->[4] . ", " . $row->[5],
		 $row->[6]);
    } else {
	@args = @{$row};
    }
    my $rv = $sth->execute(@args)
	or croak "can't execute the query: " . $sth->errstr;
    $dbh->commit if $i++ % 10000 == 0;
}
$csv->eof or $csv->error_diag();
close $fh;

$sth->finish;
$dbh->commit;
$dbh->disconnect;
$dbh = undef;
