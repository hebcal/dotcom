#!/usr/local/bin/perl5 -w

require HTTP::Request;
require LWP::UserAgent;
use DB_File;
use URI::Escape;

$dbmfile = @ARGV ? $ARGV[0] : 'zips.db';
tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";

my($dbf) =
tie(%failure, 'DB_File', "failure.db", O_RDWR|O_CREAT, 0644, $DB_File::DB_HASH)
    || die "Can't tie failure.db: $!\n";

my($dbs) =
tie(%success, 'DB_File', "success.db", O_RDWR|O_CREAT, 0644, $DB_File::DB_HASH)
    || die "Can't tie success.db: $!\n";

@need = ();
for ($i = 0; $i <= 99999; $i++)
{
    $z = sprintf("%05d", $i);

    push(@need, $z)
	unless defined $DB{$z} || defined $failure{$z} || defined $success{$z};
}

$ua = LWP::UserAgent->new;

foreach $z (@need)
{
    $url = "http://maps.yahoo.com/py/maps.py?&csz=$z";
    warn "$url\n";
    $request = HTTP::Request->new(GET => $url);
    $response = $ua->request($request);

    if ($response->is_success) {
	if ($response->content =~
	    m,/py/pmap.py\?Pyt=Tmap\&addr=\&city=([^\&]+)\&state=(\w\w)\&slt=([^\&]+)\&sln=([^\&]+)\&zip=,) {
	    ($city,$state,$slt,$sln) = ($1,$2,$3,$4);

	    $city  =~ s/\+/ /g;
	    $state =~ s/\+/ /g;
	    $slt   =~ s/\+/ /g;
	    $sln   =~ s/\+/ /g;

	    $city  =~ uri_unescape($city);
	    $state =~ uri_unescape($state);
	    $slt   =~ uri_unescape($slt);
	    $sln   =~ uri_unescape($sln);

	    # check for dummy center-of-USA lat/long
	    if ($slt eq '39.5276' && $sln eq '-99.1420')
	    {
		$failure{$z} = 'b';
		$dbf->sync;
		next;
	    }

	    $sln =~ s/^-//;
	    $city = "\U$city\E";
	    $success{$z} =
		"\"00\",\"$z\",\"$state\",\"$city\",$sln,$slt,0,0";
	    $dbs->sync;
	    print $success{$z}, "\n";
	} else {
	    $failure{$z} = 1;
	    $dbf->sync;
	}
    } else {
	warn $response->error_as_HTML();
    }
}

undef($dbf);
undef($dbs);

untie(%DB);
untie(%failure);
untie(%success);
exit(0);
