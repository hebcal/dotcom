########################################################################
# Palm::DBA are routines for writing Palm Date Book Archive files.
#
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
########################################################################

package Palm::DBA;
require 5.000;
use strict;
use Time::Local;

my $VERSION = '$Revision$'; #'

my $PALM_DBA_MAGIC      = 1145176320;
my $PALM_DBA_INTEGER    = 1;
my $PALM_DBA_DATE       = 3;
my $PALM_DBA_BOOL       = 6;
my $PALM_DBA_REPEAT     = 7;
my $PALM_DBA_MAXENTRIES = 2500;

# @events is an array of arrays.  these are the indices into each
# event structure:

$Palm::DBA::EVT_IDX_SUBJ = 0;		# title of event
$Palm::DBA::EVT_IDX_UNTIMED = 1;	# 0 if all-day, non-zero if timed
$Palm::DBA::EVT_IDX_MIN = 2;		# minutes, [0 .. 59]
$Palm::DBA::EVT_IDX_HOUR = 3;		# hour of day, [0 .. 23]
$Palm::DBA::EVT_IDX_MDAY = 4;		# day of month, [1 .. 31]
$Palm::DBA::EVT_IDX_MON = 5;		# month of year, [0 .. 11]
$Palm::DBA::EVT_IDX_YEAR = 6;		# year [1 .. 9999]
$Palm::DBA::EVT_IDX_DUR = 7;		# duration in minutes
$Palm::DBA::EVT_IDX_MEMO = 8;		# memo text

sub write_int
{
    print STDOUT pack("V", $_[0]);
}

sub write_byte
{
    print STDOUT pack("C", $_[0]);
}

sub write_pstring
{
    my($len) = length($_[0]);

    $len = 254 if $len > 254;
    &write_byte($len);
    print STDOUT substr($_[0], 0, $len);
}

sub write_header
{
    my($filename) = @_;

    &write_int($PALM_DBA_MAGIC);
    &write_pstring($filename);
    &write_byte(0);
    &write_int(8);
    &write_int(0);

    # magic OLE graph table
    &write_int(0x36);
    &write_int(0x0F);
    &write_int(0x00);
    &write_int(0x01);
    &write_int(0x02);
    &write_int(0x1000F);
    &write_int(0x10001);
    &write_int(0x10003);
    &write_int(0x10005);
    &write_int(0x60005);
    &write_int(0x10006);
    &write_int(0x10006);
    &write_int(0x80001);

    1;
}

sub write_contents
{
    my($events,$tz,$dst) = @_;
    my($nevents) = scalar(@{$events});
    my($startTime,$i,$secsEast,$local2local);

    # compute diff seconds between GMT and whatever our local TZ is
    # pick 1990/01/15 as a date that we're certain is standard time
    $startTime = &Time::Local::timegm(0,34,12,15,0,90,0,0,0);
    $secsEast = $startTime - &Time::Local::timelocal(0,34,12,15,0,90,0,0,0);

    $tz = 0 unless (defined $tz && $tz =~ /^-?\d+$/);

    if ($tz == 0)
    {
	# assume GMT
	$local2local = $secsEast;
    }
    else
    {
	# add secsEast to go from our localtime to GMT
	# then sub destination tz secsEast to get into local time
	$local2local = $secsEast - ($tz * 60 * 60);
    }

#    warn "DBG: tz=$tz,dst=$dst,local2local=$local2local,secsEast=$secsEast\n";

    $nevents = $PALM_DBA_MAXENTRIES
	if ($nevents > $PALM_DBA_MAXENTRIES);
    &write_int($nevents*15);

    for ($i = 0; $i < $nevents; $i++)
    {
	# skip events that can't be expressed in a 31-bit time_t
        next if $events->[$i]->[$Palm::DBA::EVT_IDX_YEAR] <= 1969 ||
	    $events->[$i]->[$Palm::DBA::EVT_IDX_YEAR] >= 2038;

	if ($events->[$i]->[$Palm::DBA::EVT_IDX_UNTIMED] != 0)
	{
	    # all-day/untimed: 12 noon
	    $events->[$i]->[$Palm::DBA::EVT_IDX_HOUR] = 12;
	    $events->[$i]->[$Palm::DBA::EVT_IDX_MIN] = 0;
	}

	if (!$dst)
	{
	    # no DST, so just use gmtime and then add that city offset
	    $startTime =
		&Time::Local::timegm(0,
				     $events->[$i]->[$Palm::DBA::EVT_IDX_MIN],
				     $events->[$i]->[$Palm::DBA::EVT_IDX_HOUR],
				     $events->[$i]->[$Palm::DBA::EVT_IDX_MDAY],
				     $events->[$i]->[$Palm::DBA::EVT_IDX_MON],
				     $events->[$i]->[$Palm::DBA::EVT_IDX_YEAR]
				     - 1900);
	    $startTime -= ($tz * 60 * 60); # move into local tz
	}
	else
	{
	    $startTime = &Time::Local::timelocal(
		 0,
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MIN],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_HOUR],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MDAY],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MON],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_YEAR] - 1900);
	    $startTime += $local2local; # move into their local tz
	}

	&write_int($PALM_DBA_INTEGER);
	&write_int(0);		# recordID

	&write_int($PALM_DBA_INTEGER);
	&write_int(1);		# status

	&write_int($PALM_DBA_INTEGER);
	&write_int(0x7FFFFFFF);	# position

	&write_int($PALM_DBA_DATE);
	&write_int($startTime);

	&write_int($PALM_DBA_INTEGER);

	# endTime
	if ($events->[$i]->[$Palm::DBA::EVT_IDX_UNTIMED] != 0)
	{
	    &write_int($startTime);
	}
	else
	{
	    &write_int($startTime +
			   ($events->[$i]->[$Palm::DBA::EVT_IDX_DUR] * 60));
	}

	&write_int(5);		# spacer
	&write_int(0);		# spacer

	if (defined $events->[$i]->[$Palm::DBA::EVT_IDX_SUBJ] &&
	    $events->[$i]->[$Palm::DBA::EVT_IDX_SUBJ] ne '')
	{
	    &write_pstring($events->[$i]->[$Palm::DBA::EVT_IDX_SUBJ]);
	}
	else
	{
	    &write_byte(0);
	}

	&write_int($PALM_DBA_INTEGER);
	&write_int(0);		# duration

	&write_int(5);		# spacer
	&write_int(0);		# spacer

	if (defined $events->[$i]->[$Palm::DBA::EVT_IDX_MEMO] &&
	    $events->[$i]->[$Palm::DBA::EVT_IDX_MEMO] ne '')
	{
	    &write_pstring($events->[$i]->[$Palm::DBA::EVT_IDX_MEMO]);
	}
	else
	{
	    &write_byte(0);
	}

	&write_int($PALM_DBA_BOOL);
	&write_int($events->[$i]->[$Palm::DBA::EVT_IDX_UNTIMED] ? 1 : 0);

	&write_int($PALM_DBA_BOOL);
	&write_int(0);		# isPrivate

	&write_int($PALM_DBA_INTEGER);
	&write_int(1);		# category

	&write_int($PALM_DBA_BOOL);
	&write_int(0);		# alarm

	&write_int($PALM_DBA_INTEGER);
	&write_int(0xFFFFFFFF);	# alarmAdv

	&write_int($PALM_DBA_INTEGER);
	&write_int(0);		# alarmTyp

	&write_int($PALM_DBA_REPEAT);
	&write_int(0);		# repeat
    }

    1;
}

1;
