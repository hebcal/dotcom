#!/usr/local/bin/perl5 -w

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Hebcal;
use strict;

# process form params
my($q) = new CGI;
$q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		"\t\"http://www.w3.org/TR/html4/loose.dtd");

my($author) = 'michael@radwin.org';
my($server_name) = $q->server_name();
$server_name =~ s/^www\.//;

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($hhmts) = "<!-- hhmts start -->
Last modified: Fri Apr 27 11:02:33 PDT 2001
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated:\n/g;

my($html_footer) = "<hr
noshade size=\"1\"><font size=-2 face=Arial>Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href=\"/privacy/\">Privacy Policy</a> -
<a href=\"/help/\">Help</a>
<br>$hhmts ($rcsrev)
</font></body></html>
";

print "Set-Cookie: C=0; expires=Thu, 01 Jan 1970 16:00:01 GMT; path=/\015\012";
print $q->header(),
    $q->start_html(-title => "Hebcal Cookie Deleted",
		   -target => '_top',
		   -head => [
			   "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			   $q->Link({-rel => 'stylesheet',
				     -href => '/style.css',
				     -type => 'text/css'}),
			   $q->Link({-rev => 'made',
				     -href => "mailto:$author"}),
			   ],
		   ),
    &Hebcal::navbar($server_name, "Cookie\nDeleted", 1),
    "<h1>Hebcal\nCookie Deleted</h1>\n",
    "<p>We deleted your cookie for the Hebcal Interactive Jewish\n",
    "Calendar.</p>\n", $html_footer;

exit(0);

