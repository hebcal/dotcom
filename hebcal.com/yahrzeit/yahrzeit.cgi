#!/usr/local/bin/perl5 -w

########################################################################
# compute yahrzeit dates based on gregorian calendar based on Hebcal
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
Last modified: Thu Mar  1 14:29:44 PST 2001
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

my(%yahrzeits) = ();
my(%ytype) = ();
foreach $key (@ynums)
{
    if (defined $q->param("m$key") &&
	defined $q->param("d$key") &&
	defined $q->param("y$key") &&
	$q->param("m$key") =~ /^\d{1,2}$/ &&
	$q->param("d$key") =~ /^\d{1,2}$/ &&
	$q->param("y$key") =~ /^\d{4}$/)
    {
	$yahrzeits{$q->param("n$key")} =
	    sprintf("%02d %02d %4d %s",
		    $q->param("m$key"),
		    $q->param("d$key"),
		    $q->param("y$key"),
		    $q->param("n$key"));
	$ytype{$q->param("n$key")} = 
	    ($q->param("t$key") eq 'Birthday') ? 'Hebrew Birthday' :
		$q->param("t$key");
    }
}

if (! defined $q->path_info())
{
    &results_page();
}
elsif ($q->path_info() =~ /[^\/]+.csv$/)
{
    &csv_display();
}
elsif ($q->path_info() =~ /[^\/]+.dba$/)
{
    &dba_display();
}
else
{
    &results_page();
}

close(STDOUT);
exit(0);

sub dba_display
{
    my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);
    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;
    print $q->header(-type =>
		     "application/x-palm-dba; filename=\"$path_info\"",
		     -content_disposition =>
		     "inline; filename=$path_info",
		     -last_modified => &Hebcal::http_date($time));

    &Hebcal::dba_write_header($path_info);
    &Hebcal::dba_write_contents(\@events, 0, 0);
}

sub csv_display
{
    my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);
    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;
    print $q->header(-type => "text/x-csv; filename=\"$path_info\"",
		     -content_disposition =>
		     "inline; filename=$path_info",
		     -last_modified => &Hebcal::http_date($time));

    my($endl) = "\012";			# default Netscape and others
    if (defined $q->user_agent() && $q->user_agent() !~ /^\s*$/)
    {
	$endl = "\015\012"
	    if $q->user_agent() =~ /Microsoft Internet Explorer/;
	$endl = "\015\012" if $q->user_agent() =~ /MSP?IM?E/;
    }

    &Hebcal::csv_write_contents(\@events, $endl);
}

sub my_invoke_hebcal {
    my($this_year,$y,$t) = @_;
    my(@events2) = ();

    my($tmpfile) = POSIX::tmpnam();
    open(T, ">$tmpfile") || die "$tmpfile: $!\n";
    foreach $key (keys %{$y})
    {
	print T $y->{$key}, "\n";
    }
    close(T);

    my($cmd) = "/home/users/mradwin/bin/hebcal -D -x -Y $tmpfile";

    my(%greg2heb) = ();
    my($year);

    foreach $year ($this_year .. ($this_year + 10))
    {
	my(@events) = &Hebcal::invoke_hebcal("$cmd $year", '');
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
		$greg2heb{sprintf("%04d%02d%02d", $year, $mon, $mday)} = $subj;
		next;
	    }

	    if (defined $y->{$subj})
	    {
		my($subj2) = "${subj}'s " . $t->{$subj};
		my($isodate) = sprintf("%04d%02d%02d", $year, $mon, $mday);

		$subj2 .= " ($greg2heb{$isodate})"
		    if (defined $greg2heb{$isodate});

		push(@events2,
		     [$subj2,
		      $events[$i]->[$Hebcal::EVT_IDX_UNTIMED],
		      $events[$i]->[$Hebcal::EVT_IDX_MIN],
		      $events[$i]->[$Hebcal::EVT_IDX_HOUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		      $events[$i]->[$Hebcal::EVT_IDX_MON],
		      $events[$i]->[$Hebcal::EVT_IDX_YEAR],
		      $events[$i]->[$Hebcal::EVT_IDX_DUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MEMO]]);
	    }
	    elsif ($subj eq 'Pesach VIII' || $subj eq 'Shavuot II' ||
		   $subj eq 'Yom Kippur' || $subj eq 'Shmini Atzeret')
	    {
		next unless defined $q->param('yizkor') &&
		    ($q->param('yizkor') eq 'on' ||
		     $q->param('yizkor') eq '1');

		my($subj2) = "Yizkor ($subj)";

		push(@events2,
		     [$subj2,
		      $events[$i]->[$Hebcal::EVT_IDX_UNTIMED],
		      $events[$i]->[$Hebcal::EVT_IDX_MIN],
		      $events[$i]->[$Hebcal::EVT_IDX_HOUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		      $events[$i]->[$Hebcal::EVT_IDX_MON],
		      $events[$i]->[$Hebcal::EVT_IDX_YEAR],
		      $events[$i]->[$Hebcal::EVT_IDX_DUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MEMO]]);
	    }
	}
    }

    unlink($tmpfile);
    @events2;
}

sub results_page {
print STDOUT $q->header(),
    $q->start_html(-title => 'Interactive Yahrzeit/Birthday Calendar',
		   -target => '_top',
		   -head => [
			     "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			     $q->Link({-rel => 'stylesheet',
				       -href => '/style.css',
				       -type => 'text/css'}),
			     ],
			   -meta => {
			       'robots' => 'noindex',
			       'keywords' =>
				   'yahzeit,yahrzeit,yohrzeit,yohrtzeit,yartzeit,yarzeit,yortzeit,yorzeit,yizkor,yiskor,kaddish'
				   },
		   ),
    "<table width=\"100%\"\nclass=\"navbar\">",
    "<tr><td><small>",
    "<strong><a\nhref=\"/\">", $server_name, "</a></strong>\n",
    "<tt>-&gt;</tt>\n",
    "yahrzeit</small></td>",
    "<td align=\"right\"><small><a\n",
    "href=\"/search/\">Search</a></small>",
    "</td></tr></table>",
    "<h1>Interactive\nYahrzeit/Birthday Calendar</h1>\n";

&form(1,'','') unless keys %yahrzeits;

    # download links
    print STDOUT "<p>Advanced options:\n<small>[ <a href=\"", $script_name;
    print STDOUT "index.html" if $q->script_name() =~ m,/index.html$,;
    print STDOUT "/yahrzeit.csv?dl=1";

    foreach $key ($q->param())
    {
	my($val) = $q->param($key);
	print STDOUT "&amp;$key=", &Hebcal::url_escape($val);
    }
    print STDOUT "&amp;filename=yahrzeit.csv";
    print STDOUT "\">Download&nbsp;Outlook&nbsp;CSV&nbsp;file</a>";

    # only offer DBA export when we know timegm() will work
    if ($this_year > 1969 && $this_year < 2028)
    {
	print STDOUT "\n- <a href=\"", $script_name;
	print STDOUT "index.html" if $q->script_name() =~ m,/index.html$,;
	print STDOUT "/yahrzeit.dba?dl=1";

	foreach $key ($q->param())
	{
	    my($val) = $q->param($key);
	    print STDOUT "&amp;$key=", &Hebcal::url_escape($val);
	}
	print STDOUT "&amp;filename=yahrzeit.dba";
	print STDOUT "\">Download&nbsp;Palm&nbsp;Date&nbsp;Book&nbsp;Archive&nbsp;(.DBA)</a>";
    }
    print STDOUT "\n]</small></p>\n";

my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

print STDOUT "<pre>" unless ($q->param('yizkor'));

my($numEntries) = scalar(@events);
my($i);
for ($i = 0; $i < $numEntries; $i++)
{
    my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
    my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
    my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
    my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

    if ($year != $events[$i - 1]->[$Hebcal::EVT_IDX_YEAR] &&
	$q->param('yizkor'))
    {
	print STDOUT "</pre>" unless $i == 0;
	print STDOUT "<h3>$year</h3><pre>";
    }

    my($dow) = ($year > 1969 && $year < 2038) ?
	$Hebcal::DoW[&Hebcal::get_dow($year - 1900, $mon - 1, $mday)] . ' '
	    : '';

    printf STDOUT ("%s%02d-%s-%04d  %s\n",
		   $dow, $mday, $Hebcal::MoY_short[$mon-1], $year,
		 &HTML::Entities::encode($subj));
}
print STDOUT "</pre>";

print STDOUT "<hr>\n";

&form(0,'','');
}

sub form
{
    my($head,$message,$help) = @_;

    my(%months) = %Hebcal::MoY_long;
    $months{'x'} = '[select one]';

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">\n";
    }

    print STDOUT qq{$message<form\naction="$script_name">};

    for (my $i = 1; $i < 6; $i++)
    {
	print STDOUT
	    $q->popup_menu(-name => "t$i",
			   -id => "t$i",
			   -values => ['Yahrzeit','Birthday']),
	    "\nName:\n",
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
	    "\n<small>(Month Day, Year)</small><br>\n";
    }

    print STDOUT "<label\nfor=\"yizkor\">",
    $q->checkbox(-name => 'yizkor',
		 -id => 'yizkor',
		 -label => "\nInclude Yizkor dates"),
    "</label><br>",
    $q->hidden(-name => 'rand',-value => time(),-override => 1),
    qq{<input\ntype="submit" value="Compute Calendar"></form>\n},
    $html_footer;

    exit(0);
}
