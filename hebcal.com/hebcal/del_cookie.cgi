#!/usr/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
#
# Copyright (c) 2013  Michael J. Radwin.
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
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use Hebcal ();

# process form params
my $q = new CGI;

my $title;
my $entry_content;
if (defined $ENV{'QUERY_STRING'} && $ENV{'QUERY_STRING'} eq 'optout')
{
    print "Set-Cookie: C=opt_out; path=/; expires=Thu, 15 Apr 2037 20:00:00 GMT\015\012";
    print "Expires: Thu, 01 Jan 1970 16:00:01 GMT\015\012",
    "Cache-Control: no-cache\015\012";

    $title = "Opt-Out Complete";
    $entry_content=<<EOHTML;
<p class="lead">Opt-out completed successfully.</p>
<p>Your <b>hebcal.com</b> cookie id is now set to opt_out.</p>
EOHTML
;
}
else
{
    print "Set-Cookie: C=0; expires=Thu, 01 Jan 1970 16:00:01 GMT; path=/\015\012";
    print "Expires: Thu, 01 Jan 1970 16:00:01 GMT\015\012",
	"Cache-Control: no-cache\015\012";

    $title = "Cookie Deleted";
    $entry_content=<<EOHTML;
<p class="lead">We deleted your cookie for the Hebcal Jewish Calendar and
Shabbat Candle Lighting Times.</p>
EOHTML
;
}

my $body=<<EOHTML;
<div class="page-title">
<h1>$title</h1>
</div>
$entry_content
EOHTML
;
print $q->header(),
    Hebcal::html_header_bootstrap($title, Hebcal::script_name($q), "single single-post"),
    $body,
    Hebcal::html_footer_bootstrap($q,undef);
exit(0);

