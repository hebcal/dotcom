#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use strict;
use DB_File;
use Fcntl qw(:DEFAULT :flock);
use Hebcal;

my($op,$addr) = @ARGV;
if (defined $op && $op =~ /^unsub/i && $addr) {
    &unsubscribe(lc($addr));
} else {
    die "usage: $0 unsub email-addr\n";
}

exit(0);

sub unsubscribe
{
    my($email) = @_;

    my $lockfd = &Hebcal::emaildb_lock(LOCK_EX);

    my $dbmfile = '/pub/m/r/mradwin/hebcal.com/email/subs.db';
    my(%DB);
    my($db) = tie(%DB, 'DB_File', $dbmfile, O_CREAT|O_RDWR, 0644,
		  $DB_File::DB_HASH)
	or die "$dbmfile: $!\n";

    my $args = $DB{$email};
    unless ($args) {
	warn "ignoring $email: not subscribed\n";
	undef $db;
	untie(%DB);
	&Hebcal::emaildb_unlock($lockfd);
	return 0;
    }

    if ($args =~ /^action=/) {
	warn "ignoring $email: already unsubscribed\n";
	undef $db;
	untie(%DB);
	&Hebcal::emaildb_unlock($lockfd);
	return 0;
    }

    my($now) = time;
    $DB{$email} = "action=UNSUBSCRIBE;t=$now";

    $db->sync;
    undef $db;
    untie(%DB);

    &Hebcal::emaildb_unlock($lockfd);

    warn "unsubscribe $email: OK\n";

    1;
}
