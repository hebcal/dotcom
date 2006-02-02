#!/usr/local/bin/perl

# no warnings -- Mail::Delivery::BounceParser has tons of undef

########################################################################
#
# $Id$
#
# Copyright (c) 2006  Michael J. Radwin.
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
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
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

eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use DBI ();
use Email::Valid ();
use Mail::DeliveryStatus::BounceParser ();

my $site = "hebcal.com";
my $dsn = "DBI:mysql:database=hebcal1;host=mysql.hebcal.com";

my $message = new Mail::Internet \*STDIN;
my $header = $message->head();
my $to = $header->get("To");

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
	$std_reason = $report->get("std_reason");
	exit(0) if ($std_reason eq "over_quota");
	$bounce_reason = $report->get("reason");
    }
}

$email_address =~ s/\'/\\\'/g;
$bounce_reason =~ s/\'/\\\'/g;
$bounce_reason =~ s/\s+/ /g;

my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

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
    $id = $dbh->{"mysql_insertid"};
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

