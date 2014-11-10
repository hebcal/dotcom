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

eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if 0; # not running under some shell

use strict;
use DBI ();
use Config::Tiny;
use Getopt::Long ();

my $COUNT_DEFAULT = 7;

my $PROG = "shabbat_deactivate.pl";

my $opt_help;
my $opt_dryrun;
my $opt_quiet;
my $opt_count = $COUNT_DEFAULT;

if (!Getopt::Long::GetOptions("help|h" => \$opt_help,
                "count=i" => \$opt_count,
		"quiet" => \$opt_quiet,
                "dryrun|n" => \$opt_dryrun))
{
    Usage();
}

$opt_help && Usage();
@ARGV && Usage();

my $dbh = open_database();
my $addrs = get_candidates($dbh);
deactivate_subs($dbh, $addrs) unless $opt_dryrun;
$dbh->disconnect;
exit(0);

sub Usage
{
    print STDERR <<EOF
Usage:
    $PROG [options]

Options:
  -help         Help
  -dryrun       Prints the actions that $PROG would take
                  but does not remove anything
  -quiet        Quiet mode (do not print commands)
  -count <n>    Threshold is <n> for bounces (default $COUNT_DEFAULT)
EOF
;
    exit(1);
}

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

sub get_candidates {
    my($dbh) = @_;
    my $sql = qq{
	SELECT b.email_address,count(1)
	FROM hebcal_shabbat_email e,
	     hebcal_shabbat_bounce b
	WHERE e.email_address = b.email_address
	AND e.email_status = 'active'
	AND b.std_reason IN('user_unknown',
                        'user_disabled',
                        'domain_error',
                        'amzn_abuse')
	GROUP by b.email_address
    };
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or die "can't execute the query: " . $sth->errstr;

    my @addrs;
    while (my($email,$count) = $sth->fetchrow_array)
    {
	if ($count > $opt_count)
	{
	    print "$email ($count bounces)\n" unless $opt_quiet;
	    push(@addrs, $email);
	}
    }

    return \@addrs;
}

sub deactivate_subs
{
    my($dbh,$addrs) = @_;

    foreach my $e (@{$addrs})
    {
	my $sql = <<EOD
UPDATE hebcal_shabbat_email
SET email_status='bounce'
WHERE email_address = '$e'
EOD
;
	$dbh->do($sql);

	shabbat_log(1, "bounce", $e);
    }
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
