#!/usr/local/bin/perl -w

use lib "/home/mradwin/local/lib/perl5/site_perl";

use strict;
use DB_File;
use Fcntl qw(:DEFAULT :flock);
use Hebcal;
use Net::SMTP;
use Mail::Internet;
use Email::Valid;

my $message = new Mail::Internet \*STDIN;
my $header = $message->head();

my $to = $header->get('To');

unless (defined $to) {
    die "$0: no To: header!";
}

my $from = $header->get('From');

if ($to =~ /shabbat-subscribe\+([^\@]+)\@/) {
    &subscribe($1);
} elsif ($to =~ /shabbat-unsubscribe\@/) {
    chomp $from;
    if (Email::Valid->address($from))
    {
	my $addr = Email::Valid->address($from);
	&unsubscribe($addr);
    }
}
exit(0);

sub subscribe
{
    my($encoded) = @_;

    my $dbmfile = '/pub/m/r/mradwin/hebcal.com/email/email.db';
    my(%DB);
    my($db) = tie(%DB, 'DB_File', $dbmfile, O_CREAT|O_RDWR, 0644,
		  $DB_File::DB_HASH)
	or die "$dbmfile: $!\n";

    my($fd) = $db->fd;
    open(DB_FH, "+<&=$fd") || die "dup $!";

    unless (flock (DB_FH, LOCK_EX)) { die "flock: $!" }

    my $args = $DB{$encoded};
    unless ($args) {
	warn "skipping $encoded: (undef)";
	return 0;
    }

    if ($args =~ /^action=/) {
	warn "skipping $encoded: $args";
	return 0;
    }

    my($now) = time;
    $DB{$encoded} = "action=PROCESSED;t=$now";

    $db->sync;
    flock(DB_FH, LOCK_UN);
    undef $db;
    untie(%DB);
    close(DB_FH);

    my %args;
    foreach my $kv (split(/;/, $args)) {
	my($key,$val) = split(/=/, $kv, 2);
	$args{$key} = $val;
    }
    unless ($args{'em'}) {
	warn "skipping $encoded: no email ($args)";
	return 0;
    }

    my $email = $args{'em'};
    delete $args{'em'};

    my $newargs = 't2=' . time();
    while (my($key,$val) = each(%args)) {
	$newargs .= ';' . $key . '=' . $val;
    }

    $dbmfile = '/pub/m/r/mradwin/hebcal.com/email/subs.db';
    $db = tie(%DB, 'DB_File', $dbmfile, O_CREAT|O_RDWR, 0644,
	      $DB_File::DB_HASH)
	or die "$dbmfile: $!\n";

    $fd = $db->fd;
    open(DB_FH, "+<&=$fd") || die "dup $!";

    unless (flock (DB_FH, LOCK_EX)) { die "flock: $!" }

    $DB{$email} = $newargs;

    $db->sync;
    flock(DB_FH, LOCK_UN);
    undef $db;
    untie(%DB);
    close(DB_FH);
}

sub unsubscribe
{
    my($email) = @_;

    my $dbmfile = '/pub/m/r/mradwin/hebcal.com/email/subs.db';
    my(%DB);
    my($db) = tie(%DB, 'DB_File', $dbmfile, O_CREAT|O_RDWR, 0644,
		  $DB_File::DB_HASH)
	or die "$dbmfile: $!\n";

    my($fd) = $db->fd;
    open(DB_FH, "+<&=$fd") || die "dup $!";

    unless (flock (DB_FH, LOCK_EX)) { die "flock: $!" }

    my $args = $DB{$email};
    unless ($args) {
	warn "skipping $email: (undef)";
	return 0;
    }

    if ($args =~ /^action=/) {
	warn "skipping $email: $args";
	return 0;
    }

    my($now) = time;
    $DB{$email} = "action=UNSUBSCRIBE;t=$now";

    $db->sync;
    flock(DB_FH, LOCK_UN);
    undef $db;
    untie(%DB);
    close(DB_FH);
}
