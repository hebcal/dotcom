#!/usr/bin/perl -w

########################################################################
#
# Copyright (c) 2013  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use DBI ();
use Hebcal ();
use Config::Tiny;

my $Config = Config::Tiny->read($Hebcal::CONFIG_INI_PATH)
    or die "$Hebcal::CONFIG_INI_PATH: $!\n";
my $dbhost = $Config->{_}->{"hebcal.mysql.host"};
my $dbuser = $Config->{_}->{"hebcal.mysql.user"};
my $dbpass = $Config->{_}->{"hebcal.mysql.password"};
my $dbname = $Config->{_}->{"hebcal.mysql.dbname"};

my $site = "hebcal.com";
my $dsn = "DBI:mysql:database=$dbname;host=$dbhost";
my $usage = "usage: $0 unsub|bounce email-addr";

sub main() {
    my($op,$addr) = @ARGV;

    $op = lc($op);
    $addr = lc($addr);

    if ($op eq "unsub") {
	unsubscribe($addr, $op, "unsubscribed");
    } elsif ($op eq "bounce") {
	unsubscribe($addr, $op, "bounce");
    } else {
	die "$usage\n";
    }
}

sub unsubscribe($$$)
{
    my($email,$op,$new_status) = @_;

    my $dbh = DBI->connect($dsn, $dbuser, $dbpass);

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

    if ($status eq "unsubscribed") {
	warn "unsub_twice";
	$dbh->disconnect;
	return 0;
    }

    $sql = <<EOD
UPDATE hebcal_shabbat_email
SET email_status='$new_status'
WHERE email_address = '$email'
EOD
;
    $dbh->do($sql);
    $dbh->disconnect;

    shabbat_log(1, $op, $email);
    return unless $op eq "unsub";

    my($body) = qq{Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
$site};

    my %headers =
	(
	 "From" =>
	 "Hebcal Subscription Notification <shabbat-owner\@$site>",
	 "To" => $email,
	 "Content-Type" => "text/plain",
	 "Subject" => "You have been unsubscribed from hebcal",
	 );

    Hebcal::sendmail_v2(Hebcal::shabbat_return_path($email),\%headers,$body);
}


sub shabbat_log
{
    my($status,$code,$to) = @_;
    if (open(LOG, ">>/home/hebcal/local/var/log/subscribers.log"))
    {
	my $t = time();
	print LOG "status=$status to=$to code=$code time=$t\n";
	close(LOG);
    }
}

die "$usage\n" unless @ARGV == 2;
main();
exit(0);
