#!/usr/bin/perl

eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if 0; # not running under some shell

# $Source: /Users/mradwin/hebcal-copy/local/bin/RCS/shabbat_bounce.pl,v $
# $Id$

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use strict;
use DBI;
use Email::Valid;
use Mail::DeliveryStatus::BounceParser;

my $site = 'hebcal.com';
my $dsn = 'DBI:mysql:database=hebcal1;host=mysql.hebcal.com';

my $message = new Mail::Internet \*STDIN;
my $header = $message->head();
my $to = $header->get('To');

my($email_address,$bounce_reason);
my($std_reason);
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

    if ($to =~ /shabbat-return-([^\@]+)\@/i) {
	$email_address = $1;
	$email_address =~ s/=/\@/;
    }
}

if (!$email_address) {
    die "can't find email address in message";
}

my $bounce = eval { Mail::DeliveryStatus::BounceParser->new($message->as_string()) };
if ($@) { 
    # couldn't parse.  ignore this message.
    warn "bounceparser unable to parse message, bailing";
    exit(0);
} else {
    # don't worry about transient failures with SMTP servers
    exit(0) unless $bounce->is_bounce();

    my @reports = $bounce->reports;
    foreach my $report (@reports) {
	$std_reason = $report->get('std_reason');
	exit(0) if ($std_reason eq 'over_quota');
	$bounce_reason = $report->get('reason');
    }
}

$email_address =~ s/\'/\\\'/g;
$bounce_reason =~ s/\'/\\\'/g;
$bounce_reason =~ s/\s+/ /g;

my $dbh = DBI->connect($dsn, 'mradwin_hebcal', 'xxxxxxxx');

my $sql = <<EOD
SELECT bounce_id
FROM hebcal1.hebcal_shabbat_bounce_address
WHERE hebcal1.hebcal_shabbat_bounce_address.bounce_address = '$email_address'
EOD
;

my($id) = $dbh->selectrow_array($sql);
if (!$id) {
    $sql = <<EOD
INSERT INTO hebcal1.hebcal_shabbat_bounce_address
       (bounce_address, bounce_id, bounce_std_reason)
VALUES ('$email_address', NULL, '$std_reason')
EOD
;
    $dbh->do($sql);
    $id = $dbh->{'mysql_insertid'};
}

$sql = <<EOD
INSERT INTO hebcal1.hebcal_shabbat_bounce_reason
       (bounce_id, bounce_time, bounce_reason)
VALUES ($id, NOW(), '$bounce_reason')
EOD
;
$dbh->do($sql);

$dbh->disconnect;
exit(0);

