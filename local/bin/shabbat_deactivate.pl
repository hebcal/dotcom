#!/usr/bin/perl

eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if 0; # not running under some shell

# $Source: /Users/mradwin/hebcal-copy/local/bin/RCS/shabbat_deactivate.pl,v $
# $Id$

use strict;
use DBI ();
use Getopt::Long ();

my $COUNT_DEFAULT = 7;

my $PROG = "shabbat_deactivate.pl";
my $VER = '$Revision$$';
if ($VER =~ /(\d+)\.(\d+)/)
{
    $VER = "$1.$2";
}

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

my @addrs;
my @ids;
my $dbh = get_candidates();
deactivate_subs($dbh) unless $opt_dryrun;
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

Version: $PROG $VER
EOF
;
    exit(1);
}

sub get_candidates
{
    my $site = "hebcal.com";
    my $dsn = "DBI:mysql:database=hebcal1;host=mysql.hebcal.com";
    my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

    my $sql = qq{
	SELECT DISTINCT a.bounce_address,r.bounce_id,count(r.bounce_id)
	FROM hebcal1.hebcal_shabbat_email e,
	     hebcal1.hebcal_shabbat_bounce_address a,
	     hebcal1.hebcal_shabbat_bounce_reason r
	WHERE r.bounce_id = a.bounce_id
	AND a.bounce_address = e.email_address
	AND e.email_status = 'active'
	AND (a.bounce_std_reason = 'user_unknown' OR
	     a.bounce_std_reason = 'domain_error')
	GROUP by a.bounce_address
    };
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or die "can't execute the query: " . $sth->errstr;

    while (my($email,$id,$count) = $sth->fetchrow_array)
    {
	if ($count > $opt_count)
	{
	    print "$email ($count bounces)\n" unless $opt_quiet;
	    push(@addrs, $email);
	    push(@ids, $id);
	}
    }

    $dbh;
}

sub deactivate_subs
{
    my($dbh) = @_;
    foreach my $e (@addrs)
    {
	my $sql = <<EOD
UPDATE hebcal1.hebcal_shabbat_email
SET email_status='bounce'
WHERE email_address = '$e'
EOD
;
	$dbh->do($sql);

	shabbat_log(1, "bounce", $e);
    }

    my $id_sql = "bounce_id = '" . shift(@ids) . "'";
    foreach my $id (@ids)
    {
	$id_sql .= " OR bounce_id = '$id'";
    }

    my $sql = "DELETE from hebcal1.hebcal_shabbat_bounce_reason WHERE "
	. $id_sql;
    $dbh->do($sql);

    $sql = "DELETE from hebcal1.hebcal_shabbat_bounce_address WHERE "
	. $id_sql;
    $dbh->do($sql);
}

sub shabbat_log
{
    my($status,$code,$to) = @_;
    if (open(LOG, ">>$ENV{'HOME'}/local/var/log/subscribers.log"))
    {
	my $t = time();
	print LOG "status=$status to=$to code=$code time=$t\n";
	close(LOG);
    }
}

