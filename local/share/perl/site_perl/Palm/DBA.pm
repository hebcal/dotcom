########################################################################
# Palm::DBA are routines for writing Palm Date Book Archive files.
#
# Usage:
#
# use Palm::DBA;
# my @events = (
#     ["Michael's Birthday", 1, -1, -1, 2, 5, 1975, 0, ""],
#     ["Dinner with Ariella", 0, 30, 19, 13, 7, 2002, 120, ""],
#     );
#
# Palm::DBA::write_header('calendar_2002.dba');
# Palm::DBA::write_contents(\@events, '-8', 1);
# 
# Copyright (c) 2004  Michael J. Radwin.
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

package Palm::DBA;
require 5.000;
use strict;
use Time::Local ();

my $VERSION = '$Revision$'; #'

my $PALM_DBA_MAGIC      = 1145176320;
my $PALM_DBA_INTEGER    = 1;
my $PALM_DBA_DATE       = 3;
my $PALM_DBA_CSTRING    = 5;
my $PALM_DBA_BOOL       = 6;
my $PALM_DBA_REPEAT     = 8;
my $PALM_DBA_MAXENTRIES = 2500;

# @events is an array of arrays.  these are the indices into each
# event structure:

$Palm::DBA::EVT_IDX_SUBJ = 0;		# title of event
$Palm::DBA::EVT_IDX_UNTIMED = 1;	# non-zero if all-day, 0 if timed
$Palm::DBA::EVT_IDX_MIN = 2;		# minutes, [0 .. 59]
$Palm::DBA::EVT_IDX_HOUR = 3;		# hour of day, [0 .. 23]
$Palm::DBA::EVT_IDX_MDAY = 4;		# day of month, [1 .. 31]
$Palm::DBA::EVT_IDX_MON = 5;		# month of year, [0 .. 11]
$Palm::DBA::EVT_IDX_YEAR = 6;		# year [1970 .. 2038]
$Palm::DBA::EVT_IDX_DUR = 7;		# duration in minutes
$Palm::DBA::EVT_IDX_MEMO = 8;		# memo text

sub write_int($)
{
    print STDOUT pack("V", $_[0]);
}

sub write_byte($)
{
    print STDOUT pack("C", $_[0]);
}

sub write_cstring($)
{
    my($s) = @_;

    if (!defined($s) || $s eq '')
    {
	write_byte(0);
    }
    else
    {
	my($len) = length($s);
	$len = 254 if $len > 254;
	write_byte($len);
	print STDOUT substr($s, 0, $len);
    }
}

sub write_header($)
{
    my($filename) = @_;

    write_int($PALM_DBA_MAGIC);
    write_cstring($filename);
    write_byte(0);
    write_int(8);
    write_int(0);

    # magic OLE graph table
    write_int(0x36);
    write_int(0x0F);
    write_int(0x00);
    write_int(0x01);
    write_int(0x02);
    write_int(0x1000F);
    write_int(0x10001);
    write_int(0x10003);
    write_int(0x10005);
    write_int(0x60005);
    write_int(0x10006);
    write_int(0x10006);
    write_int(0x80001);

    1;
}

sub write_contents($$$)
{
    my($events,$tz,$dst) = @_;
    my($nevents) = scalar(@{$events});
    my($startTime,$i,$secsEast,$local2local);

    # compute diff seconds between GMT and whatever our local TZ is
    # pick 1990/01/15 as a date that we're certain is standard time
    $startTime = Time::Local::timegm(0,34,12,15,0,90,0,0,0);
    $secsEast = $startTime - Time::Local::timelocal(0,34,12,15,0,90,0,0,0);

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
    write_int($nevents*15);

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
	    $startTime = Time::Local::timegm(
		 0,
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MIN],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_HOUR],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MDAY],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MON],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_YEAR] - 1900);
	    $startTime -= ($tz * 60 * 60); # move into local tz
	}
	else
	{
	    $startTime = Time::Local::timelocal(
		 0,
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MIN],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_HOUR],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MDAY],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_MON],
		 $events->[$i]->[$Palm::DBA::EVT_IDX_YEAR] - 1900);
	    $startTime += $local2local; # move into their local tz
	}

	write_int($PALM_DBA_INTEGER);
	write_int(0);		# recordID

	write_int($PALM_DBA_INTEGER);
	write_int(1);		# status

	write_int($PALM_DBA_INTEGER);
	write_int(0x7FFFFFFF);	# position

	write_int($PALM_DBA_DATE);
	write_int($startTime);

	write_int($PALM_DBA_INTEGER);

	# endTime
	if ($events->[$i]->[$Palm::DBA::EVT_IDX_UNTIMED] != 0)
	{
	    write_int($startTime);
	}
	else
	{
	    write_int($startTime +
		       ($events->[$i]->[$Palm::DBA::EVT_IDX_DUR] * 60));
	}

	write_int($PALM_DBA_CSTRING);
	write_int(0);		# always zero
	write_cstring($events->[$i]->[$Palm::DBA::EVT_IDX_SUBJ]);

	write_int($PALM_DBA_INTEGER);
	write_int(0);		# duration

	write_int($PALM_DBA_CSTRING);
	write_int(0);		# always zero
	write_cstring($events->[$i]->[$Palm::DBA::EVT_IDX_MEMO]);

	write_int($PALM_DBA_BOOL);
	write_int($events->[$i]->[$Palm::DBA::EVT_IDX_UNTIMED] ? 1 : 0);

	write_int($PALM_DBA_BOOL);
	write_int(0);		# isPrivate

	write_int($PALM_DBA_INTEGER);
	write_int(1);		# category

	write_int($PALM_DBA_BOOL);
	write_int(0);		# alarm

	write_int($PALM_DBA_INTEGER);
	write_int(0xFFFFFFFF);	# alarmAdv

	write_int($PALM_DBA_INTEGER);
	write_int(0);		# alarmTyp

	write_int($PALM_DBA_REPEAT);
	write_int(0);		# repeat
    }

    1;
}

1;
