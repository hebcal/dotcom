#!/usr/local/bin/perl -w

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

my $bounce = eval { Mail::DeliveryStatus::BounceParser->new(\*STDIN) };
if ($@) { 
    # couldn't parse.  ignore this message.
    exit(0);
}

my @reports = $bounce->reports;
foreach my $report (@reports) {
    my $to = $report->get('To');
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
	    shabbat_bounce($report,$1);
	}
    }
}

sub shabbat_bounce
{
    my($report,$email) = @_;
    $email =~ s/=/\@/;

    my $reason = $report->get('reason');
    if (! defined($reason)) {
	$reason = $report->get('std_reason');
    }

    my $dbh = DBI->connect($dsn, 'mradwin_hebcal', 'xxxxxxxx');

    my $sql = <<EOD
INSERT INTO hebcal1.hebcal_shabbat_bounce
       (bounce_time, bounce_address, bounce_reason)
VALUES (NOW(),       '$email',       '$reason')
EOD
;
    $dbh->do($sql);
    $dbh->disconnect;
}

