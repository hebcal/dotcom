#!/usr/local/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
#
# Copyright (c) 2003  Michael J. Radwin.
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

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use Hebcal;
use strict;

# process form params
my($q) = new CGI;

my($rcsrev) = '$Revision$'; #'
my($hhmts) = "<!-- hhmts start -->
Last modified: Mon May  7 21:40:33 PDT 2001
<!-- hhmts end -->";

if (defined $ENV{'QUERY_STRING'} && $ENV{'QUERY_STRING'} eq 'optout')
{
    print "Set-Cookie: C=opt_out; path=/; expires=Thu, 15 Apr 2010 20:00:00 GMT\015\012";
    print "Expires: Thu, 01 Jan 1970 16:00:01 GMT\015\012",
    "Cache-Control: no-cache\015\012";

    print $q->header(),
    &Hebcal::start_html($q, 'Hebcal Opt-Out Complete', undef, undef),
    &Hebcal::navbar2($q, "Opt-Out", 1),
    "<h1>Hebcal\nOpt-Out Complete</h1>\n",
    "<p>Opt-out completed successfully.</p>\n",
    "<p>Your <b>hebcal.com</b> Cookie id is now set to opt_out.</p>\n",
    &Hebcal::html_footer($q,$hhmts,$rcsrev);
}
else
{
print "Set-Cookie: C=0; expires=Thu, 01 Jan 1970 16:00:01 GMT; path=/\015\012";
print "Expires: Thu, 01 Jan 1970 16:00:01 GMT\015\012",
"Cache-Control: no-cache\015\012";
print $q->header(),
    &Hebcal::start_html($q, 'Hebcal Cookie Deleted', undef, undef),
    &Hebcal::navbar2($q, "Cookie\nDeleted", 1),
    "<h1>Hebcal\nCookie Deleted</h1>\n",
    "<p>We deleted your cookie for the Hebcal Interactive Jewish\n",
    "Calendar and 1-Click Shabbat.</p>\n",
    &Hebcal::html_footer($q,$hhmts,$rcsrev);
}

exit(0);

