#!/usr/local/bin/perl5 -w

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Hebcal;
use strict;

# process form params
my($q) = new CGI;

my($rcsrev) = '$Revision$'; #'
my($hhmts) = "<!-- hhmts start -->
Last modified: Mon May  7 21:40:33 PDT 2001
<!-- hhmts end -->";

print "Set-Cookie: C=0; expires=Thu, 01 Jan 1970 16:00:01 GMT; path=/\015\012";
print $q->header(),
    &Hebcal::start_html($q, 'Hebcal Cookie Deleted', undef, undef),
    &Hebcal::navbar2($q, "Cookie\nDeleted", 1),
    "<h1>Hebcal\nCookie Deleted</h1>\n",
    "<p>We deleted your cookie for the Hebcal Interactive Jewish\n",
    "Calendar and 1-Click Shabbat.</p>\n",
    &Hebcal::html_footer($q,$hhmts,$rcsrev);

exit(0);

