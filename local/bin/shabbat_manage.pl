#!/usr/bin/perl -w

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
    if 0; # not running under some shell

# $Source: /Users/mradwin/hebcal-copy/local/bin/RCS/shabbat_manage.pl,v $
# $Id$

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use strict;
use DBI ();
use Hebcal ();
use Mail::Internet ();
use Email::Valid ();
use MIME::Base64 ();

my $site = "hebcal.com";
my $dsn = "DBI:mysql:database=hebcal1;host=mysql.hebcal.com";

my $err_notsub =
"The email address used to send your message is not subscribed
to the Shabbat candle lighting time list.";
my $err_needto =
"We can't accept Bcc: email messages ($site address missing
from the To: header).";
my $err_useweb =
"We currently cannot handle email subscription requests.  Please
use the web interface to subscribe:

  http://www.$site/email";

my $message = new Mail::Internet \*STDIN;
my $header = $message->head();

my $to = $header->get("To");
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

my $from = $header->get("From");
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
    shabbat_log(0, "missing_from");
    exit(0);
}

unless (defined $to) {
    shabbat_log(0, "needto");
    error_email($from,$err_needto);
    exit(0);
}

if ($to =~ /shabbat-subscribe\@/i) {
    shabbat_log(0, "subscribe_useweb"); 
    error_email($from,$err_useweb);
    exit(0);
} elsif ($to =~ /shabbat-subscribe[\-\+](\d{5})\@/i) {
    shabbat_log(0, "subscribe_useweb");
    error_email($from,$err_useweb);
    exit(0);
} elsif ($to =~ /shabbat-subscribe[\-\+]([^\@]+)\@/i) {
    subscribe($from,lc($1));
} elsif ($to =~ /shabbat-unsubscribe\@/i) {
    unsubscribe($from);
} else {
    shabbat_log(0, "badto");
    error_email($from,$err_needto);
}
exit(0);

sub subscribe
{
    my($from,$encoded) = @_;

    my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

    my $sql = <<EOD
SELECT email_address,email_status
FROM   hebcal_shabbat_email
WHERE  email_id = '$encoded'
EOD
;
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or die "can't execute the query: " . $sth->errstr;
    my($email,$status) = $sth->fetchrow_array;
    $sth->finish;

    unless ($status) {
	shabbat_log(0, "subscribe_notfound");
	$dbh->disconnect;
	return 0;
    }

    if ($status eq "active") {
	shabbat_log(0, "subscribe_twice");
	$dbh->disconnect;
	return 0;
    }

    shabbat_log(1, "subscribe");

    unless ($email) {
	$dbh->disconnect;
	warn "skipping $encoded: no email";
	return 0;
    }

    $sql = <<EOD
UPDATE hebcal1.hebcal_shabbat_email
SET email_status='active'
WHERE email_address = '$email'
EOD
;
    $dbh->do($sql);
    $dbh->disconnect;

    my $b64 = MIME::Base64::encode_base64($email);
    chomp($b64);
    my $unsub_url = "http://www.$site/email/?" .
	"e=" . my_url_escape($b64);

    my($body) = qq{Hello,

Your subscription request for hebcal is complete.

Regards,
$site

To modify your subscription, visit:
$unsub_url

To unsubscribe from this list, send an email to:
shabbat-unsubscribe\@$site
};

    my $email_mangle = $email;
    $email_mangle =~ s/\@/=/g;
    my $return_path = sprintf('shabbat-return-%s@%s', $email_mangle, $site);

    my %headers =
	(
	 "From" =>
	 "Hebcal Subscription Notification <shabbat-owner\@$site>",
	 "To" => $email,
	 "MIME-Version" => "1.0",
	 "Content-Type" => "text/plain",
	 "Subject" => "Your subscription to hebcal is complete",
	 "List-Unsubscribe" => "<mailto:shabbat-unsubscribe\@$site>",
	 "Precedence" => "bulk",
	 );

    if ($header) {
	my $mid = $header->get("Message-Id");
	if ($mid) {
	    chomp($mid);
	    $headers{"In-Reply-To"} = $mid;
	}

    }
    Hebcal::sendmail_v2($return_path,\%headers,$body);
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

    my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

    my $sql = <<EOD
SELECT email_status,email_id
FROM   hebcal_shabbat_email
WHERE  email_address = '$email'
EOD
;
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or die "can't execute the query: " . $sth->errstr;
    my($status,$encoded) = $sth->fetchrow_array;
    $sth->finish;

    unless ($status) {
	shabbat_log(0, "unsub_notfound");

	$dbh->disconnect;

	error_email($email,$err_notsub);
	return 0;
    }

    if ($status eq "unsubscribed") {
	shabbat_log(0, "unsub_twice");

	$dbh->disconnect;

	error_email($email,$err_notsub);
	return 0;
    }

    shabbat_log(1, "unsub");

    $sql = <<EOD
UPDATE hebcal1.hebcal_shabbat_email
SET email_status='unsubscribed'
WHERE email_address = '$email'
EOD
;
    $dbh->do($sql);
    $dbh->disconnect;

    my($body) = qq{Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
$site};

    my $email_mangle = $email;
    $email_mangle =~ s/\@/=/g;
    my $return_path = sprintf('shabbat-return-%s@%s', $email_mangle, $site);

    my %headers =
	(
	 "From" =>
	 "Hebcal Subscription Notification <shabbat-owner\@$site>",
	 "To" => $email,
	 "MIME-Version" => "1.0",
	 "Content-Type" => "text/plain",
	 "Subject" => "You have been unsubscribed from hebcal",
	 );

    if ($header) {
	my $mid = $header->get("Message-Id");
	if ($mid) {
	    chomp($mid);
	    $headers{"In-Reply-To"} = $mid;
	}
    }

    Hebcal::sendmail_v2($return_path,\%headers,$body);
}

sub error_email
{
    my($email,$error) = @_;

    return 0 unless $email;

    my $addr = ($to ? $to : "shabbat-unsubscribe\@$site");
    while(chomp($error)) {}
    my($body) = qq{Sorry,

We are unable to process the message from <$email>
to <$addr>.

$error

Regards,
$site};

    my $return_path = "shabbat-return\@$site";
    my %headers =
	(
	 "From" =>
	 "Hebcal Subscription Notification <shabbat-owner\@$site>",
	 "To" => $email,
	 "MIME-Version" => "1.0",
	 "Content-Type" => "text/plain",
	 "Subject" => "Unable to process your message",
	 );

    if ($header) {
	my $mid = $header->get("Message-Id");
	if ($mid) {
	    chomp($mid);
	    $headers{"In-Reply-To"} = $mid;
	}
    }

    Hebcal::sendmail_v2($return_path,\%headers,$body);
}

sub shabbat_log
{
    my($status,$code) = @_;
    if (open(LOG, ">>$ENV{'HOME'}/.shabbat-log"))
    {
	my $t = time();
	print LOG "status=$status from=$from to=$to code=$code time=$t\n";
	close(LOG);
    }
}


