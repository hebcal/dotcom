#!/usr/local/bin/perl -w

use lib "/home/mradwin/local/lib/perl5/site_perl";

use strict;
use DB_File;
use Fcntl qw(:DEFAULT :flock);
use Hebcal;
use POSIX qw(strftime);

die "usage: $0 {-all | address ...}\n" unless @ARGV;

my($now) = time;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;

my($friday) = &Time::Local::timelocal(0,0,0,
				      $mday,$mon,$year,$wday,$yday,$isdst);
my($saturday) = $now + ((6 - $wday) * 60 * 60 * 24);

my($sat_year) = (localtime($saturday))[5] + 1900;

my($zips_dbmfile) = '/pub/m/r/mradwin/hebcal.com/email/zips.db';
my(%ZIPS);
tie(%ZIPS, 'DB_File', $zips_dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
    || die "Can't tie $zips_dbmfile: $!\n";

my(%SUBS) = &load_subs();

while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    my($cmd,$loc) = &parse_config($cfg);
    my(@events) = &Hebcal::invoke_hebcal($cmd,$loc);

    my($body) = "$loc\n\n"
	. &gen_body(\@events) . qq{
Regards,
hebcal.com

To unsubscribe from this list, send an email to:
shabbat-unsubscribe\@hebcal.com
};

    my($fri) = $now + ((5 - $wday) * 60 * 60 * 24);

    my($return_path) = "shabbat-bounce\@hebcal.com";
    my %headers =
        (
         'From' => "Hebcal <shabbat-owner\@hebcal.com>",
         'To' => $to,
         'MIME-Version' => '1.0',
         'Content-Type' => 'text/plain',
         'Subject' =>
	 strftime("[shabbat] %b %d Candle lighting", localtime($fri)),
	 'List-Unsubscribe' => "<mailto:shabbat-unsubscribe\@hebcal.com>",
	 'Precedence' => 'bulk',
         );

    # try 3 times to avoid intermittent failures
    my($i);
    my($status) = 0;
    for ($i = 0; $status == 0 && $i < 3; $i++)
    {
	$status = &Hebcal::sendmail_v2($return_path,\%headers,$body);
    }

    warn "$0: unable to email $to\n"
	if ($status == 0);
}

untie(%ZIPS);
exit(0);

sub gen_body
{
    my($events) = @_;

    my $body = '';

    my($numEntries) = scalar(@{$events});
    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	# holiday is at 12:00:01 am
	my($time) = &Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
	next if $time < $friday || $time > $saturday;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($year) = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $strtime = strftime("%A, %d %B %Y", localtime($time));

	if ($subj eq 'Candle lighting' || $subj =~ /Havdalah/)
	{
	    $body .= sprintf("%s for %s is at %d:%02d PM\n",
			     $subj, $strtime, $hour, $min);
	}
	elsif ($subj =~ /^(Parshas|Parashat)\s+/)
	{
	    $body .= "This week's Torah portion is $subj\n";
	}
	else
	{
	    $body .= "Holiday: $subj on $strtime\n";
	}
    }

    $body;
}

sub load_subs
{
    my(%subs);

    my($dbmfile) = '/pub/m/r/mradwin/hebcal.com/email/subs.db';
    my(%DB);
    my($db) = tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444,
		  $DB_File::DB_HASH)
	or die "$dbmfile: $!\n";

    my($fd) = $db->fd;
    open(DB_FH, "<&=$fd") || die "dup $!";
    unless (flock (DB_FH, LOCK_SH)) { die "flock: $!" }

    if ($ARGV[0] eq '-all')
    {
	%subs = %DB;
    }
    else
    {
	foreach (@ARGV)
	{
	    if (defined $DB{$_})
	    {
		$subs{$_} = $DB{$_};
	    }
	    else
	    {
		warn "$_: no such user\n";
	    }
	}
    }

    flock(DB_FH, LOCK_UN);
    undef $db;
    undef $fd;
    untie(%DB);
    close(DB_FH);

    %subs;
}

sub parse_config
{
    my($config) = @_;

    my($cmd) = '/home/mradwin/local/bin/hebcal';

    my %args;
    foreach my $kv (split(/;/, $config)) {
	my($key,$val) = split(/=/, $kv, 2);
	$args{$key} = $val;
    }

    my($zipinfo) = $ZIPS{$args{'zip'}};
    my($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $zipinfo);
    my($city,$state) = split(/\0/, substr($zipinfo,6));

    my(@city) = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = lc($_);
	$_ = "\u$_";		# inital cap
	$city .= $_;
    }

    my $city_descr = "$city, $state " . $args{'zip'};
    $city_descr .= "\n" . $Hebcal::tz_names{$args{'tz'}};
    $city_descr .= "\nDST: " . $args{'dst'}
	if $args{'dst'} ne 'usa';

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";

    $cmd .= " -z " . $args{'tz'}
	if (defined $args{'tz'} && $args{'tz'} ne '');
    $cmd .= " -Z " . $args{'dst'}
	if (defined $args{'dst'} && $args{'dst'} ne '');
    $cmd .= " -m " . $args{'m'}
	if (defined $args{'m'} && $args{'m'} =~ /^\d+$/);

    $cmd .= ' -s -c ' . $sat_year;

    ($cmd,$city_descr);
}

