#!/usr/bin/perl

eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if 0; # not running under some shell

# $Source: /Users/mradwin/hebcal-copy/local/bin/RCS/shabbat_deactivate.pl,v $
# $Id$

use strict;
use DBI;

my $site = 'hebcal.com';
my $dsn = 'DBI:mysql:database=hebcal1;host=mysql.hebcal.com';
my $dbh = DBI->connect($dsn, 'mradwin_hebcal', 'xxxxxxxx');

my $sql = "SELECT * FROM hebcal1.foo2";
my $sth = $dbh->prepare($sql);
my $rv = $sth->execute
    or die "can't execute the query: " . $sth->errstr;
my @addrs;
while (my($email) = $sth->fetchrow_array) {
    push(@addrs, $email);
}

foreach my $e (@addrs) {
    $sql = <<EOD
UPDATE hebcal1.hebcal_shabbat_email
SET email_status='bounce'
WHERE email_address = '$e'
EOD
;
    $dbh->do($sql);
}

$dbh->disconnect;
exit(0);

