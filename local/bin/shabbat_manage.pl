#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use strict;
use DB_File::Lock;
use Hebcal;
use Mail::Internet;
use Email::Valid;
use MIME::Base64;

my $STAGING = '/pub/m/r/mradwin/hebcal.com/email/email.db';
my $SUBS = '/pub/m/r/mradwin/hebcal.com/email/subs.db';

my $err_notsub =
"The email address used to send your message is not subscribed
to the Shabbat candle lighting time list.";
my $err_needto =
"We can't accept Bcc: email messages (hebcal.com address missing
from the To: header).";
my $err_useweb =
"We currently cannot handle email subscription requests.  Please
use the web interface to subscribe:

  http://www.hebcal.com/email";

my $message = new Mail::Internet \*STDIN;
my $header = $message->head();

my $to = $header->get('To');
if ($to) {
    chomp($to);
    if ($to =~ /^[^<]*<([^>]+)>/) {
	$to = $1;
    }
    if (Email::Valid->address($to)) {
	$to = Email::Valid->address($to);
    } else {
	warn $Email::Valid::Details;
    }
}

my $from = $header->get('From');
if ($from) {
    chomp($from);
    if ($from =~ /^[^<]*<([^>]+)>/) {
	$from = $1;
    }
    if (Email::Valid->address($from)) {
	$from = lc(Email::Valid->address($from));
    } else {
	warn $Email::Valid::Details;
    }
}

unless ($from) {
    &log(0, 'missing_from');
    exit(0);
}

unless (defined $to) {
    &log(0, 'needto');
    &error_email($from,$err_needto);
    exit(0);
}

if ($to =~ /shabbat-subscribe\@hebcal\.com/) {
    &log(0, 'subscribe_useweb'); 
    &error_email($from,$err_useweb);
    exit(0);
} elsif ($to =~ /shabbat-subscribe\+(\d{5})\@hebcal\.com/) {
    &log(0, 'subscribe_useweb');
    &error_email($from,$err_useweb);
    exit(0);
} elsif ($to =~ /shabbat-subscribe\+([^\@]+)\@hebcal\.com/) {
    &subscribe($from,$1);
} elsif ($to =~ /shabbat-unsubscribe\@hebcal\.com/) {
    &unsubscribe($from);
} else {
    &log(0, 'badto');
    &error_email($from,$err_needto);
}
exit(0);

sub subscribe
{
    my($from,$encoded) = @_;

    my(%DB);
    tie(%DB, 'DB_File::Lock', $STAGING, O_CREAT|O_RDWR, 0644, $DB_HASH, 'write')
	or die "$STAGING: $!\n";

    my $args = $DB{$encoded};
    unless ($args) {
	&log(0, 'subscribe_notfound');
	untie(%DB);
	return 0;
    }

    if ($args =~ /^action=/) {
	&log(0, 'subscribe_twice');
	untie(%DB);
	return 0;
    }

    &log(1, 'subscribe');

    my($now) = time;
    $DB{$encoded} = "action=PROCESSED;t=$now";

    untie(%DB);
    undef(%DB);

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

    if (lc($email) ne lc($from)) {
	$newargs .= ";alt=$from";
    }

    tie(%DB, 'DB_File::Lock', $SUBS, O_CREAT|O_RDWR, 0644, $DB_HASH, 'write')
	or die "$SUBS: $!\n";

    $DB{$email} = $newargs;
#    if (lc($email) ne lc($from)) {
#	$DB{$from} = "type=alt;em=$email";
#    }

    untie(%DB);

    my $b64 = encode_base64($email);
    chomp($b64);
    my $unsub_url = "http://www.hebcal.com/email/?" .
	"e=" . &my_url_escape($b64);

    my($body) = qq{Hello,

Your subscription request for hebcal is complete.

Regards,
hebcal.com

To modify your subscription, visit:
$unsub_url

To unsubscribe from this list, send an email to:
shabbat-unsubscribe\@hebcal.com
};

    my $return_path = "shabbat-bounce\@hebcal.com";
    my %headers =
        (
         'From' =>
	 "Hebcal Subscription Notification <shabbat-owner\@hebcal.com>",
         'To' => $email,
         'MIME-Version' => '1.0',
         'Content-Type' => 'text/plain',
         'Subject' => 'Your subscription to hebcal is complete',
	 'List-Unsubscribe' => "<mailto:shabbat-unsubscribe\@hebcal.com>",
	 'Precedence' => 'bulk',
         );

    if ($header) {
	my $mid = $header->get('Message-Id');
	if ($mid) {
	    chomp($mid);
	    $headers{'In-Reply-To'} = $mid;
	}

    }
    &Hebcal::sendmail_v2($return_path,\%headers,$body);
}

sub my_url_escape
{
    my($str) = @_;

    $str =~ s/([^\w\$. -])/sprintf("%%%02X", ord($1))/eg;
    $str =~ s/ /+/g;

    $str;
}

sub unsubscribe
{
    my($email) = @_;

    my(%DB);
    tie(%DB, 'DB_File::Lock', $SUBS, O_CREAT|O_RDWR, 0644, $DB_HASH, 'write')
	or die "$SUBS: $!\n";

    my $args = $DB{$email};
    unless ($args) {
	&log(0, 'unsub_notfound');

	untie(%DB);

	&error_email($email,$err_notsub);
	return 0;
    }

    if ($args =~ /^action=/) {
	&log(0, 'unsub_twice');

	untie(%DB);

	&error_email($email,$err_notsub);
	return 0;
    }

    &log(1, 'unsub');

    my($now) = time;
    $DB{$email} = "action=UNSUBSCRIBE;t=$now";

    untie(%DB);

    my($body) = qq{Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
hebcal.com};

    my $return_path = "shabbat-bounce\@hebcal.com";
    my %headers =
        (
         'From' =>
	 "Hebcal Subscription Notification <shabbat-owner\@hebcal.com>",
         'To' => $email,
         'MIME-Version' => '1.0',
         'Content-Type' => 'text/plain',
         'Subject' => 'You have been unsubscribed from hebcal',
         );

    if ($header) {
	my $mid = $header->get('Message-Id');
	if ($mid) {
	    chomp($mid);
	    $headers{'In-Reply-To'} = $mid;
	}
    }

    &Hebcal::sendmail_v2($return_path,\%headers,$body);
}

sub error_email
{
    my($email,$error) = @_;

    return 0 unless $email;

    while(chomp($error)) {}
    my($body) = qq{Sorry,

We are unable to process the message from <$email>
to <shabbat-unsubscribe\@hebcal.com>.

$error

Regards,
hebcal.com};

    my $return_path = "shabbat-bounce\@hebcal.com";
    my %headers =
        (
         'From' =>
	 "Hebcal Subscription Notification <shabbat-owner\@hebcal.com>",
         'To' => $email,
         'MIME-Version' => '1.0',
         'Content-Type' => 'text/plain',
         'Subject' => 'Unable to process your message',
         );

    if ($header) {
	my $mid = $header->get('Message-Id');
	if ($mid) {
	    chomp($mid);
	    $headers{'In-Reply-To'} = $mid;
	}
    }

    &Hebcal::sendmail_v2($return_path,\%headers,$body);
}

sub log {
    my($status,$code) = @_;
    if (open(LOG, ">>$ENV{'HOME'}/.shabbat-log"))
    {
	my $t = time();
	print LOG "status=$status from=$from to=$to code=$code time=$t\n";
	close(LOG);
    }
}
