#!/usr/local/bin/perl -w

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use strict;
use DBI ();
use Hebcal ();

my $site = 'hebcal.com';
my $dsn = 'DBI:mysql:database=hebcal1;host=mysql.hebcal.com';

sub main() {
    my($op,$addr) = @ARGV;

    my $usage = "usage: $0 unsub email-addr";

    if (!defined $op) {
	die "$usage\n";
    } elsif ($op =~ /^unsub/i && $addr) {
	unsubscribe(lc($addr));
    } else {
	die "$usage\n";
    }
}

sub unsubscribe($)
{
    my($email) = @_;

    my $dbh = DBI->connect($dsn, 'mradwin_hebcal', 'xxxxxxxx');

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
	warn "unsub_notfound";
	$dbh->disconnect;
	return 0;
    }

    if ($status eq 'unsubscribed') {
	warn "unsub_twice";
	$dbh->disconnect;
	return 0;
    }

    shabbat_log(1, 'unsub', $email);

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
         'From' =>
	 "Hebcal Subscription Notification <shabbat-owner\@$site>",
         'To' => $email,
         'MIME-Version' => '1.0',
         'Content-Type' => 'text/plain',
         'Subject' => 'You have been unsubscribed from hebcal',
         );

    Hebcal::sendmail_v2($return_path,\%headers,$body);
}


sub shabbat_log
{
    my($status,$code,$to) = @_;
    if (open(LOG, ">>$ENV{'HOME'}/.shabbat-log"))
    {
	my $t = time();
	print LOG "status=$status to=$to code=$code time=$t\n";
	close(LOG);
    }
}

main();
exit(0);

