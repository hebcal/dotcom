#!/usr/local/bin/perl -w

use lib "/home/mradwin/local/lib/perl5/site_perl";

use strict;
use DB_File;
use Fcntl qw(:DEFAULT :flock);
use Hebcal;
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

    my($body) = qq{Hello,

Your subscription request for hebcal is complete.

Regards,
hebcal.com

To unsubscribe from this list, send an email to:
shabbat-unsubscribe\@hebcal.com
};

    &Hebcal::sendmail
	("shabbat-bounce\@hebcal.com",
	 "shabbat-owner\@hebcal.com",
	 "Hebcal Subscription Notification",
	 "Your subscription to hebcal is complete",
	 "List-Unsubscribe: <mailto:shabbat-unsubscribe\@hebcal.com>\n" .
	 "Precedence: bulk\n",
	 $body,$email,'');
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
	&not_subscribed($email);
	return 0;
    }

    if ($args =~ /^action=/) {
	&not_subscribed($email);
	return 0;
    }

    my($now) = time;
    $DB{$email} = "action=UNSUBSCRIBE;t=$now";

    $db->sync;
    flock(DB_FH, LOCK_UN);
    undef $db;
    untie(%DB);
    close(DB_FH);

    my($body) = qq{Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
hebcal.com};

    &Hebcal::sendmail("shabbat-bounce\@hebcal.com",
		      "shabbat-owner\@hebcal.com",
		      "Hebcal Subscription Notification",
		      "You have been unsubscribed from hebcal",
		      '',$body,$email,'');

}

sub not_subscribed
{
    my($email) = @_;

    my($body) = qq{Sorry,

We are unable to process the message from <$email>
to <shabbat-unsubscribe\@hebcal.com>.

The email address used to send your message is not subscribed
to the Shabbat candle lighting time list.

Regards,
hebcal.com};

    &Hebcal::sendmail("shabbat-bounce\@hebcal.com",
		      "shabbat-owner\@hebcal.com",
		      "Hebcal Subscription Notification",
		      "Unable to process your message",
		      '',$body,$email,'');

}
