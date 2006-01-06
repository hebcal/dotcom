#!/usr/local/bin/perl -w

# $Source: /Users/mradwin/hebcal-copy/local/bin/RCS/shabbat_weekly.pl,v $
# $Id$

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use strict;
use Hebcal ();
use POSIX qw(strftime);
use MIME::Base64 ();
use Time::Local ();
use DBI ();
use Net::SMTP ();

die "usage: $0 {-all | address ...}\n" unless @ARGV;

my $VERSION = '$Revision$$';
if ($VERSION =~ /(\d+)\.(\d+)/) {
    $VERSION = "$1.$2";
}

my($LOGIN) = getlogin() || getpwuid($<) || "UNKNOWN";

my $now = time;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;

my $friday = Time::Local::timelocal(0,0,0,$mday,$mon,$year,$wday,$yday,$isdst);
my $saturday = $now + ((6 - $wday) * 60 * 60 * 24);
my $sat_year = (localtime($saturday))[5] + 1900;
my $subject = strftime("[shabbat] %b %d",
		       localtime($now + ((5 - $wday) * 60 * 60 * 24)));

my $ZIPS = Hebcal::zipcode_open_db("/home/mradwin/web/hebcal.com/hebcal/zips99.db");

my(%SUBS) = load_subs();
if (! keys(%SUBS) && ($ARGV[0] ne "-all")) {
    die "$ARGV[0]: not found.\n";
}

# walk through subs to make sure there are no errors first
while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    parse_config($cfg);
}

my $logfile = sprintf("%s/local/var/log/shabbat-%04d%02d%02d",
		      $ENV{"HOME"}, $year, $mon+1, $mday);
open(LOG, ">>$logfile") || die "$logfile: $!";

my $smtp = smtp_connect("mail.hebcal.com");
$smtp || die "Can't connect to SMTP server";

my $HOSTNAME = `/bin/hostname -f`;
chomp($HOSTNAME);
$smtp->hello($HOSTNAME);

while (my($to,$cfg) = each(%SUBS))
{
    next if $cfg =~ /^action=/;
    next if $cfg =~ /^type=alt/;
    my($cmd,$loc,$args) = parse_config($cfg);
    my @events = Hebcal::invoke_hebcal("$cmd $sat_year","",undef);
    if ($sat_year != $year) {
	# Happens when Friday is Dec 31st and Sat is Jan 1st
	my @ev2 = Hebcal::invoke_hebcal("$cmd 12 $year","",undef);
	@events = (@ev2, @events);
    }

    my $encoded = MIME::Base64::encode_base64($to);
    chomp($encoded);
    my $unsub_url = "http://www.hebcal.com/email/?" .
	"e=" . my_url_escape($encoded);

    my($body) = gen_body(\@events) . qq{
$loc

Shabbat Shalom,
hebcal.com

To modify your subscription or to unsubscribe completely, visit:
$unsub_url
};

    my $email_mangle = $to;
    $email_mangle =~ s/\@/=/g;
    my $return_path = sprintf('shabbat-return-%s@hebcal.com', $email_mangle);

    my $lighting = get_friday_candles(\@events);
    my $msgid = $args->{"id"} . "." . time();

    my %headers =
	(
	 "From" => "Hebcal <shabbat-owner\@hebcal.com>",
	 "To" => $to,
	 "MIME-Version" => "1.0",
	 "Content-Type" => "text/plain",
	 "Subject" => "$subject Candles $lighting",
	 "List-Unsubscribe" => "<$unsub_url&unsubscribe=1&v=1>",
	 "Errors-To" => $return_path,
	 "Precedence" => "bulk",
	 "Message-ID" => "<$msgid\@hebcal.com>",
	 );

    # try 3 times to avoid intermittent failures
    my $status = 0;
    for (my $i = 0; $status == 0 && $i < 3; $i++)
    {
	$status = my_sendmail($smtp,$return_path,\%headers,$body,1);
	sleep(1);

	if ($status == 0)
	{
	    $smtp->quit;
	    $smtp = smtp_connect("mail.hebcal.com");
	    $smtp || die "Can't reconnect to SMTP server";
	}
    }

    print LOG join(":", $msgid, $status, $to,
		   defined $args->{"zip"} 
		   ? $args->{"zip"} : $args->{"city"}), "\n";
}

close(LOG);

$smtp->quit();
undef $smtp;

Hebcal::zipcode_close_db($ZIPS);
undef($ZIPS);

exit(0);

sub my_url_escape
{
    my($str) = @_;

    $str =~ s/([^\w\$. -])/sprintf("%%%02X", ord($1))/eg;
    $str =~ s/ /+/g;

    $str;
}

sub get_friday_candles
{
    my($events) = @_;
    my($numEntries) = scalar(@{$events});
    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($time) = Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       "","","");
	next if $time < $friday || $time > $saturday;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	if ($subj eq "Candle lighting")
	{
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    $hour -= 12 if $hour > 12;

	    return sprintf("%d:%02dpm", $hour, $min);
	}
    }

    return "";
}

sub gen_body
{
    my($events) = @_;

    my $body = "";

    my($numEntries) = scalar(@{$events});
    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	# holiday is at 12:00:01 am
	my($time) = Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       "","","");
	next if $time < $friday || $time > $saturday;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($year) = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $strtime = strftime("%A, %d %B %Y", localtime($time));

	if ($subj eq "Candle lighting" || $subj =~ /Havdalah/)
	{
	    $body .= sprintf("%s for %s is at %d:%02dpm\n",
			     $subj, $strtime, $hour, $min);
	}
	elsif ($subj eq "No sunset today.")
	{
	    $body .= "No sunset on $strtime\n";
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

    my $dsn = "DBI:mysql:database=hebcal1;host=mysql.hebcal.com";
    my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

    my $all_sql = "";
    if ($ARGV[0] ne "-all") {
	$all_sql = "AND email_address IN ('" . join("','", @ARGV) . "')";
    }

    my $sql = <<EOD
SELECT email_address,
       email_id,
       email_candles_zipcode,
       email_candles_city,
       email_candles_havdalah
FROM hebcal1.hebcal_shabbat_email
WHERE hebcal1.hebcal_shabbat_email.email_status = 'active'
$all_sql
EOD
;

    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
	or die "can't execute the query: " . $sth->errstr;
    while (my($email,$id,$zip,$city,$havdalah) = $sth->fetchrow_array) {
	my $cfg = "id=$id;m=$havdalah";
	if ($zip) {
	    $cfg .= ";zip=$zip";
	} elsif ($city) {
	    $cfg .= ";city=$city";
	}
	$subs{$email} = $cfg;
    }

    $dbh->disconnect;
    %subs;
}

sub parse_config
{
    my($config) = @_;

    my($cmd) = "/home/mradwin/web/hebcal.com/bin/hebcal";

    my %args;
    foreach my $kv (split(/;/, $config)) {
	my($key,$val) = split(/=/, $kv, 2);
	$args{$key} = $val;
    }

    my $city_descr;
    if (defined $args{"zip"}) {
	my($zipinfo) = $ZIPS->{$args{"zip"}};
	die "unknown zipcode [$config]" unless defined $zipinfo;
    
	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    Hebcal::zipcode_fields($zipinfo);

	$city_descr = "These times are for:";
	$city_descr .= "\n  $city, $state " . $args{"zip"};
	$city_descr .= "\n  " . $Hebcal::tz_names{$tz};

	if (defined $tz && $tz ne "?") {
	    $cmd .= " -z $tz";
	}

	if ($dst == 1) {
	    $cmd .= " -Z usa";
	} elsif ($dst == 0) {
	    $cmd .= " -Z none";
	}

	$cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    } elsif (defined $args{"city"}) {
	$city_descr = $args{"city"};
	$city_descr =~ s/\+/ /g;
	$cmd .= " -C '" . $city_descr . "'";
	$cmd .= " -i"
	    if ($Hebcal::city_dst{$city_descr} eq "israel");
	$city_descr = "These times are for $city_descr.";
    } else {
	die "no geographic key in [$config]";
    }

    $cmd .= " -m " . $args{"m"}
	if (defined $args{"m"} && $args{"m"} =~ /^\d+$/);

    $cmd .= " -s -c";

    ($cmd,$city_descr,\%args);
}

sub smtp_connect
{
    my($s) = @_;

    # try 3 times to avoid intermittent failures
    for (my $i = 0; $i < 3; $i++)
    {
	my $smtp = Net::SMTP->new($s, Timeout => 20);
	if ($smtp)
	{
	    return $smtp;
	}
	else
	{
	    my $sec = 5;
	    warn "Could not connect to $s, retry in $sec seconds\n";
	    sleep($sec);
	}
    }
    
    undef;
}

sub my_sendmail
{
    my($smtp,$return_path,$headers,$body,$verbose) = @_;
    
    $headers->{"X-Sender"} = "$LOGIN\@$HOSTNAME";
    $headers->{"X-Mailer"} = "hebcal mail v$VERSION";

    my $message = "";
    while (my($key,$val) = each %{$headers})
    {
	while (chomp($val)) {}
	$message .= "$key: $val\n";
    }
    $message .= "\n" . $body;

    my $to = $headers->{"To"};
    unless ($smtp->mail($return_path)) {
        warn "smtp mail() failure for $to\n"
	    if $verbose;
        return 0;
    }

    unless($smtp->to($to)) {
	warn "smtp to() failure for $to\n"
	    if $verbose;
	return 0;
    }

    unless($smtp->data()) {
        warn "smtp data() failure for $to\n"
	    if $verbose;
        return 0;
    }

    unless($smtp->datasend($message)) {
        warn "smtp datasend() failure for $to\n"
	    if $verbose;
        return 0;
    }

    unless($smtp->dataend()) {
        warn "smtp dataend() failure for $to\n"
	    if $verbose;
        return 0;
    }

    1;
}

