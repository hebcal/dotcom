#!/usr/local/bin/perl -w

# $Id$

# Copyright (c) 2002  Michael John Radwin.  All rights reserved.
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

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";
use strict;
use Hebcal;

my $DB = &Hebcal::zipcode_open_db();
die unless defined $DB->{"95051"};

my($ncandle) = my($nzip) = my($ncity) = my($npos) =
    my($ndownload) = my($ndba) = my($ncsv) = 0;
my($unk_zip) = 0;
my(%unk_zip) = ();

my %counter = ();
while(<STDIN>)
{
    next unless substr($_, 0, 14) eq 'www.hebcal.com';

    my $part;
    if (m,(GET|POST)\s+/\s+HTTP/,)
    {
	$part = '/';
    }
    elsif (m,(GET|POST)\s+/([^\s/]+),)
    {
	$part = $2;
    }
    else
    {
	next;
    }

    if (defined $counter{$part}) {
	$counter{$part}++;
    } else {
	$counter{$part} = 1;
    }

    if (m,\.(dba|csv), && /v=1/ && /dl=1/)
    {
	$ndownload++;

	if (m,\.dba,)
	{
	    $ndba++;
	}
	else
	{
	    $ncsv++;
	}
    }

    if (m,GET\s+/hebcal/\?, && /v=1/)
    {
	if (/\bc=(on|1)\b/)
	{
	    $ncandle++;
	    if (/geo=city/)
	    {
		$ncity++;
	    }
	    elsif (/geo=pos/)
	    {
		$npos++;
	    }
	    elsif (/zip=(\d\d\d\d\d)/)
	    {
		my($zipcode) = $1;
		my($val) = $DB->{$zipcode};
		$nzip++;

		if (!defined $val) {
		    $unk_zip++;
		    $unk_zip{$zipcode}++;
		    $ncandle--;
		    $nzip--;
		}
	    }
	    else
	    {
		$ncandle--;
	    }
	}
    }
}
 
printf "%5d download (%5d dba, %5d csv)\n",
   $ndownload, $ndba, $ncsv;
printf "%5d candle   (%5d zip, %5d city, %5d pos)\n\n",
    $ncandle, $nzip, $ncity, $npos;

foreach my $part (sort { $counter{$b} <=> $counter{$a} } keys %counter)
{
    printf "%5d %s\n", $counter{$part}, $part;
}

if ($unk_zip > 0) {
    printf "\n%5d zips unknown\n", $unk_zip;

    foreach (sort keys %unk_zip) {
	printf "%s %5d\n", $_, $unk_zip{$_};
    }
}

&Hebcal::zipcode_close_db($DB);
undef($DB);

exit(0);
