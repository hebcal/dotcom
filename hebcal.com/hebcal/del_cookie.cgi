#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

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

