#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use strict;
use DB_File::Lock;
use Hebcal;

sub main() {
    my($op,$addr) = @ARGV;
    if (!defined $op) {
	die "usage: $0 {unsub|bounce} email-addr\n";
    } elsif ($op =~ /^unsub/i && $addr) {
	unsubscribe(lc($addr), 'UNSUBSCRIBE');
    } elsif ($op =~ /^bounce/i && $addr) {
	unsubscribe(lc($addr), 'BOUNCE');
    } else {
	die "usage: $0 {unsub|bounce} email-addr\n";
    }
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
