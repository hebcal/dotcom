#!/usr/local/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2008  Michael J. Radwin.
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

use strict;
use DBI ();
use Getopt::Long ();

my $COUNT_DEFAULT = 7;

my $PROG = "shabbat_deactivate.pl";
my $VER = '$Revision$$';
if ($VER =~ /(\d+)/)
{
    $VER = $1;
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

Version: $PROG r$VER
EOF
;
    exit(1);
}

sub get_candidates
{
    my $site = "hebcal.com";
    my $dsn = "DBI:mysql:database=hebcal5;host=mysql5.hebcal.com";
    my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

    my $sql = qq{
	SELECT DISTINCT a.bounce_address,r.bounce_id,count(r.bounce_id)
	FROM hebcal_shabbat_email e,
	     hebcal_shabbat_bounce_address a,
	     hebcal_shabbat_bounce_reason r
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

    return undef unless @ids;

    foreach my $e (@addrs)
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

    my $id_sql = "bounce_id = '" . shift(@ids) . "'";
    foreach my $id (@ids)
    {
	$id_sql .= " OR bounce_id = '$id'";
    }

    my $sql = "DELETE from hebcal_shabbat_bounce_reason WHERE "
	. $id_sql;
    $dbh->do($sql);

    $sql = "DELETE from hebcal_shabbat_bounce_address WHERE "
	. $id_sql;
    $dbh->do($sql);
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

