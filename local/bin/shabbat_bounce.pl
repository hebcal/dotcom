#!/usr/bin/perl

# no warnings -- Mail::Delivery::BounceParser has tons of undef

########################################################################
#
# Copyright (c) 2014  Michael J. Radwin.
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
use Email::Valid ();
use Mail::DeliveryStatus::BounceParser ();
use Config::Tiny;

my $message = new Mail::Internet \*STDIN;
my $header = $message->head();

my($email_address,$bounce_reason);
my($std_reason);

$email_address = extract_return_addr($header->get("Delivered-To"));
$email_address ||= extract_return_addr($header->get("To"));

if (!$email_address) {
    die "can't find email address in message";
}

my $daemon_from = $header->get("From");
chomp($daemon_from);
if ($daemon_from eq 'complaints@email-abuse.amazonses.com') {
    $bounce_reason = $std_reason = "amzn_abuse";
} else {
    my $bounce = eval { Mail::DeliveryStatus::BounceParser->new($message->as_string()) };
    if ($@) {
        $bounce_reason = $std_reason = "parse_fail";
    } else {
        if ($bounce->is_bounce()) {
            my @reports = $bounce->reports;
            foreach my $report (@reports) {
                $std_reason = $report->get("std_reason");
                $bounce_reason = $report->get("reason");
            }
        } else {
            $bounce_reason = $std_reason = "transient_fail";
        }
    }
}

if ($bounce_reason) {
    $bounce_reason =~ s/\s+/ /g;
}

if (open(LOG, ">>/home/hebcal/local/var/log/bounce.log")) {
    my $t = time();
    print LOG "from=$email_address time=$t std_reason=$std_reason\n";
    close(LOG);
}

my $dbh = open_database();
my $sql = "INSERT INTO hebcal_shabbat_bounce (email_address,std_reason,full_reason) VALUES (?,?,?)";
my $sth = $dbh->prepare($sql);
$sth->execute($email_address,$std_reason,$bounce_reason)
    or die $dbh->errstr;

$dbh->disconnect;
exit(0);

sub open_database {
    my $ini_path = "/home/hebcal/local/etc/hebcal-dot-com.ini";
    my $Config = Config::Tiny->read($ini_path)
        or die "$ini_path: $!\n";
    my $dbhost = $Config->{_}->{"hebcal.mysql.host"};
    my $dbuser = $Config->{_}->{"hebcal.mysql.user"};
    my $dbpass = $Config->{_}->{"hebcal.mysql.password"};
    my $dbname = $Config->{_}->{"hebcal.mysql.dbname"};

    my $dsn = "DBI:mysql:database=$dbname;host=$dbhost";
    my $dbh = DBI->connect($dsn, $dbuser, $dbpass)
        or die "DB Connection not made: $DBI::errstr";

    return $dbh;
}

sub extract_return_addr {
    my($to) = @_;
    my $email_address;

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

        if ($to =~ /shabbat-return(?:[-+])([^\@]+)\@/i) {
            $email_address = $1;
            $email_address =~ s/=/\@/;
        }
    }

    $email_address;
}
