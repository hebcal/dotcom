#!/usr/bin/perl -w

use strict;
use DBI ();
use Config::Tiny;
use Amazon::SQS::Simple;
use JSON;

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
my $sql = "INSERT INTO hebcal_shabbat_bounce (email_address,std_reason,full_reason,deactivated) VALUES (?,?,?,0)";
my $sth = $dbh->prepare($sql);

my $access_key = $Config->{_}->{"hebcal.aws.access_key"};
my $secret_key = $Config->{_}->{"hebcal.aws.secret_key"};

my $sqs = new Amazon::SQS::Simple($access_key, $secret_key, Version => '2012-11-05');
my $queue_endpoint = $Config->{_}->{"hebcal.aws.sns.email-bounce.url"};
my $q = $sqs->GetQueue($queue_endpoint);

my $msg = $q->ReceiveMessage();
if ($msg) {
    my $body = $msg->MessageBody();
    my $event = decode_json $body;
    my $innerMsg = $event->{Message};
    if ($innerMsg) {
        my $obj = decode_json $innerMsg;
        if ($obj->{notificationType} && $obj->{notificationType} eq "Bounce" &&
            $obj->{bounce} &&
            $obj->{bounce}->{bounceType} &&
            $obj->{bounce}->{bounceType} eq "Permanent" &&
            $obj->{bounce}->{bouncedRecipients}) {
            my $recip = $obj->{bounce}->{bouncedRecipients}->[0];
            my $email_address = $recip->{emailAddress};
            my $bounce_reason = $recip->{diagnosticCode};
            my $std_reason = "user_disabled";
            $sth->execute($email_address,$std_reason,$bounce_reason)
                or die $dbh->errstr;
        }
    } else {
        warn "Couldn't find Message in JSON payload";
    }
    $q->DeleteMessage($msg);
}

$dbh->disconnect;
exit(0);
