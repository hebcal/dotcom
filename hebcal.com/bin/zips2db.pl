#!/usr/local/bin/perl5 -w

########################################################################
# zips2db.pl - generate zips.db file from Gazeteer zips.txt
# part of the Hebcal Interactive Jewish Calendar
#
# Copyright (c) 2000  Michael John Radwin.  All rights reserved.
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
