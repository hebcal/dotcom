#!/usr/local/bin/perl5 -w

########################################################################
# compute yahrtzeit dates based on gregorian calendar based on Hebcal
#
# Copyright (c) 2000  Michael John Radwin.  All rights reserved.
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

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;
use Hebcal;
use HTML::Entities ();
use POSIX;
use strict;

my($author) = 'michael@radwin.org';
my($expires_date) = 'Thu, 15 Apr 2010 20:00:00 GMT';

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($hhmts) = "<!-- hhmts start -->
Last modified: Mon Oct 23 15:23:50 PDT 2000
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated:\n/g;

my($html_footer) = "<hr
noshade size=\"1\"><small>$hhmts ($rcsrev)<br><br>Copyright
&copy; $this_year <a href=\"/michael/contact.html\">Michael J. Radwin</a>.
All rights reserved.</small></body></html>
";

# process form params
my($q) = new CGI;

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;
my($server_name) = $q->server_name();
$server_name =~ s/^www\.//;

$q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		"\t\"http://www.w3.org/TR/html4/loose.dtd");

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
my($key);
foreach $key ($q->param())
{
    my($val) = $q->param($key);
    $val =~ s/[^\w\s-]//g;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

my(@ynums);
foreach $key ($q->param())
{
    if ($key =~ /^n(\d+)$/)
    {
	my($num) = $1;
	push(@ynums, $num) if ($q->param($key) ne '');
    }
}

my(%yahrtzeits) = ();
foreach $key (@ynums)
{
    if (defined $q->param("m$key") &&
	defined $q->param("d$key") &&
	defined $q->param("y$key") &&
	$q->param("m$key") =~ /^\d{1,2}$/ &&
	$q->param("d$key") =~ /^\d{1,2}$/ &&
	$q->param("y$key") =~ /^\d{4}$/)
    {
	$yahrtzeits{$q->param("n$key")} =
	    sprintf("%02d %02d %4d %s",
		    $q->param("m$key"),
		    $q->param("d$key"),
		    $q->param("y$key"),
		    $q->param("n$key"));
    }
}

&form(1,'','') unless keys %yahrtzeits;

my($tmpfile) = POSIX::tmpnam();
open(T, ">$tmpfile") || die "$tmpfile: $!\n";
foreach $key (keys %yahrtzeits)
{
    print T $yahrtzeits{$key}, "\n";
}
close(T);

my($cmd) = "/home/users/mradwin/bin/hebcal -D -h -x -Y $tmpfile";

print STDOUT $q->header(),
    $q->start_html(-title => 'Interactive Yahrtzeit Calendar',
		   -target => '_top',
		   -head => [
			     "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			     $q->Link({-rel => 'stylesheet',
				       -href => '/style.css',
				       -type => 'text/css'}),
			     ],
		   -meta => {'robots' => 'noindex'});

print STDOUT
    "<table width=\"100%\"\nclass=\"navbar\">",
    "<tr><td><small>",
    "<strong><a\nhref=\"/\">", $server_name, "</a></strong>\n",
    "<tt>-&gt;</tt>\n",
    "yahrtzeit</small></td>",
    "<td align=\"right\"><small><a\n",
    "href=\"/search/\">Search</a></small>",
    "</td></tr></table>",
    "<h1>Interactive\nYahrtzeit Calendar</h1>\n";

print STDOUT "<pre>\n";

my(%greg2heb) = ();
my($year);
foreach $year ($this_year .. ($this_year + 10))
{
    my($cmd_pretty) = "$cmd $year";
    $cmd_pretty =~ s,.*/hebcal,hebcal,; # basename
    print STDOUT "<!-- $cmd_pretty -->\n";

    my(@events) = &invoke_hebcal("$cmd $year", '');

    my($numEntries) = scalar(@events);
    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];
	
	if ($subj =~ /,\s+\d{4}\s*$/)
	{
	    $greg2heb{sprintf("%04d%02d%02", $year, $mon, $mday)} = $subj;
	    next;
	}

	if (defined $yahrtzeits{$subj})
	{
	    my($dow) = ($year > 1969 && $year < 2038) ?
		$Hebcal::DoW[&get_dow($year - 1900, $mon - 1, $mday)] . ' ' :
		    '';
	    printf STDOUT "%s%04d-%02d-%02d  %s's Yahrtzeit",
	    	$dow, $year, $mon, $mday, HTML::Entities::encode($subj);

	    my($isodate) = sprintf("%04d%02d%02", $year, $mon, $mday);
	    print STDOUT " ($greg2heb{$isodate})"
		if (defined $greg2heb{$isodate});
	    print STDOUT "\n";
	}
    }
}

unlink($tmpfile);
print STDOUT "</pre>\n";

print STDOUT $html_footer;

close(STDOUT);
exit(0);

sub form
{
    my($head,$message,$help) = @_;

    my(%months) = %Hebcal::MoY_long;
    $months{'x'} = '[select one]';


    if ($head)
    {
	print STDOUT
	    $q->header(),
	    $q->start_html(-title => "Interactive Yahrtzeit Calendar",
			   -target=>'_top',
			   -head => [
			     "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			     $q->Link({-rel => 'stylesheet',
				       -href => '/style.css',
				       -type => 'text/css'}),
			     ],
			   -meta => {'robots' => 'noindex'});

	print STDOUT
	    "<table width=\"100%\"\nclass=\"navbar\">",
	    "<tr><td><small>",
	    "<strong><a\nhref=\"/\">", $server_name, "</a></strong>\n",
	    "<tt>-&gt;</tt>\n",
	    "yahrtzeit</small></td>",
	    "<td align=\"right\"><small><a\n",
	    "href=\"/search/\">Search</a></small>",
	    "</td></tr></table>",
	    "<h1>Interactive\nYahrtzeit Calendar</h1>\n";
    }

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">";
    }

    print STDOUT qq{$message\n<form\naction="$script_name">};

    for (my $i = 0; $i < 6; $i++)
    {
	print STDOUT
	    "Name:\n",
	    $q->textfield(-name => "n$i",
			  -id => "n$i"),
	    "\n&nbsp;&nbsp;&nbsp;Day:\n",
	    $q->popup_menu(-name => "m$i",
			   -id => "m$i",
			   -values => ['x',1..12],
			   -default => 'x',
			   -labels => \%months),
	    "\n",
	    $q->textfield(-name => "d$i",
			  -id => "d$i",
			  -maxlength => 2,
			  -size => 2),
	    "\n,\n",
	    $q->textfield(-name => "y$i",
			  -id => "y$i",
			  -maxlength => 4,
			  -size => 4),
	    "\n(Month Day, Year)<br>\n";
    }

    print STDOUT qq{<input\ntype="submit" value="Get Yahrtzeits"></form>\n};
    print STDOUT $html_footer;

    exit(0);
}
