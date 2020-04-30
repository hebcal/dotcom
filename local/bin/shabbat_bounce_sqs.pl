#!/usr/bin/perl -w

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use DBI ();
use Hebcal ();
use Config::Tiny;
use Amazon::SQS::Simple;
use Mail::DeliveryStatus::BounceParser;
use Email::Valid;
use JSON;
use Getopt::Long ();
use Carp;
use Log::Log4perl qw(:easy);
use Fcntl qw(:flock);

my $opt_help;
my $opt_verbose = 0;
my $opt_log = 1;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "log!" => \$opt_log,
     "verbose|v+" => \$opt_verbose)) {
    usage();
}

$opt_help && usage();

my $loglevel;
if ($opt_verbose == 0) {
    $loglevel = $WARN;
} elsif ($opt_verbose == 1) {
    $loglevel = $INFO;
} else {
    $loglevel = $DEBUG;
}
# Just log to STDERR
Log::Log4perl->easy_init($loglevel);

my $lockfilename = "/tmp/hebcal-shabbat-bounce.lock";
open(my $lockfile, ">", $lockfilename)
    or LOGDIE("Can't open $lockfilename: $!");

if (!flock($lockfile, LOCK_EX)) {
    WARN("Unable to acquire lock: $!");
    exit(1);
}

my $site = "hebcal.com";

if ($opt_log) {
    my $HOME = "/home/hebcal";
    my $now = time;
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($now);
    $year += 1900;
    my $logfile = sprintf("%s/local/var/log/bounce-%04d-%02d.log",
                          $HOME, $year, $mon + 1);
    open(LOG, ">>$logfile") || LOGCROAK "$logfile: $!";
    select LOG;
    $| = 1;
    select STDOUT;
}

my $ini_path = "/home/hebcal/local/etc/hebcal-dot-com.ini";
my $Config = Config::Tiny->read($ini_path)
    or LOGDIE("$ini_path: $!");
my $dbhost = $Config->{_}->{"hebcal.mysql.host"};
my $dbuser = $Config->{_}->{"hebcal.mysql.user"};
my $dbpass = $Config->{_}->{"hebcal.mysql.password"};
my $dbname = $Config->{_}->{"hebcal.mysql.dbname"};

my $dsn = "DBI:mysql:database=$dbname;host=$dbhost";
DEBUG("Connecting to $dsn");
my $dbh = DBI->connect($dsn, $dbuser, $dbpass)
    or LOGDIE("DB Connection not made: $DBI::errstr");
my $sql = "INSERT INTO hebcal_shabbat_bounce (email_address,std_reason,full_reason,deactivated) VALUES (?,?,?,0)";
my $sth = $dbh->prepare($sql);

my $access_key = $Config->{_}->{"hebcal.aws.access_key"};
my $secret_key = $Config->{_}->{"hebcal.aws.secret_key"};

my $SNS_BOUNCE_INI = "hebcal.aws.sns.email-bounce.url";
my $queue_endpoint = $Config->{_}->{$SNS_BOUNCE_INI};
if (!$queue_endpoint) {
    LOGDIE("Required key '$SNS_BOUNCE_INI' missing from $ini_path");
}

my $SNS_UNSUB_INI = "hebcal.aws.sns.email-unsub.url";
my $unsub_endpoint = $Config->{_}->{$SNS_UNSUB_INI};
if (!$unsub_endpoint) {
    LOGDIE("Required key '$SNS_UNSUB_INI' missing from $ini_path");
}

INFO("Fetching bounces from $queue_endpoint");
my $sqs = new Amazon::SQS::Simple($access_key, $secret_key, Version => '2012-11-05');
my $q = $sqs->GetQueue($queue_endpoint)
    or LOGDIE("SQS GetQueue $queue_endpoint failed: $!");

my $total = 0;
my $count = 0;
my @messages;
do {
    @messages = $q->ReceiveMessageBatch;
    $total += scalar @messages;
    foreach my $msg (@messages) {
        my $body = $msg->MessageBody();
        DEBUG($body);
        my $event = decode_json $body;
        my $innerMsg = $event->{Message};
        if ($innerMsg) {
            if ($opt_log) {
                print LOG $innerMsg, "\n";
            }
            my $obj = decode_json $innerMsg;
            if (!$obj->{notificationType}) {
                WARN("MISSING notificationType $innerMsg");
                next;
            }
            if ($obj->{notificationType} eq 'Bounce') {
                my $recip = $obj->{bounce}->{bouncedRecipients}->[0];
                my $email_address = $recip->{emailAddress};
                my $bounce_reason = $recip->{diagnosticCode};
                my $bounce_type = $obj->{bounce}->{bounceType};
                my $std_reason;
                if ($bounce_reason) {
                    $std_reason = get_std_reason($bounce_reason);
                } else {
                    $std_reason = $bounce_type;
                }
                if ($std_reason eq "unknown" && $bounce_type eq "Transient") {
                    $std_reason = $bounce_type;
                }
                INFO("$email_address $std_reason");
                $sth->execute($email_address,$std_reason,$bounce_reason)
                    or LOGDIE($dbh->errstr);
                $count++;
            } elsif ($obj->{notificationType} eq 'Complaint') {
                my $recip = $obj->{complaint}->{complainedRecipients}->[0];
                my $email_address = $recip->{emailAddress};
                my $std_reason = "amzn_abuse";
                INFO("$email_address $std_reason");
                $sth->execute($email_address,$std_reason,$std_reason)
                    or LOGDIE($dbh->errstr);
                $count++;
            } else {
                WARN("UNKNOWN notificationType $innerMsg");                
            }
        } else {
            WARN("Couldn't find Message in JSON payload");
        }
    }
    if (@messages) {
        $q->DeleteMessageBatch(\@messages);
    }
} while (@messages);
undef $q;
INFO("Processed $count of $total bounces");

INFO("Fetching unsubs from $unsub_endpoint");
$q = $sqs->GetQueue($unsub_endpoint)
    or LOGDIE("SQS GetQueue $unsub_endpoint failed: $!");
$total = 0;
$count = 0;
do {
    @messages = $q->ReceiveMessageBatch;
    $total += scalar @messages;
    foreach my $msg (@messages) {
        my $body = $msg->MessageBody();
        DEBUG($body);
        my $event = decode_json $body;
        my $innerMsg = $event->{Message};
        if ($innerMsg) {
            if ($opt_log) {
                print LOG $innerMsg, "\n";
            }
            my $obj = decode_json $innerMsg;
            if (!$obj->{notificationType}) {
                WARN("MISSING notificationType $innerMsg");
                next;
            }
            if ($obj->{notificationType} eq 'Received') {
                my $source = $obj->{mail}->{source};
                my $destination = $obj->{mail}->{destination}->[0];
                my $commonHeaders = $obj->{mail}->{commonHeaders};
                if ($commonHeaders) {
                    my $from = $commonHeaders->{from};
                    if ($from && $from->[0]) {
                        $from = $from->[0];
                        if ($from =~ /^[^<]*<([^>]+)>/) {
                            $from = $1;
                        }
                        my $addr = Email::Valid->address($from);
                        if ($addr) {
                            $addr = lc($addr);
                            DEBUG("Replacing $source with actual $addr");
                            $source = $addr;
                        } else {
                            WARN("Invalid address '$from': $Email::Valid::Details");
                        }
                    }
                }
                INFO("unsub $source $destination");
                if ($destination =~ /^shabbat-unsubscribe\+(\w+)\@hebcal.com$/) {
                    my $email_id = $1;
                    unsubscribe($dbh,$source,$destination,$email_id);
                } else {
                    unsubscribe($dbh,$source,$destination,undef);
                }
                $count++;
            }
        } else {
            WARN("MISSING Message");
            next;
        }
    }
    if (@messages) {
        $q->DeleteMessageBatch(\@messages);
    }
} while (@messages);
INFO("Processed $count of $total unsubscribes");


$dbh->disconnect;

close(LOG) if $opt_log;

flock($lockfile, LOCK_UN);              # ignore failures

INFO("Success!");

exit(0);

sub usage {
    die "usage: $0 {-verbose|-nolog}\n";
}

# Mail::DeliveryStatus::BounceParser
sub get_std_reason {
    my($full_reason) = @_;
    return "unknown" unless defined $full_reason;
    if ($full_reason =~ /\s(5\.\d+\.\d+)\s/) {
        my $status = $1;
        if ($status =~ /^5\.1\.[01]$/)  {
            return "user_unknown";
        } elsif ($status eq "5.1.2") {
            return "domain_error";
        } elsif ($status eq "5.2.1") {
            return "user_disabled";
        } elsif ($status eq "5.2.2") {
            return "over_quota";
        } elsif ($status eq "5.4.4") {
            return "domain_error";
        } else {
            return Mail::DeliveryStatus::BounceParser::_std_reason($full_reason);
        }
    } elsif ($full_reason =~ /^Amazon SES has suppressed sending to this address/) {
        return "user_disabled";
    } else {
        return "unknown";
    }
}

sub shabbat_log {
    my($status,$code,$from,$to) = @_;
    if (open(LOG2, ">>/home/hebcal/local/var/log/subscribers.log")) {
        my $t = time();
        print LOG2 "status=$status from=$from to=$to code=$code time=$t\n";
        close(LOG2);
    }
}

sub unsubscribe {
    my($dbh,$email,$to,$email_id) = @_;

    my $sql = "SELECT email_status,email_id FROM hebcal_shabbat_email";
    if ($email_id) {
        $sql .= " WHERE email_id = '$email_id'";
    } else {
        $sql .= " WHERE email_address = '$email'";
    }
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
        or die "can't execute the query: " . $sth->errstr;
    my($status,$encoded) = $sth->fetchrow_array;
    $sth->finish;

    unless ($status) {
        shabbat_log(0, "unsub_notfound", $email, $to);
        error_email($email, $to);
        return 0;
    }

    if ($status eq "unsubscribed") {
        shabbat_log(0, "unsub_twice", $email, $to);
        error_email($email, $to);
        return 0;
    }

    shabbat_log(1, "unsub", $email, $to);

    $sql = <<EOD
UPDATE hebcal_shabbat_email
SET email_status='unsubscribed'
WHERE email_id = '$encoded'
EOD
;
    $dbh->do($sql);

    my $body = qq{Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
$site};

    my %headers = (
     "From" =>
     "Hebcal <shabbat-owner\@$site>",
     "To" => $email,
     "Content-Type" => "text/plain",
     "Subject" => "You have been unsubscribed from hebcal",
     );

    Hebcal::sendmail_v2(Hebcal::shabbat_return_path($email),\%headers,$body,$opt_verbose)
        or LOGWARN("Mail to $email failed: $@");

}

sub error_email {
    my($email,$to) = @_;

    my $addr = $to || "shabbat-unsubscribe\@$site";

    my $body = qq{Sorry,

We are unable to process the message from <$email>
to <$addr>.

The email address used to send your message is not subscribed
to the Shabbat candle lighting time list.

Regards,
$site};

    my %headers = (
     "From" =>
     "Hebcal <shabbat-owner\@$site>",
     "To" => $email,
     "Content-Type" => "text/plain",
     "Subject" => "Unable to process your message",
     );

    Hebcal::sendmail_v2(Hebcal::shabbat_return_path($email),\%headers,$body,$opt_verbose)
        or LOGWARN("Mail to $email failed: $@");
}

