#!/usr/local/bin/perl -w

########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting times
# are calculated from your latitude and longitude (which can be
# determined by your zip code or closest city).
#
# Copyright (c) 1999  Michael John Radwin.  All rights reserved.
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

require 'cgi-lib.pl';
require 'timelocal.pl';
require 'ctime.pl';

$author = 'michael@radwin.org';
$dbmfile = 'zips.db';
$dbmfile =~ s/\.db$//;

&CgiDie("Script Error: No Database", "\nThe database is unreadable.\n" .
	"Please <a href=\"mailto:$author" .
	"\">e-mail Michael</a> to tell him that hebcal is broken.")
    unless -r "${dbmfile}.db";

$expires_date = 'Thu, 15 Apr 2010 20:00:00 GMT';
$cgipath = '/hebcal/';
$rcsrev = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

@DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');

%exception_timezones =
    (
     '99692', -10,
  '33101', -5,
  '33102', -5,
  '33107', -5,
  '33109', -5,
  '33110', -5,
  '33111', -5,
  '33116', -5,
  '33119', -5,
  '33121', -5,
  '33148', -5,
  '33151', -5,
  '33152', -5,
  '33153', -5,
  '33159', -5,
  '33163', -5,
  '33164', -5,
  '33188', -5,
  '33192', -5,
  '33194', -5,
  '33195', -5,
  '33197', -5,
  '33199', -5,
  '33231', -5,
  '33233', -5,
  '33234', -5,
  '33238', -5,
  '33239', -5,
  '33242', -5,
  '33243', -5,
  '33245', -5,
  '33247', -5,
  '33255', -5,
  '33256', -5,
  '33257', -5,
  '33261', -5,
  '33265', -5,
  '33266', -5,
  '33269', -5,
  '33280', -5,
  '33283', -5,
  '33296', -5,
  '33299', -5,
  '33122', -5,
  '33125', -5,
  '33126', -5,
  '33127', -5,
  '33128', -5,
  '33129', -5,
  '33130', -5,
  '33131', -5,
  '33132', -5,
  '33133', -5,
  '33134', -5,
  '33135', -5,
  '33136', -5,
  '33137', -5,
  '33138', -5,
  '33139', -5,
  '33140', -5,
  '33141', -5,
  '33142', -5,
  '33143', -5,
  '33144', -5,
  '33145', -5,
  '33146', -5,
  '33147', -5,
  '33150', -5,
  '33154', -5,
  '33155', -5,
  '33156', -5,
  '33157', -5,
  '33158', -5,
  '33160', -5,
  '33161', -5,
  '33162', -5,
  '33165', -5,
  '33166', -5,
  '33167', -5,
  '33168', -5,
  '33169', -5,
  '33170', -5,
  '33172', -5,
  '33173', -5,
  '33174', -5,
  '33175', -5,
  '33176', -5,
  '33177', -5,
  '33178', -5,
  '33179', -5,
  '33180', -5,
  '33181', -5,
  '33182', -5,
  '33183', -5,
  '33184', -5,
  '33185', -5,
  '33186', -5,
  '33187', -5,
  '33189', -5,
  '33190', -5,
  '33193', -5,
  '33196', -5,
  '46201', -5,
  '46202', -5,
  '46203', -5,
  '46204', -5,
  '46205', -5,
  '46208', -5,
  '46214', -5,
  '46216', -5,
  '46217', -5,
  '46218', -5,
  '46219', -5,
  '46220', -5,
  '46221', -5,
  '46222', -5,
  '46224', -5,
  '46225', -5,
  '46226', -5,
  '46227', -5,
  '46229', -5,
  '46231', -5,
  '46234', -5,
  '46236', -5,
  '46237', -5,
  '46239', -5,
  '46240', -5,
  '46241', -5,
  '46250', -5,
  '46254', -5,
  '46256', -5,
  '46259', -5,
  '46260', -5,
  '46268', -5,
  '46278', -5,
  '46280', -5,
  '46290', -5,
  '46206', -5,
  '46207', -5,
  '46209', -5,
  '46211', -5,
  '46223', -5,
  '46228', -5,
  '46230', -5,
  '46242', -5,
  '46244', -5,
  '46247', -5,
  '46249', -5,
  '46251', -5,
  '46253', -5,
  '46255', -5,
  '46266', -5,
  '46274', -5,
  '46275', -5,
  '46277', -5,
  '46282', -5,
  '46283', -5,
  '46285', -5,
  '46291', -5,
  '46295', -5,
  '46298', -5,
     );

%known_state_timezones =
    (
     'HI', -10,
     'AK', -9,
     'CA', -8,
     'NV', -8,
     'WA', -8,
     'MT', -7,
     'AZ', -7,
     'UT', -7,
     'WY', -7,
     'CO', -7,
     'NM', -7,
     'TX', -6,
     'OK', -6,
     'IL', -6,
     'WI', -6,
     'MN', -6,
     'IA', -6,
     'MO', -6,
     'AR', -6,
     'LA', -6,
     'MS', -6,
     'AL', -6,
     'OH', -5,
     'RI', -5,
     'MA', -5,
     'NY', -5,
     'NH', -5,
     'VT', -5,
     'ME', -5,
     'CT', -5,
     'NJ', -5,
     'DE', -5,
     'DC', -5,
     'PA', -5,
     'WV', -5,
     'VA', -5,
     'NC', -5,
     'SC', -5,
     'NC', -5,
     'GA', -5,
     'MD', -5,
     'PR', -5,
     );

%valid_cities =
    (
     'Atlanta', 1,
     'Austin', 1,
     'Berlin', 1,
     'Baltimore', 1,
     'Bogota', 1,
     'Boston', 1,
     'Buenos Aires', 1,
     'Buffalo', 1,
     'Chicago', 1,
     'Cincinnati', 1,
     'Cleveland', 1,
     'Dallas', 1,
     'Denver', 1,
     'Detroit', 1,
     'Gibraltar', 1,
     'Hawaii', 1,
     'Houston', 1,
     'Jerusalem', 1,
     'Johannesburg', 1,
     'London', 1,
     'Los Angeles', 1,
     'Miami', 1,
     'Mexico City', 1,
     'New York', 1,
     'Omaha', 1,
     'Philadelphia', 1,
     'Phoenix', 1,
     'Pittsburgh', 1,
     'Saint Louis', 1,
     'San Francisco', 1,
     'Seattle', 1,
     'Toronto', 1,
     'Vancouver', 1,
     'Washington DC', 1,
     );

%tz_names = (
     '-5', 'U.S. Eastern',
     '-6', 'U.S. Central',
     '-7', 'U.S. Mountain',
     '-8', 'U.S. Pacific',
     '-9', 'U.S. Alaskan',
     '-10', 'U.S. Hawaii',
     );

@MoY_abbrev = ('',
	       'jan','feb','mar','apr','may','jun',
	       'jul','aug','sep','oct','nov','dec');
@MoY = 
    ('',
     'January','Februrary','March','April','May','June',
     'July','August','September','October','November','December');

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime(time);
$year += 1900;

$html_header = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\"
\t\"http://www.w3.org/TR/REC-html40/loose.dtd\">
<html><head>
<title>Hebcal Interactive Jewish Calendar</title>
<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
<meta name=\"description\" content=\"Generates a list of Jewish holidays and candle lighting times customized to your zip code, city, or latitude/longitude.\">
<meta name=\"keywords\" content=\"hebcal, Jewish calendar, Hebrew calendar, candle lighting, Shabbat, Havdalah, sedrot, Sadinoff\">
<link rev=\"made\" href=\"mailto:$author\">
<meta name=\"DC.Title\" content=\"Hebcal Interactive Jewish Calendar\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#title\">
<meta name=\"DC.Creator.PersonalName\" content=\"Radwin, Michael\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#creator\">
<meta name=\"DC.Creator.PersonalName.Address\" content=\"$author\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#creator\">
<meta name=\"DC.Subject\" content=\"Jewish calendar\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Subject\" content=\"Hebrew calendar\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Subject\" content=\"hebcal\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Subject\" content=\"candle lighting\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#subject\">
<meta name=\"DC.Type\" content=\"Text.Form\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#type\">
<meta name=\"DC.Identifier\" content=\"http://www.radwin.org/hebcal/\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#identifier\">
<meta name=\"DC.Language\" scheme=\"ISO639-1\" content=\"en\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#language\">
<meta name=\"DC.Date.X-MetadataLastModified\" scheme=\"ISO8601\" content=\"1999-08-07\">
<link rel=SCHEMA.dc href=\"http://purl.org/metadata/dublin_core_elements#date\">
<base href=\"http://www.radwin.org/hebcal/\">
</head>
<body>";

$ENV{'TZ'} = 'PST8PDT';  # so ctime displays the time zone
$hhmts = "<!-- hhmts start -->
Last modified: Thu Dec 16 19:07:01 PST 1999
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated: /g;
$hhmts = 'This page generated: ' . &ctime(time) . '<br>' . $hhmts;

$html_footer = "<hr noshade size=\"1\">
<small>$hhmts ($rcsrev)
<br><br>Copyright &copy; $year Michael John Radwin. All rights
reserved.<br><a href=\"/michael/projects/hebcal/\">Frequently
asked questions about this service.</a></small>
</body></html>
";

# boolean options
@opts = ('c','x','o','s','i','h','a','d','usa','israel','none','set');
%opts = ();

&ReadParse();

if (! defined $in{'v'} &&
    defined $ENV{'HTTP_COOKIE'} &&
    $ENV{'HTTP_COOKIE'} =~ /[\s;,]*C=([^\s,;]+)/)
{
    &process_cookie($1);
}

while (($key,$val) = each(%in))
{
    $val =~ s/[^\w\s-]//g;
    $in{$key} = $val;
}

$year = $in{'year'}
    if (defined $in{'year'} && $in{'year'} =~ /^\d+$/ && $in{'year'} > 0);

# timezone opt
for ($i = -12; $i <= 12; $i++)
{
    $tz{$i} = '';
}
$tz{'auto'} = '';

if (defined $in{'tz'})
{
    $tz{$in{'tz'}} = ' selected';
}
elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
{
    $tz{'0'} = ' selected';
}

# month opt
for ($i = 0; $i <= 12; $i++)
{
    $month{$i} = '';
}

if (defined $in{'month'} && $in{'month'} =~ /^\d+$/ &&
    $in{'month'} >= 1 && $in{'month'} <= 12)
{
    $month{$in{'month'}} = ' selected';
}
else
{
#    $month{$mon + 1} = ' selected';
    $month{'0'} = ' selected';
}

foreach (@opts)
{
    $opts{$_}     = (defined $in{$_} && ($in{$_} eq 'on' || $in{$_} eq '1')) ?
	1 : 0;
}

if (defined $in{'dst'})
{
    $opts{'usa'}    = ($in{'dst'} eq 'usa') ? 1 : 0;
    $opts{'israel'} = ($in{'dst'} eq 'israel') ? 1 : 0;
    $opts{'none'}   = ($in{'dst'} eq 'none') ? 1 : 0;
}
elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
{
    $opts{'none'}   = 1;
}
else
{
    $opts{'usa'}    = 1;
}

$opts{'set'} = 1
    if (!defined $in{'v'} && defined $in{'geo'} &&
	(! defined $ENV{'HTTP_COOKIE'} || $ENV{'HTTP_COOKIE'} =~ /^\s*$/));

foreach (@opts)
{
    $opts_chk{$_} = $opts{$_} ? ' checked' : '';
}

$havdalah = 72;
$havdalah = $in{'m'} if (defined $in{'m'} && $in{'m'} =~ /^\d+$/);

if (! defined $in{'v'})
{
    $in{'zip'} = '' unless defined $in{'zip'};
    &form('');
}
    
$cmd  = "/home/users/mradwin/bin/hebcal";

if (defined $in{'city'} && $in{'city'} !~ /^\s*$/)
{
    &form("Sorry, invalid city\n" . $in{'city'})
	unless defined($valid_cities{$in{'city'}});

    $cmd .= " -C '$in{'city'}'";

    $city_descr = "Closest City: $in{'city'}";
    $lat_descr  = '';
    $long_descr = '';
    $dst_tz_descr = '';

    delete $in{'tz'};
    delete $in{'dst'};
}
elsif (defined $in{'lodeg'} && defined $in{'lomin'} && defined $in{'lodir'} &&
       defined $in{'ladeg'} && defined $in{'lamin'} && defined $in{'ladir'})
{
    &form("Sorry, all latitude/longitude\narguments must be numeric.")
	if (($in{'lodeg'} !~ /^\s*\d*\s*$/) ||
	    ($in{'lomin'} !~ /^\s*\d*\s*$/) ||
	    ($in{'ladeg'} !~ /^\s*\d*\s*$/) ||
	    ($in{'lamin'} !~ /^\s*\d*\s*$/));

    ($long_deg) = ($in{'lodeg'} =~ /^\s*(\d+)\s*$/);
    ($long_min) = ($in{'lomin'} =~ /^\s*(\d+)\s*$/);
    ($lat_deg)  = ($in{'ladeg'} =~ /^\s*(\d+)\s*$/);
    ($lat_min)  = ($in{'lamin'} =~ /^\s*(\d+)\s*$/);

    $long_deg   = 0 unless defined $long_deg;
    $long_min   = 0 unless defined $long_min;
    $lat_deg    = 0 unless defined $lat_deg;
    $lat_min    = 0 unless defined $lat_min;

    $in{'lodir'} = 'w' unless ($in{'lodir'} eq 'e');
    $in{'ladir'} = 'n' unless ($in{'ladir'} eq 's');

    $in{'lodeg'} = $long_deg;
    $in{'lomin'} = $long_min;
    $in{'ladeg'} = $lat_deg;
    $in{'lamin'} = $lat_min;

    &form("Sorry, longitude degrees\n" .
	  "<b>$in{'lodeg'}</b> out of valid range 0-180.")
	if ($in{'lodeg'} > 180);

    &form("Sorry, latitude degrees\n" .
	  "<b>$in{'ladeg'}</b> out of valid range 0-90.")
	if ($in{'ladeg'} > 90);

    &form("Sorry, longitude minutes\n" .
	  "<b>$in{'lomin'}</b> out of valid range 0-60.")
	if ($in{'lomin'} > 60);

    &form("Sorry, latitude minutes\n" .
	  "<b>$in{'lamin'}</b> out of valid range 0-60.")
	if ($in{'lamin'} > 60);

    $city_descr = "Geographic Position";
    $lat_descr  = "${lat_deg}d${lat_min}' \U$in{'ladir'}\E latitude";
    $long_descr = "${long_deg}d${long_min}' \U$in{'lodir'}\E longitude";
    $dst_tz_descr =
"Daylight Savings Time: $in{'dst'}</small>\n<dd><small>Time zone: GMT $in{'tz'}:00";
    $dst_tz_descr .= " ($tz_names{$in{'tz'}})" if defined $tz_names{$in{'tz'}};


    # don't multiply minutes by -1 since hebcal does it internally
    $long_deg *= -1  if ($in{'lodir'} eq 'e');
    $lat_deg  *= -1  if ($in{'ladir'} eq 's');

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}
elsif (defined $in{'zip'})
{
    $in{'dst'} = 'usa' if !defined($in{'dst'}) || $in{'dst'} =~ /^\s*$/;
    $in{'geo'} = 'zip';

    &form("Please specify a 5-digit\nzip code.")
	if $in{'zip'} =~ /^\s*$/;

    &form("Sorry, <b>" . $in{'zip'} . "</b> does\n" .
	  "not appear to be a 5-digit zip code.")
	unless $in{'zip'} =~ /^\d\d\d\d\d$/;

    dbmopen(%DB,$dbmfile, 0400) ||
	&CgiDie("Script Error: Database Unavailable",
		"\nThe database is unavailable right now.\n" .
		"Please <a href=\"${cgipath}?" .
		$ENV{'QUERY_STRING'} . "\">try again</a>.");

    $val = $DB{$in{'zip'}};
    dbmclose(%DB);

    &form("Sorry, can't find\n".  "<b>" . $in{'zip'} . 
	  "</b> in the zip code database.",
          "<ul><li>Please try a nearby zip code or select candle lighting times by\n" .
          "<a href=\"${cgipath}?c=on&amp;geo=city\">city</a> or\n" .
          "<a href=\"${cgipath}?c=on&amp;geo=pos\">latitude/longitude</a></li></ul>")
	unless defined $val;

    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));

    @city = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = "\L$_\E";
	$_ = "\u$_";
	$city .= $_;
    }
    undef(@city);

    $city_descr = "$city, $state &nbsp;$in{'zip'}";

    if ($in{'tz'} eq 'auto' || $in{'tz'} eq '')
    {
	if (defined $exception_timezones{$in{'zip'}})
	{
	    $in{'tz'} = $exception_timezones{$in{'zip'}};
	}
	elsif (!defined $known_state_timezones{$state})
	{
	    &form("Sorry, can't auto-detect\n" .
		  "timezone for <b>" . $city_descr . "</b>\n".
		  "(state <b>" . $state . "</b> spans multiple time zones).",
		  "<ul><li>Please select your time zone below.</li></ul>");
	}
	else
	{
	    $in{'tz'} = $known_state_timezones{$state};
	}
    }

    $lat_descr  = "${lat_deg}d${lat_min}' N latitude";
    $long_descr = "${long_deg}d${long_min}' W longitude";
    $dst_tz_descr =
"Daylight Savings Time: $in{'dst'}</small>\n<dd><small>Time zone: GMT $in{'tz'}:00";
    $dst_tz_descr .= " ($tz_names{$in{'tz'}})" if defined $tz_names{$in{'tz'}};

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}

foreach (@opts)
{
    $cmd .= ' -' . $_ if $opts{$_} && length($_) == 1;
}

$cmd .= " -m $in{'m'}" if (defined $in{'m'} && $in{'m'} =~ /^\d+$/);

if (defined $in{'tz'} && $in{'tz'} ne '')
{
    $cmd .= " -z $in{'tz'}";
}

if (defined $in{'dst'} && $in{'dst'} ne '')
{
    $cmd .= " -Z $in{'dst'}";
}

if (defined $in{'month'} && $in{'month'} =~ /^\d+$/ &&
    $in{'month'} >= 1 && $in{'month'} <= 12)
{
    $cmd .= " $in{'month'}";
}

$cmd .= " $year";


&results_page() unless defined $ENV{'PATH_INFO'};

open(HEBCAL,"$cmd |") ||
    &CgiDie("Script Error: can't run hebcal",
	    "\nCommand was \"$cmd\".\n" .
	    "Please <a href=\"mailto:$author" .
	    "\">e-mail Michael</a> to tell him that hebcal is broken.");

local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
    (stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

print STDOUT "Last-Modified: ", &http_date($time), "\015\012";
print STDOUT "Expires: $expires_date\015\012";
print STDOUT "Content-Type: text/x-csv\015\012\015\012";

$endl = "\012";			# default Netscape and others
if (defined $ENV{'HTTP_USER_AGENT'} && $ENV{'HTTP_USER_AGENT'} !~ /^\s*$/)
{
    $endl = "\015\012"
	if $ENV{'HTTP_USER_AGENT'} =~ /Microsoft Internet Explorer/;
    $endl = "\015\012" if $ENV{'HTTP_USER_AGENT'} =~ /MSP?IM?E/;
}

print STDOUT "\"Subject\",\"Start Date\",\"Start Time\",\"End Date\",",
    "\"End Time\",\"All day event\",\"Description\",",
    "\"Private\",\"Show time as\"$endl";

$prev = '';
local($loc) = (defined $in{'city'} || defined $in{'zip'}) ?
    "in $city_descr" : '';
$loc =~ s/\s*&nbsp;\s*/ /g;
while(<HEBCAL>)
{
    next if $_ eq $prev;
    $prev = $_;
    chop;
    ($date,$descr) = split(/ /, $_, 2);

    ($subj,$date,$start_time,$end_date,$end_time,$all_day)
	= &parse_date_descr($date,$descr);

    print STDOUT '"', $subj, '","', $date, '",', $start_time, ',', $end_date,
	',', $end_time, ',', $all_day, ',"',
	($start_time eq '' ? '' : $loc), '","true","3"', $endl;
}
close(HEBCAL);
close(STDOUT);

exit(0);


sub form
{
    local($message,$help) = @_;
    local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;
    local($key,$val);

#    print STDOUT "Last-Modified: ", &http_date($time), "\015\012";
    print STDOUT "Content-Type: text/html\015\012\015\012";

    print STDOUT "$html_header
<table border=\"0\" width=\"100%\" cellpadding=\"0\" class=\"navbar\">
<tr valign=\"top\"><td><small>
<a href=\"/\">radwin.org</a> <tt>-&gt;</tt>
hebcal</small></td>
<td align=\"right\"><small><a href=\"/search/\">Search</a></small>
</td></tr></table>
<h1>Hebcal Interactive Jewish Calendar</h1>
";

if ($message ne '')
{
    $help = '' unless defined $help;
    $message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	$message . "</font></p>\n" . $help . "\n<hr noshade size=\"1\">";
}

print STDOUT "$message
<form action=\"$cgipath\">
Jewish Holidays for:&nbsp;&nbsp;&nbsp;
<label for=\"year\">Year: <input name=\"year\"
id=\"year\" value=\"$year\" size=\"4\" maxlength=\"4\"></label>
<input type=\"hidden\" name=\"v\" value=\"1\">
&nbsp;&nbsp;&nbsp;
<label for=\"month\">Month:
<select name=\"month\" id=\"month\">
<option value=\"x\"$month{'0'}>- entire year -
";
    for ($i = 1; $i <= 12; $i++)
    {
	print STDOUT "<option value=\"$i\"$month{$i}>$MoY[$i]\n";
    }
    print STDOUT "</select></label>
<br>
<small>
Use all digits to specify a year. You probably aren't
interested in 93, but rather 1993.
</small>
<br><br>
";

    if ($opts{'c'} == 0)
    {
	print STDOUT
"(Candle lighting times are off.  Turn them on for:
<a href=\"${cgipath}?c=on&amp;geo=zip\">zip code</a>,
<a href=\"${cgipath}?c=on&amp;geo=city\">closest city</a>, or
<a href=\"${cgipath}?c=on&amp;geo=pos\">latitude/longitude</a>.)
<br><br>
";
    }
    else
    {
	print STDOUT 
"<input type=\"hidden\" name=\"c\" value=\"on\">
Include candle lighting times for ";
	if (defined $in{'geo'})
	{
	    print STDOUT "zip code:\n"
		if ($in{'geo'} eq 'zip');
	    print STDOUT "closest city:\n"
		if ($in{'geo'} eq 'city');
	    print STDOUT "latitude/longitude:\n"
		if ($in{'geo'} eq 'pos');
	}
	else
	{
	    print STDOUT "zip code:\n";
	}
	print STDOUT
"<br><small>(or <a href=\"${cgipath}?c=off\">turn them off</a>, or select by";
	if (defined $in{'geo'} && $in{'geo'} eq 'city')
	{
	    print STDOUT " <a\nhref=\"${cgipath}?c=on&amp;geo=zip\">zip code</a> or";
	    print STDOUT " <a\nhref=\"${cgipath}?c=on&amp;geo=pos\">latitude/longitude</a>";
	}
	elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
	{
	    print STDOUT " <a\nhref=\"${cgipath}?c=on&amp;geo=zip\">zip code</a> or";
	    print STDOUT " <a\nhref=\"${cgipath}?c=on&amp;geo=city\">closest city</a>"
	}
	else
	{
	    print STDOUT " <a
href=\"${cgipath}?c=on&amp;geo=city\">closest city</a> or <a
href=\"${cgipath}?c=on&amp;geo=pos\">latitude/longitude</a>";
	}
	print STDOUT ")</small>
<br>
<blockquote>";

    if (defined $in{'geo'} && $in{'geo'} eq 'city')
    {
	$in{'city'} = 'Jerusalem'
	    unless defined $in{'city'} && $in{'city'} !~ /^\s*$/;
	print STDOUT "
<input type=\"hidden\" name=\"geo\" value=\"city\">
<label for=\"city\">Closest City:
";

	print STDOUT "<select name=\"city\" id=\"city\">\n";
	foreach (sort keys %valid_cities)
	{
	    print STDOUT '<option';
	    print STDOUT ' selected' if $in{'city'} eq $_;
	    print STDOUT ">$_\n";
	}
	print STDOUT "</select>\n";

	print STDOUT "</label><br>\n";
    }
    elsif (defined $in{'geo'} && $in{'geo'} eq 'pos')
    {
	print STDOUT "
<input type=\"hidden\" name=\"geo\" value=\"pos\">
<label for=\"ladeg\"><input name=\"ladeg\" id=\"ladeg\" value=\"$in{'ladeg'}\"
size=\"3\" maxlength=\"2\">&nbsp;deg</label>&nbsp;&nbsp;<label
for=\"lamin\"><input name=\"lamin\" id=\"lamin\" value=\"$in{'lamin'}\"
size=\"2\" maxlength=\"2\">&nbsp;min</label>&nbsp;<select
name=\"ladir\">";
print STDOUT "<option\nvalue=\"n\"",
	($in{'ladir'} eq 'n' ? ' selected' : ''), ">North Latitude";
print STDOUT "<option\nvalue=\"s\"",
	($in{'ladir'} eq 's' ? ' selected' : ''), ">South Latitude";

print STDOUT "</select><br>
<label for=\"lodeg\"><input name=\"lodeg\" id=\"lodeg\" value=\"$in{'lodeg'}\"
size=\"3\" maxlength=\"3\">&nbsp;deg</label>&nbsp;&nbsp;<label
for=\"lomin\"><input name=\"lomin\" id=\"lomin\" value=\"$in{'lomin'}\"
size=\"2\" maxlength=\"2\">&nbsp;min</label>&nbsp;<select
name=\"lodir\">";

print STDOUT "<option\nvalue=\"w\"",
	($in{'lodir'} eq 'w' ? ' selected' : ''), ">West Longitude";
print STDOUT "<option\nvalue=\"e\"",
	($in{'lodir'} eq 'e' ? ' selected' : ''), ">East Longitude";
print STDOUT "</select><br>
";
    }
    else
    {
	print STDOUT "
<input type=\"hidden\" name=\"geo\" value=\"zip\">
<label for=\"zip\">Zip code: <input name=\"zip\"
id=\"zip\" value=\"$in{'zip'}\" size=\"5\" maxlength=\"5\"></label>
&nbsp;&nbsp;&nbsp;
";
    }

    if (!defined $in{'geo'} || $in{'geo'} ne 'city')
    {
	print STDOUT "<label for=\"tz\">Time zone:
<select name=\"tz\" id=\"tz\">
";

	print STDOUT 
	    "<option value=\"auto\"$tz{'auto'}>Attempt to auto-detect\n"
		if $in{'geo'} eq 'zip';

	print STDOUT 
"<option value=\"-5\"$tz{'-5'}>GMT -05:00 ($tz_names{'-5'})
<option value=\"-6\"$tz{'-6'}>GMT -06:00 ($tz_names{'-6'})
<option value=\"-7\"$tz{'-7'}>GMT -07:00 ($tz_names{'-7'})
<option value=\"-8\"$tz{'-8'}>GMT -08:00 ($tz_names{'-8'})
<option value=\"-9\"$tz{'-9'}>GMT -09:00 ($tz_names{'-9'})
<option value=\"-10\"$tz{'-10'}>GMT -10:00 ($tz_names{'-10'})
";

	print STDOUT
"<option value=\"-11\"$tz{'-11'}>GMT -11:00
<option value=\"-12\"$tz{'-12'}>GMT -12:00
<option value=\"12\"$tz{'12'}>GMT +12:00
<option value=\"11\"$tz{'11'}>GMT +11:00
<option value=\"10\"$tz{'10'}>GMT +10:00
<option value=\"9\"$tz{'9'}>GMT +09:00
<option value=\"8\"$tz{'8'}>GMT +08:00
<option value=\"7\"$tz{'7'}>GMT +07:00
<option value=\"6\"$tz{'6'}>GMT +06:00
<option value=\"5\"$tz{'5'}>GMT +05:00
<option value=\"4\"$tz{'4'}>GMT +04:00
<option value=\"3\"$tz{'3'}>GMT +03:00
<option value=\"2\"$tz{'2'}>GMT +02:00
<option value=\"1\"$tz{'1'}>GMT +01:00
<option value=\"0\"$tz{'0'}>Greenwich Mean Time
<option value=\"-1\"$tz{'-1'}>GMT -01:00
<option value=\"-2\"$tz{'-2'}>GMT -02:00
<option value=\"-3\"$tz{'-3'}>GMT -03:00
<option value=\"-4\"$tz{'-4'}>GMT -04:00
"  if (defined $in{'geo'} && $in{'geo'} eq 'pos');

	print STDOUT
"</select></label><br>
Daylight Savings Time:
<label for=\"usa\">
<input type=\"radio\" name=\"dst\" id=\"usa\" value=\"usa\"$opts_chk{'usa'}>
USA (except <small>AZ</small>, <small>HI</small>, and
<small>IN</small>)</label>
";
	print STDOUT
"<label for=\"israel\">
<input type=\"radio\" name=\"dst\" id=\"israel\" value=\"israel\"$opts_chk{'israel'}>
Israel</label>
"  if (defined $in{'geo'} && $in{'geo'} eq 'pos');

	print STDOUT
"<label for=\"none\">
<input type=\"radio\" name=\"dst\" id=\"none\" value=\"none\"$opts_chk{'none'}>
none</label><br>
";
    }

print STDOUT "<label for=\"m\">Havdalah minutes past sundown: <input
name=\"m\" id=\"m\" value=\"$havdalah\" size=\"3\"
maxlength=\"3\"></label><br>
</blockquote>
";
}
print STDOUT
"<table border=\"0\">
<tr><td>
<label for=\"a\"><input type=\"checkbox\" name=\"a\" id=\"a\"$opts_chk{'a'}>
Use ashkenazis hebrew</label>
</td><td>
<label for=\"o\"><input type=\"checkbox\" name=\"o\" id=\"o\"$opts_chk{'o'}>
Add days of the Omer</label>
</td></tr><tr><td>
<label for=\"x\"><input type=\"checkbox\" name=\"x\" id=\"x\"$opts_chk{'x'}>
Suppress Rosh Chodesh</label>
</td><td>
<label for=\"h\"><input type=\"checkbox\" name=\"h\" id=\"h\"$opts_chk{'h'}>
Suppress all default holidays</label>
</td></tr><tr><td colspan=\"2\">
<label for=\"s\"><input type=\"checkbox\" name=\"s\" id=\"s\"$opts_chk{'s'}>
Add weekly sedrot on Saturday</label>
(<label for=\"i\"><input type=\"checkbox\" name=\"i\" id=\"i\"$opts_chk{'i'}>
Use Israeli sedra scheme</label>)
</td></tr><tr><td colspan=\"2\">
<label for=\"d\"><input type=\"checkbox\" name=\"d\" id=\"d\"$opts_chk{'d'}>
Print hebrew date for the entire date range</label>
</td></tr><tr><td colspan=\"2\">
<label for=\"set\"><input type=\"checkbox\" name=\"set\" id=\"set\"$opts_chk{'set'}>
Save my preferences in a cookie</label>
(<a href=\"http://www.zdwebopedia.com/TERM/c/cookie.html\">What's
a cookie?</a>)
</td></tr>
</table>
<br><input type=\"submit\" value=\"Get Calendar\">
";

#  # for debugging only
#  if (defined $ENV{'HTTP_COOKIE'} && $ENV{'HTTP_COOKIE'} !~ /^\s*$/)
#  {
#      print STDOUT "<input type=\"hidden\" name=\"cookie\"\nvalue=\"";
#      $z = $ENV{'HTTP_COOKIE'};
#      $z =~ s/&/&amp;/g;
#      $z =~ s/</&lt;/g;
#      $z =~ s/>/&gt;/g;
#      $z =~ s/"/&quot;/g; #"#
#      print STDOUT $z, "\">\n";
#  }

print STDOUT "</form>\n$html_footer";

    close(STDOUT);
    exit(0);

    1;
}



sub results_page
{
    local($date) = $year;
    local($filename) = 'hebcal_' . $year;
    local($ycal) = (defined($in{'y'}) && $in{'y'} eq '1') ? 1 : 0;
    local($prev_url,$next_url,$prev_title,$next_title);

    if ($in{'month'} =~ /^\d+$/ && $in{'month'} >= 1 && $in{'month'} <= 12)
    {
	$filename .= '_' . $MoY_abbrev[$in{'month'}];
	$date = $MoY[$in{'month'}] . ' ' . $date;
    }

    if ($opts{'c'} == 1)
    {
	$filename .= '_';
	if (defined $in{'zip'})
	{
	    $filename .= $in{'zip'};
	}
	elsif (defined $in{'city'})
	{
	    $tmp = "\L$in{'city'}\E";
	    $tmp =~ s/ /_/g;
	    $filename .= $tmp;
	}
	else
        {
	    $filename .= 'geopos';
	}
    }

    $filename .= '.csv';

    local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    # next and prev urls
    if ($in{'month'} =~ /^\d+$/ && $in{'month'} >= 1 && $in{'month'} <= 12)
    {
	local($pm,$nm,$py,$ny);

	if ($in{'month'} == 1)
	{
	    $pm = 12;
	    $nm = 2;
	    $py = $year - 1;
	    $ny = $year;
	}
	elsif ($in{'month'} == 12)
	{
	    $pm = 11;
	    $nm = 1;
	    $py = $year;
	    $ny = $year + 1;
	}
	else
	{
	    $pm = $in{'month'} - 1;
	    $nm = $in{'month'} + 1;
	    $ny = $py = $year;
	}

	$prev_url = "$cgipath?year=" . $py . "&amp;month=" . $pm;
	while (($key,$val) = each(%in))
	{
	    $prev_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$prev_title = $MoY[$pm] . " " . $py;

	$next_url = "$cgipath?year=" . $ny . "&amp;month=" . $nm;
	while (($key,$val) = each(%in))
	{
	    $next_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$next_title = $MoY[$nm] . " " . $ny;
    }
    else
    {
	$prev_url = "$cgipath?year=" . ($year - 1);
	while (($key,$val) = each(%in))
	{
	    $prev_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year';
	}
	$prev_title = ($year - 1);

	$next_url = "$cgipath?year=" . ($year + 1);
	while (($key,$val) = each(%in))
	{
	    $next_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year';
	}
	$next_title = ($year + 1);
    }

    if ($opts{'set'}) {
	$newcookie = &gen_cookie();
	if (! defined $ENV{'HTTP_COOKIE'} || $ENV{'HTTP_COOKIE'} ne $newcookie)
	{
	    print STDOUT "Set-Cookie: ", $newcookie, "; expires=",
	    $expires_date, "; path=/; domain=www.radwin.org\015\012";
	}
    }

#    print STDOUT "Last-Modified: ", &http_date($time), "\015\012";
    print STDOUT "Expires: $expires_date\015\012";
    print STDOUT "Content-Type: text/html\015\012\015\012";

    print STDOUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\"
\t\"http://www.w3.org/TR/REC-html40/loose.dtd\">
<html><head>
<title>Hebcal: Jewish Calendar $date</title>
<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
<meta name=\"robots\" content=\"noindex\">
<link rel=\"start\" href=\"$cgipath\" title=\"Hebcal Interactive Jewish Calendar\">
<link rel=\"prev\" href=\"$prev_url\" title=\"$prev_title\">
<link rel=\"next\" href=\"$next_url\" title=\"$next_title\">
</head>
<body>
<table border=\"0\" width=\"100%\" cellpadding=\"0\" class=\"navbar\">
<tr valign=\"top\"><td><small>
<a href=\"/\">radwin.org</a> <tt>-&gt;</tt>
";

    print STDOUT "<a href=\"$cgipath";
    print STDOUT "?c=on&amp;geo=$in{'geo'}" if ($opts{'c'} == 1);
    print STDOUT "\">hebcal</a> <tt>-&gt;</tt>
$date</small>
<td align=\"right\"><small><a href=\"/search/\">Search</a></small>
</td></tr></table>
<h1>Jewish Calendar $date</h1>
";

    if ($opts{'c'} == 1)
    {
	print STDOUT "<dl>\n<dt>", $city_descr, "\n";
	print STDOUT "<dd><small>", $lat_descr, "</small>\n" if $lat_descr ne '';
	print STDOUT "<dd><small>", $long_descr, "</small>\n" if $long_descr ne '';
	print STDOUT "<dd><small>", $dst_tz_descr, "</small>\n" if $dst_tz_descr ne '';
	print STDOUT "</dl>\n";
    }

    print STDOUT "Go to:\n";
    print STDOUT "<a href=\"$prev_url\">", $prev_title, "</a> |\n";
    print STDOUT "<a href=\"$next_url\">", $next_title, "</a><br>\n";

    print STDOUT "<p><a href=\"${cgipath}index.html/$filename?dl=1";
    while (($key,$val) = each(%in))
    {
	print STDOUT "&amp;$key=", &url_escape($val);
    }
    print STDOUT "\">Download\nas an Outlook CSV file</a>";

    if ($ycal == 0)
    {
	print STDOUT " - <a href=\"$cgipath?y=1";
	while (($key,$val) = each(%in))
	{
	    print STDOUT "&amp;$key=", &url_escape($val);
	}
	print STDOUT "\">Show\nYahoo! Calendar links</a>";
    }
    print STDOUT "</p>\n";

print STDOUT 
"<div><small>
<p>Your personal <a href=\"http://calendar.yahoo.com/\">Yahoo!
Calendar</a> is a free web-based calendar that can synchronize with Palm
Pilot, Outlook, etc.</p>
<ul>
<li>If you wish to upload <strong>all</strong> of the below holidays to
your Yahoo!  Calendar, do the following:
<ol>
<li>Click the \"Download as an Outlook CSV file\" link above.
<li>Save the hebcal CSV file on your computer.
<li>Go to <a href=\"http://calendar.yahoo.com/?v=81\">options page</a> of
Yahoo! Calendar.
<li>Find the \"Import from Outlook\" section and choose \"Import Now\"
to import your CSV file to your online calendar.
</ol>
<li>To import selected holidays <strong>one at a time</strong>, use
the \"add\" links below.  These links will pop up a new browser window
so you can keep this window open.
</ul></small></div>
" if $ycal;

    $cmd_pretty = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename
    print STDOUT "<!-- $cmd_pretty -->\n";
    print STDOUT "<pre>";
    open(HEBCAL,"$cmd |") ||
	&CgiDie("Script Error: can't run hebcal",
		"\nCommand was \"$cmd\".\n" .
		"Please <a href=\"mailto:$author" .
		"\">e-mail Michael</a> to tell him that hebcal is broken.");

    $prev = '';
    while(<HEBCAL>)
    {
	next if $_ eq $prev;
	$prev = $_;
	chop;
	($date,$descr) = split(/ /, $_, 2);
	($subj,$date,$start_time,$end_date,$end_time,$all_day,
	 $hr,$min,$month,$day,$year) =
	     &parse_date_descr($date,$descr);

	if ($ycal)
	{
	    $ST  = sprintf("%04d%02d%02d", $year, $month, $day);
	    if ($hr >= 0 && $min >= 0)
	    {
		local($loc) = (defined $in{'city'} || defined $in{'zip'}) ?
		    "in $city_descr" : '';
	        $loc =~ s/\s*&nbsp;\s*/ /g;

		$hr += 12 if $hr < 12 && $hr > 0;
		$ST .= sprintf("T%02d%02d00", $hr, $min);

		if ($in{'tz'} !~ /^\s*$/)
		{
		    $abstz = $in{'tz'} >= 0 ? $in{'tz'} : -$in{'tz'};
		    $signtz = $in{'tz'} < 0 ? '-' : '';

		    $ST .= sprintf("Z%s%02d00", $signtz, $abstz);
		}

		$ST .= "&amp;DESC=" . &url_escape($loc)
		    if $loc ne '';
	    }

	    print STDOUT
		"<a target=\"_calendar\" href=\"http://calendar.yahoo.com/";
	    print STDOUT "?v=60&amp;TYPE=16&amp;ST=$ST&amp;TITLE=",
		&url_escape($subj), "&amp;VIEW=d\">add</a> ";
	}

	$descr =~ s/&/&amp;/g;
	$descr =~ s/</&lt;/g;
	$descr =~ s/>/&gt;/g;

	$dow = ($year > 1969 && $year < 2038) ? 
	    $DoW[&get_dow($year - 1900, $month - 1, $day)] . ' ' :
		'';
	printf STDOUT "%s%04d-%02d-%02d  %s\n",
	$dow, $year, $month, $day, $descr;
    }
    close(HEBCAL);

    print STDOUT "</pre>", "Go to:\n";
    print STDOUT "<a href=\"$prev_url\">", $prev_title, "</a> |\n";
    print STDOUT "<a href=\"$next_url\">", $next_title, "</a><br>\n";

    print STDOUT  $html_footer;

    close(STDOUT);
    exit(0);

    1;
}

sub get_dow
{
    local($year,$mon,$mday) = @_;
    local($sec,$min,$hour,$wday,$yday,$isdst);
    local($time);

    $wday = $yday = $isdst = '';
    $sec = $min = $hour = 0;
    $time = &timelocal($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

    (localtime($time))[6];
}

sub parse_date_descr
{
    local($date,$descr) = @_;

    ($month,$day,$year) = split(/\//, $date);
    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hr,$min) = ($1,$2,$3);
	$start_time = sprintf("\"%d:%02d PM\"", $hr, $min);
#	$min += 15;
#	if ($min >= 60)
#	{
#	    $hr++;
#	    $min -= 60;
#	}
#	$end_time = sprintf("\"%d:%02d PM\"", $hr, $min);
#	$end_date = $date;
	$end_time = $end_date = '';
	$all_day = '"false"';
    }
    else
    {
	$hr = $min = -1;
	$start_time = $end_time = $end_date = '';
	$all_day = '"true"';
	$subj = $descr;
    }
    
    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    ($subj,$date,$start_time,$end_date,$end_time,$all_day,
     $hr,$min,$month,$day,$year);
}

sub url_escape
{
    local($_) = @_;
    local($res) = '';

    foreach (split(//))
    {
	if (/ /)
	{
	    $res .= '+';
	}
	elsif (/[^a-zA-Z0-9_.-]/)
	{
	    $res .= sprintf("%%%02X", ord($_));
	}
	else
	{
	    $res .= $_;
	}
    }

    $res;
}

sub http_date
{
    local($time) = @_;
    local(@MoY);
    local($sec,$min,$hour,$mday,$mon,$year,$wday) =
	gmtime($time);

    @MoY = ('Jan','Feb','Mar','Apr','May','Jun',
	    'Jul','Aug','Sep','Oct','Nov','Dec');
    $year += 1900;

    sprintf("%s, %02d %s %4d %02d:%02d:%02d GMT",
	    $DoW[$wday],$mday,$MoY[$mon],$year,$hour,$min,$sec);
}

sub gen_cookie {
    local($retval);

    $retval = 'C=t=' . time;

    if ($opts{'c'}) {
	if ($in{'geo'} eq 'zip') {
	    $retval .= '&zip=' . $in{'zip'};
	    $retval .= '&dst=' . $in{'dst'}
	        if defined $in{'dst'} && $in{'dst'} !~ /^\s*$/;
	    $retval .= '&tz=' . $in{'tz'}
	        if defined $in{'tz'} && $in{'tz'} !~ /^\s*$/;
	} elsif ($in{'geo'} eq 'city') {
	    $retval .= '&city=' . &url_escape($in{'city'});
	} elsif ($in{'geo'} eq 'pos') {
	    $retval .= '&lodeg=' . $in{'lodeg'};
	    $retval .= '&lomin=' . $in{'lomin'};
	    $retval .= '&lodir=' . $in{'lodir'};
	    $retval .= '&ladeg=' . $in{'ladeg'};
	    $retval .= '&lamin=' . $in{'lamin'};
	    $retval .= '&ladir=' . $in{'ladir'};
	    $retval .= '&dst=' . $in{'dst'}
	        if defined $in{'dst'} && $in{'dst'} !~ /^\s*$/;
	    $retval .= '&tz=' . $in{'tz'}
	        if defined $in{'tz'} && $in{'tz'} !~ /^\s*$/;
	}
	$retval .= '&m=' . $in{'m'} if defined $in{'m'} && $in{'m'} !~ /^\s*$/;
    }

    foreach (@opts)
    {
	next if $_ eq 'c';
	next if length($_) > 1;
	$retval .= "&$_=" . $in{$_} if defined $in{$_} && $in{$_} !~ /^\s*$/;
    }

    $retval;
}


sub process_cookie {
    local($cookieval) = @_;
    local(%cookie);
    local($status);
    local(%ENV);

    $ENV{'QUERY_STRING'} = $cookieval;
    $ENV{'REQUEST_METHOD'} = 'GET';
    $status = &ReadParse(*cookie);

    if (defined $status && $status > 0) {
	if (! defined $in{'c'} || $in{'c'} eq 'on' || $in{'c'} eq '1') {
	    if (defined $cookie{'zip'} && $cookie{'zip'} =~ /^\d\d\d\d\d$/ &&
		(! defined $in{'geo'} || $in{'geo'} eq 'zip')) {
		$in{'zip'} = $cookie{'zip'};
		$in{'geo'} = 'zip';
		$in{'c'} = 'on';
		$in{'dst'} = $cookie{'dst'}
		    if (defined $cookie{'dst'} && ! defined $in{'dst'});
		$in{'tz'} = $cookie{'tz'}
		    if (defined $cookie{'tz'} && ! defined $in{'tz'});
	    } elsif (defined $cookie{'city'} && $cookie{'city'} !~ /^\s*$/ &&
		(! defined $in{'geo'} || $in{'geo'} eq 'city')) {
		$in{'city'} = $cookie{'city'};
		$in{'geo'} = 'city';
		$in{'c'} = 'on';
	    } elsif (defined $cookie{'lodeg'} &&
		     defined $cookie{'lomin'} &&
		     defined $cookie{'lodir'} &&
		     defined $cookie{'ladeg'} &&
		     defined $cookie{'lamin'} &&
		     defined $cookie{'ladir'} &&
		     (! defined $in{'geo'} || $in{'geo'} eq 'pos')) {
		$in{'lodeg'} = $cookie{'lodeg'};
		$in{'lomin'} = $cookie{'lomin'};
		$in{'lodir'} = $cookie{'lodir'};
		$in{'ladeg'} = $cookie{'ladeg'};
		$in{'lamin'} = $cookie{'lamin'};
		$in{'ladir'} = $cookie{'ladir'};
		$in{'geo'} = 'pos';
		$in{'c'} = 'on';
		$in{'dst'} = $cookie{'dst'}
		    if (defined $cookie{'dst'} && ! defined $in{'dst'});
		$in{'tz'} = $cookie{'tz'}
		    if (defined $cookie{'tz'} && ! defined $in{'tz'});
	    }
	}

	$in{'m'} = $cookie{'m'}
	   if (defined $cookie{'m'} && ! defined $in{'m'});

	foreach (@opts)
	{
	    next if $_ eq 'c';
	    $in{$_} = $cookie{$_}
	        if (! defined $in{$_} && defined $cookie{$_});
	}
    }

    $status;
}

if ($^W && 0)
{
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
}

1;
