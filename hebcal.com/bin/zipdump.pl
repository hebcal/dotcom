#!/usr/local/bin/perl -w

use DB_File;

$dbmfile = @ARGV ? $ARGV[0] : 'zips.db';
tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";
while (($key,$val) = each(%DB))
{
    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));

    # "00","14863","NY","MECKLENBURG",76.7102,42.4576,0,0

    # "01","35020","AL","BESSEMER",86.947547,33.409002,40549,0.010035 

    
    $long = sprintf("%.6g", $long_deg + ($long_min / 60.0));
    $lat  = sprintf("%.6g", $lat_deg + ($lat_min / 60.0));

    print "\"00\",\"$key\",\"$state\",\"$city\",$long,$lat,0,0\n";
}
untie(%DB);
