#!/usr/local/bin/perl5 -w

use DB_File;

$dbmfile = 'zips.db';
tie(%DB, 'DB_File', $dbmfile, O_RDWR|O_CREAT, 0644, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";

while(<>)
{
    chop;
    ($fips,$zip,$state,$city,$long,$lat,$pop,$alloc) =
	/^"(\d+)","(\d+)","([^\"]+)","([^\"]+)",([^,]+),([^,]+),([^,]+),([^,]+)$/;

    if (! defined $alloc)
    {
	warn "bad line $_\n";
	next;
    }

    die if $city =~ /,/;

    ($long_deg,$long_min) = split(/\./, $long, 2);
    ($lat_deg,$lat_min) = split(/\./, $lat, 2);

    if (defined $long_min && $long_min ne '')
    {
	$long_min = '.' . $long_min;
    }
    else
    {
	$long_min = 0;
    }

    if (defined $lat_min && $lat_min ne '')
    {
	$lat_min = '.' . $lat_min;
    }
    else
    {
	$lat_min = 0;
    }

    $long_min = $long_min * 60;
    $long_min *= -1 if $long_deg < 0;
    $long_min = sprintf("%.0f", $long_min);

    $lat_min = $lat_min * 60;
    $lat_min *= -1 if $lat_deg < 0;
    $lat_min = sprintf("%.0f", $lat_min);

    $DB{$zip} = pack('ncnc',$long_deg,$long_min,$lat_deg,$lat_min) .
	$city . "\0" . $state;
}
untie(%DB);

if ($^W)
{
    $pop = $alloc = $fips;	# touch variables to avoid warning
}

exit(0);
