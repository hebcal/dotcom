#!/usr/local/bin/perl
eval "exec /usr/local/bin/perl -S $0 $*"
    if $running_under_some_shell;

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

    if ($to =~ /shabbat-return-([^\@]+)\@/) {
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
    $bounce_reason = 'unknown (unable to parse message)';
} else {
    my @reports = $bounce->reports;
    foreach my $report (@reports) {
	my $reason = $report->get('reason');
	$bounce_reason = defined($reason) ? $reason : $report->get('std_reason');
    }
}

$email_address =~ s/\'/\\\'/g;
$bounce_reason =~ s/\'/\\\'/g;

my $dbh = DBI->connect($dsn, 'mradwin_hebcal', 'xxxxxxxx');

my $sql = <<EOD
INSERT INTO hebcal1.hebcal_shabbat_bounce
       (bounce_time, bounce_address, bounce_reason)
VALUES (NOW(), '$email_address', '$bounce_reason')
EOD
;

$dbh->do($sql);
$dbh->disconnect;
exit(0);

