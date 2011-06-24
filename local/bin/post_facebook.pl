#!/usr/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2011  Michael J. Radwin.
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

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use Hebcal ();

# get the date for this upcoming saturday
my($sat_year,$sat_month,$sat_day) = Hebcal::upcoming_dow(6);

my $WEBDIR = '/home/hebcal/web/hebcal.com';
my $HEBCAL = "$WEBDIR/bin/hebcal";
my @events = Hebcal::invoke_hebcal("$HEBCAL -s -h -x $sat_year", "", 0, $sat_month);
for (my $i = 0; $i < @events; $i++) {
    if ($events[$i]->[$Hebcal::EVT_IDX_MDAY] == $sat_day) {
	my $parasha = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $email_subj = "This week's Torah portion is $parasha. Shabbat Shalom!";
	my $return_path = "mradwin\@hebcal.com";
	my %headers = (
	   "From" => "Hebcal <$return_path>",
	   "To" => "ammo626cion\@m.facebook.com",
	   "MIME-Version" => "1.0",
	   "Content-Type" => "text/plain",
	   "Subject" => $email_subj,
	 );

	Hebcal::sendmail_v2($return_path, \%headers, "");
	last;
      }
}

exit(0);
