#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use strict;
use DB_File::Lock;
use Hebcal;
use POSIX qw(strftime);
use MIME::Base64;

die "usage: $0 {-all | address ...}\n" unless @ARGV;

my($now) = time;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;

my($friday) = &Time::Local::timelocal(0,0,0,
				      $mday,$mon,$year,$wday,$yday,$isdst);
my($saturday) = $now + ((6 - $wday) * 60 * 60 * 24);

my($sat_year) = (localtime($saturday))[5] + 1900;

my $ZIPS =
    &Hebcal::zipcode_open_db('/pub/m/r/mradwin/hebcal.com/email/zips99.db');

my(%SUBS) = &load_subs();

# walk through subs to make sure there are no errors first
while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    &parse_config($cfg);
}

while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    my($cmd,$loc,$args) = &parse_config($cfg);
    my(@events) = &Hebcal::invoke_hebcal($cmd,$loc);

    my $encoded = encode_base64($to);
    chomp($encoded);
    my $unsub_url = "http://www.hebcal.com/email/?" .
	"e=" . &my_url_escape($encoded);

    my($body) = "$loc\n\n"
	. &gen_body(\@events) . qq{
Shabbat Shalom,
hebcal.com

To modify your subscription, visit:
$unsub_url

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
	 'List-Unsubscribe' => "<$unsub_url>",
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

    sleep(2);
}

&Hebcal::zipcode_close_db($ZIPS);
undef($ZIPS);

exit(0);

sub my_url_escape
{
    my($str) = @_;

    $str =~ s/([^\w\$. -])/sprintf("%%%02X", ord($1))/eg;
    $str =~ s/ /+/g;

    $str;
}

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
	    $body .= "  http://www.hebcal.com" .
	      Hebcal::get_holiday_anchor($subj,undef,undef) . "\n";
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
    tie(%DB, 'DB_File::Lock', $dbmfile, O_RDONLY, 0444, $DB_HASH, 'read')
	or die "$dbmfile: $!\n";

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
		if ($DB{$_} =~ /^action=/)
		{
		    warn "$_: $DB{$_}\n";
		    next;
		}
		$subs{$_} = $DB{$_};
	    }
	    else
	    {
		warn "$_: no such user\n";
	    }
	}
    }

    untie(%DB);

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

    my $city_descr;
    if (defined $args{'zip'}) {
	my($zipinfo) = $ZIPS->{$args{'zip'}};
	die "unknown zipcode [$config]" unless defined $zipinfo;
    
	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    &Hebcal::zipcode_fields($zipinfo);

	$city_descr = "$city, $state " . $args{'zip'};
	$city_descr .= "\n" . $Hebcal::tz_names{$args{'tz'}};
	if ($args{'dst'} ne 'usa') {
	    $city_descr .= "\nDST: " . $args{'dst'};
	}

	$cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";

	if (defined $args{'tz'} && $args{'tz'} ne '') {
	    $cmd .= " -z " . $args{'tz'};
	}
	if (defined $args{'dst'} && $args{'dst'} ne '') {
	    $cmd .= " -Z " . $args{'dst'};
	}
    } elsif (defined $args{'city'}) {
	$city_descr = $args{'city'};
	$city_descr =~ s/\+/ /g;
	$cmd .= " -C '" . $city_descr . "'";
    } else {
	die "no geographic key in [$config]";
    }

    $cmd .= " -m " . $args{'m'}
	if (defined $args{'m'} && $args{'m'} =~ /^\d+$/);

    $cmd .= ' -s -c ' . $sat_year;

    ($cmd,$city_descr,\%args);
}

