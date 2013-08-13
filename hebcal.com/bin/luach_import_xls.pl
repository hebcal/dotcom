#!/usr/bin/perl -w

use strict;
use Text::CSV;
use Encode qw(decode encode);
use Carp;
use DBI;

my $dbfile = "reform-luach-spreadsheet.sqlite3";
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "",
		       { RaiseError => 1, AutoCommit => 0 })
    or croak $DBI::errstr;
my @sql = ("DROP TABLE IF EXISTS spreadsheet",
	   "CREATE TABLE spreadsheet (slug TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, content TEXT NOT NULL)",
	  );
foreach my $sql (@sql) {
    $dbh->do($sql)
	or croak $DBI::errstr;
}

binmode(STDOUT, ":utf8");

#my $outfile = "a.txt";
#open(OUTPUT, "> :encoding(utf8)",  $outfile)
#    || die "Can't open > $outfile for writing: $!";

my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
    or die "Cannot use CSV: ".Text::CSV->error_diag ();

my $file = "/Users/mradwin/Downloads/Luach Spreadsheet V3-win.csv";
open my $fh, "<:encoding(latin1)", $file or die "$file: $!";

my $header = $csv->getline($fh);
my $numCols = scalar(@{$header});

my $sql_insert = "INSERT INTO spreadsheet (slug, title, content) VALUES (?, ?, ?)";
my $sth = $dbh->prepare($sql_insert);

my %seen;
while (my $row = $csv->getline($fh)) {
    my $title = cleanup_str($row->[0]) || cleanup_str($row->[1]);

    my $slug = lc($title);
    $slug =~ s/\'/-/g;
    $slug =~ s/\//-/g;
    $slug =~ s/\cM/ - /g;
    $slug =~ s/\(//g;
    $slug =~ s/\)//g;
    $slug =~ s/[^\w]/-/g;
    $slug =~ s/\s+/ /g;
    $slug =~ s/\s/-/g;
    $slug =~ s/-{2,}/-/g;

    if ($seen{$slug}) {
	warn "skipping duplicate $slug";
	next;
    }
    $seen{$slug} = 1;

    my $title2 = cleanup_str($row->[1]) || cleanup_str($row->[0]);
    $title2 =~ s/\cM/<br>/g;

    my $html = qq{<h2>$title2</h2>\n};

    for (my $cell = 2; $cell < $numCols; $cell++) {
	my $val = cleanup_str($row->[$cell]);
	next if $val =~ /^\s*$/;
	$val =~ s/\cM\cM/<p>/g;
	$val =~ s/\cM/<p>/g;
	$html .= qq{<h5>} . cleanup_str($header->[$cell]) . qq{</h5>\n};
	$html .= $val;
	$html .= "\n";
    }


    my $rv = $sth->execute($slug, $title, $html)
	or croak "can't execute the query: " . $sth->errstr;
}
$csv->eof or $csv->error_diag();
close $fh;

$dbh->commit;
$dbh->disconnect;
$dbh = undef;

sub cleanup_str {
    my($s) = @_;

    $s = decode("iso-8859-1", $s);
    $s =~ s/\x{92}/\'/g;
    $s =~ s/\x{93}/\"/g;
    $s =~ s/\x{94}/\"/g;
    $s =~ s/\x{85}/.../g;
    $s =~ s/\.\s{2,}/\. /g;
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;

    $s;
}
