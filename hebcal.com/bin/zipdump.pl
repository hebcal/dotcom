#!/usr/local/bin/perl5 -w

use DB_File;

$dbmfile = 'zips.db';
tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";
while (($key,$val) = each(%DB))
{
    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));
    print "$key,$city,$state,$long_deg,$long_min,$lat_deg,$lat_min\n";
}
untie(%DB);
