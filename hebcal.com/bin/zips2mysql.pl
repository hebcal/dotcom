#!/usr/local/bin/perl -w

########################################################################
#
# zips2mysql.pl - load MySQL with Gazeteer zips.txt
# part of the Hebcal Interactive Jewish Calendar, www.hebcal.com
#
# $Id$
#
# Copyright (c) 2006  Michael J. Radwin.
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

use Getopt::Std ();
use DBI ();
use strict;

$0 =~ s,.*/,,;  # basename

## zipnov99.csv comes from US Census Bureau "Zip Code" Data 
## http://www.census.gov/geo/www/gazetteer/places2k.html

my $usage = "usage: $0 [-h] zipnov99.csv c_22mr02.csv
    -h        Display usage information.
";

my %opts;
Getopt::Std::getopts("h", \%opts) || die "$usage\n";
$opts{"h"} && die "$usage\n";
(@ARGV == 2) || die "$usage";

## National Weather Service county-timezone data comes from a file named
## c_DDmmYY.zip from
## http://www.nws.noaa.gov/geodata/catalog/county/html/county.htm
##
## In this data, timezone is a single letter like, P, M, C, E or p, m,
## c, e.  Uppercase indicates the county observes DST, lowercase
## indicates it doesn't.  Puerto Rico, Guam and Pago Pago time zones are
## all expressed in caps, but do NOT observe DST.

my(%tz_abbrev) =
    (
     "E" => "-5,1",    # Eastern (i.e. New York)
     "e" => "-5,0",    # Eastern no DST (i.e. Indianapolis)
     "C" => "-6,1",    # Central (i.e. Chicago)
     "c" => "-6,0",    # Central no DST (i.e. Regina)
     "M" => "-7,1",    # Mountain (i.e. Denver)
     "m" => "-7,0",    # Mountain now DST (i.e. Phoenix)
     "P" => "-8,1",    # Pacific (i.e. Los Angeles)
     "p" => undef,     # (doesn't appear)
     "A" => "-9,1",    # Alaska (i.e. Anchorage)
     "a" => undef,     # (doesn't appear)
     "h" => undef,     # (doesn't appear)
     "H" => "-10,0",   # Hawaii (i.e. Honolulu)
     "AH" => "-10,1",  # Aleutians West, AK
     "V" => "-4,0",    # Puerto Rico
     "G" => "10,0",    # Guam
     "S" => "-11,0",   # Pago Pago
     "CE" => "?,1",    # county split between Central and Eastern
     "CM" => "?,1",    # county split between Central and Mountain
     "MC" => "?,1",    # county split between Mountain and Central
     "MP" => "?,1",    # county split between Mountain and Pacific
     "?" => "?,?",     # for unknown
     );

my $zips_file = shift;
my $weather_file = shift;

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

print "reading zipcodes from $zips_file, writing to MySQL\n";

$count = 0;
my $matched = 0;
my(%seen);

my $dsn = "DBI:mysql:database=hebcal1;host=mysql.hebcal.com";
my $dbh = DBI->connect($dsn, "mradwin_hebcal", "xxxxxxxx");

my $sql = qq{DROP TABLE IF EXISTS hebcal_zips};
$dbh->do($sql) or die $dbh->errstr;

$sql = qq{
CREATE TABLE hebcal_zips (
    zips_zipcode VARCHAR(5) NOT NULL,
    zips_latitude VARCHAR(12) NOT NULL,
    zips_longitude VARCHAR(12) NOT NULL,
    zips_timezone tinyint NOT NULL,
    zips_dst tinyint(1) NOT NULL,
    zips_city VARCHAR(64) NOT NULL,
    zips_state VARCHAR(2) NOT NULL,
    PRIMARY KEY (zips_zipcode)			 
)};
$dbh->do($sql) or die $dbh->errstr;

$sql = "INSERT INTO hebcal_zips"
    . " (zips_zipcode,zips_latitude,zips_longitude,zips_timezone,zips_dst,"
    .   "zips_city,zips_state)"
    . " VALUES (?,?,?,?,?,?,?)";

my $sth = $dbh->prepare($sql) or die $dbh->errstr;

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
	warn "$zips_file:$.: unknown timezone for FIPS $fips (zipcode $zip_code)\n";
	$tz = "?";
	$us_state = "??";
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

    $sth->execute($zip_code,$latitude,$longitude,$tztz,$tzdst,
		  $poname,$us_state) or die $dbh->errstr;
    $count++;
}
close(IN);
$dbh->disconnect();

print "inserted $count zipcodes from $zips_file into MySQL\n";
print "$matched / $count zipcodes had a timezone\n";

exit(0);

