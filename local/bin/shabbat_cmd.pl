#!/usr/local/bin/perl -w

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use strict;
use DBI;
use Hebcal;

my $dsn = 'DBI:mysql:database=hebcal1;host=mysql.hebcal.com';
my $dbh = DBI->connect($dsn, 'mradwin_hebcal', 'xxxxxxxx');

sub main() {
    my($op,$addr) = @ARGV;

    my $usage = "usage: $0 {unsub|bounce} email-addr\nusage: $0 prune";

    if (!defined $op) {
	die "$usage\n";
    } elsif ($op eq 'prune') {
	prune();
    } elsif ($op =~ /^unsub/i && $addr) {
	unsubscribe(lc($addr), 'UNSUBSCRIBE');
    } elsif ($op =~ /^bounce/i && $addr) {
	unsubscribe(lc($addr), 'BOUNCE');
    } else {
	die "$usage\n";
    }
}

sub prune() {
    my $dbmfile = '/pub/m/r/mradwin/hebcal.com/email/email.db';
    my(%DB);
    tie(%DB, 'DB_File::Lock', $dbmfile, O_CREAT|O_RDWR, 0644, $DB_HASH, 'write')
	or die "$dbmfile: $!\n";

    my @ids;
    my $prune_time = time - (90 * 24 * 60 * 60);

    while (my($rand,$config) = each(%DB)) {
	my %args;
	foreach my $kv (split(/;/, $config)) {
	    my($key,$val) = split(/=/, $kv, 2);
	    $args{$key} = $val;
	}
	if (defined $args{'t'} && $args{'t'} < $prune_time) {
	    push(@ids, $rand);
	}
    }

    foreach my $id (@ids) {
	print "$DB{$id}\n";
	delete $DB{$id};
    }

    untie(%DB);
}

sub unsubscribe($$) {
    my($email,$flag) = @_;

    my $dbmfile = '/pub/m/r/mradwin/hebcal.com/email/subs.db';
    my(%DB);
    tie(%DB, 'DB_File::Lock', $dbmfile, O_CREAT|O_RDWR, 0644, $DB_HASH, 'write')
	or die "$dbmfile: $!\n";

    my $args = $DB{$email};
    unless ($args) {
	warn "ignoring $email: not subscribed\n";
	untie(%DB);
	return 0;
    }

    if ($args =~ /^action=/) {
	warn "ignoring $email: already unsubscribed\n";
	untie(%DB);
	return 0;
    }

    my($now) = time;
    $DB{$email} = "action=$flag;t3=$now;$args";

    untie(%DB);

    warn "unsubscribe $email: OK\n";

    1;
}

main();
exit(0);

