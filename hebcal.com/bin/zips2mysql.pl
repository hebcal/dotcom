#!/usr/local/bin/perl -w

########################################################################
# zips2db.pl - generate zips.db file from Gazeteer zips.txt
# part of the Hebcal Interactive Jewish Calendar, www.hebcal.com
# $Id$
#
# Copyright (c) 2001  Michael J. Radwin.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
########################################################################

use Getopt::Std;
use DBI;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] output.db zipnov99.csv c_22mr02.csv
    -h        Display usage information.
";

my(%opts);
&getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 3) || die "$usage";

## National Weather Service county-timezone data comes from a file named
## c_DDmmYY.zip from http://www.nws.noaa.gov/geodata/catalog/county/data/
##
## In this data, timezone is a single letter like, P, M, C, E or p, m,
## c, e.  Uppercase indicates the county observes DST, lowercase
## indicates it doesn't.  Puerto Rico, Guam and Pago Pago time zones are
## all expressed in caps, but do NOT observe DST.

my(%tz_abbrev) =
    (
     'E' => '-5,1',    # New York
     'e' => '-5,0',    # Indianapolis
     'C' => '-6,1',    # Chicago
     'c' => '-6,0',    # Regina
     'M' => '-7,1',    # Denver
     'm' => '-7,0',    # Phoenix
     'P' => '-8,1',    # Los Angeles
     'p' => undef,     # (doesn't appear)
     'A' => '-9,1',    # Anchorage
     'a' => undef,     # (doesn't appear)
     'h' => undef,     # (doesn't appear)
     'H' => '-10,0',   # Honolulu
     'AH' => '-10,1',  # Aleutians West, AK
     'V' => '-4,0',    # Puerto Rico
     'G' => '10,0',    # Guam
     'S' => '-11,0',   # Pago Pago
     'CE' => '?,?',    # for unknown
     'CM' => '?,?',    # for unknown
     'MC' => '?,?',    # for unknown
     'MP' => '?,?',    # for unknown
     '?' => '?,?',     # for unknown
     );

my($dbmfile,$zips_file,$weather_file) = @ARGV;

my(%fips_zone,%fips_state);

open(IN,$weather_file) || die "$weather_file: $!\n";
print "reading timezone data from weather file $weather_file\n";
my $count = 0;
$_ = <IN>;			# ignore header
while (<IN>)
{
    chop;
    s/\cM$//;			# nuke DOS line-ending

    my($state,$cwa,$countyname,$fips,$time_zone,$fe_area,$lon,$lat) =
	split(/,/);

    unless (defined $time_zone)
    {
	warn "$weather_file:$.: bad format\n";
	next;
    }

    $fips_zone{$fips} = $time_zone;
    $fips_state{$fips} = $state;
    $count++;
}
close(IN);
print "read $count counties from $weather_file\n";

open(IN,$zips_file) || die "$zips_file: $!\n";

my $dsn = 'DBI:mysql:database=mradwin_mt1;host=mysql.radwin.net';
my $dbh = DBI->connect($dsn, 'mradwin_mt', 'xxxxxxxx');

print "reading zipcodes from $zips_file, writing to $dbmfile\n";

$count = 0;
my $matched = 0;
my(%seen);

$_ = <IN>;			# ignore header
while(<IN>)
{
    chop;
    s/\cM$//;			# nuke DOS line-ending

    my($zip_code,$latitude,$longitude,$zip_class,$poname,$state,$county) =
	split(/,/);

    unless (defined $county)
    {
	warn "$zips_file:$.: bad format\n";
	next;
    }

    my($fips) = $state . $county;
    my($tz,$us_state);

    if (defined $fips_zone{$fips})
    {
	$tz = $fips_zone{$fips};
	$us_state = $fips_state{$fips};
	$matched++;
    }
    else
    {
	warn "$zips_file:$.: unknown timezone for FIPS $fips\n";
	$tz = '?';
	$us_state = '??';
    }

    if (defined $seen{$zip_code})
    {
	warn "$zips_file:$.: duplicate zipcode $zip_code (already seen on line $seen{$zip_code})\n";
	next;
    }
    else
    {
	$seen{$zip_code} = $.;
    }

    unless (defined $tz_abbrev{$tz})
    {
	die "no tz_abbrev for $tz";
    }

    my($tztz,$tzdst) = split(/,/, $tz_abbrev{$tz});

    my $sql = "INSERT INTO hebcal_zips";
    $sql .= " (zips_zipcode, zips_latitude, zips_longitude, zips_timezone, zips_dst, zips_city, zips_state)";
    $sql .= " VALUES ('$zip_code', '$latitude', '$longitude', '$tztz', '$tzdst', '$poname', '$us_state');";

    $dbh->do($sql);
    $count++;
}
close(IN);
$dbh->disconnect();

print "inserted $count zipcodes from $zips_file into $dbmfile\n";
print "$matched / $count zipcodes had a timezone\n";

exit(0);

