#!/usr/local/bin/perl5 -w

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

use DB_File;
use Getopt::Std;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] zips.txt
    -h        Display usage information.
";

my(%opts);
&getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 1) || die "$usage";

open(IN, $ARGV[0]) || die "$ARGV[0]: $!\n";

my $dbmfile = 'zips.db';
my %DB;
tie(%DB, 'DB_File', $dbmfile, O_RDWR|O_CREAT, 0644, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";

print "reading from $ARGV[0], writing to zips.db\n";

my $count = 0;
while(<IN>)
{
    chop;
    my($fips,$zip,$state,$city,$long,$lat,$pop,$alloc) =
	/^"(\d+)","(\d+)","([^\"]+)","([^\"]+)",([^,]+),([^,]+),([^,]+),([^,]+)$/;

    if (! defined $alloc)
    {
	warn "bad line $_\n";
	next;
    }

    die if $city =~ /,/;

    my($long_deg,$long_min) = split(/\./, $long, 2);
    my($lat_deg,$lat_min) = split(/\./, $lat, 2);

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
    $count++;
}
close(IN);
untie(%DB);

print "inserted $count zips from $ARGV[0] into zips.db\n";

exit(0);
