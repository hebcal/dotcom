#!/usr/local/bin/perl5 -w

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

package hebcal;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;

$author = 'michael@radwin.org';
$expires_date = 'Thu, 15 Apr 2010 20:00:00 GMT';

# constants for DBA export
$PALM_DBA_MAGIC      = 1145176320;
$PALM_DBA_INTEGER    = 1;
$PALM_DBA_DATE       = 3;
$PALM_DBA_BOOL       = 6;
$PALM_DBA_REPEAT     = 7;
$PALM_DBA_MAXENTRIES = 2500;

@DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
@MoY_short =
    ('Jan','Feb','Mar','Apr','May','Jun',
     'Jul','Aug','Sep','Oct','Nov','Dec');
%MoY_long = (
	     'x' => '- Entire year -',
	     1   => 'January',
	     2   => 'February',
	     3   => 'March',
	     4   => 'April',
	     5   => 'May',
	     6   => 'June',
	     7   => 'July',
	     8   => 'August',
	     9   => 'September',
	     10  => 'October',
	     11  => 'November',
	     12  => 'December',
	     );

# these states are known to span multiple timezones:
# AK, FL, ID, IN, KS, KY, MI, ND, NE, OR, SD, TN, TX
%known_timezones =
    (
     '99692'	=>	-10,	# AK west of 170W
     '99547'	=>	-10,	# AK west of 170W
     '99660'	=>	-10,	# AK west of 170W
     '99742'	=>	-10,	# AK west of 170W
     '98791'	=>	-10,	# AK west of 170W
     '99769'	=>	-10,	# AK west of 170W
     '996'	=>	'??',	# west AK
     '324'	=>	-6,	# west FL
     '325'	=>	-6,	# west FL
     '463'	=>	'??',	# Jasper, Lake, LaPorte, Newton, and
     '464'	=>	'??',	#  Porter counties, IN
     '476'	=>	'??',	# Gibson, Posey, Spencer, Vanderburgh,
     '477'	=>	'??',	#  and Warrick counties, IN
     '677'	=>	'??',	# west KS
     '678'	=>	'??',	# west KS
     '679'	=>	'??',	# west KS
     '799'	=>	-7,	# el paso, TX
     '798'	=>	'??',	# west TX
     '838'	=>	-8,	# north ID
     '835'	=>	-8,	# north ID
     '979'	=>	'??',	# east OR
     '49858'	=>	-6,	# Menominee, MI
     '498'	=>	'??',	# west MI
     '499'	=>	'??',	# west MI
     'KS'	=>	-6,
     'IN'	=>	-5,
     'MI'	=>	-5,
     'ID'	=>	-7,
     'OR'	=>	-8,
     'FL'	=>	-5,
     'HI'	=>	-10,
     'AK'	=>	-9,
     'CA'	=>	-8,
     'NV'	=>	-8,
     'WA'	=>	-8,
     'MT'	=>	-7,
     'AZ'	=>	-7,
     'UT'	=>	-7,
     'WY'	=>	-7,
     'CO'	=>	-7,
     'NM'	=>	-7,
     'TX'	=>	-6,
     'OK'	=>	-6,
     'IL'	=>	-6,
     'WI'	=>	-6,
     'MN'	=>	-6,
     'IA'	=>	-6,
     'MO'	=>	-6,
     'AR'	=>	-6,
     'LA'	=>	-6,
     'MS'	=>	-6,
     'AL'	=>	-6,
     'OH'	=>	-5,
     'RI'	=>	-5,
     'MA'	=>	-5,
     'NY'	=>	-5,
     'NH'	=>	-5,
     'VT'	=>	-5,
     'ME'	=>	-5,
     'CT'	=>	-5,
     'NJ'	=>	-5,
     'DE'	=>	-5,
     'DC'	=>	-5,
     'PA'	=>	-5,
     'WV'	=>	-5,
     'VA'	=>	-5,
     'NC'	=>	-5,
     'SC'	=>	-5,
     'GA'	=>	-5,
     'MD'	=>	-5,
     'PR'	=>	-5,
     );

# these cities should have DST set to 'none'
%city_nodst =
    (
     'Berlin'		=>	1,
     'Bogota'		=>	1,
     'Buenos Aires'	=>	1,
     'Johannesburg'	=>	1,
     'London'		=>	1,
     'Mexico City'	=>	1,
     'Toronto'		=>	1,
     'Vancouver'	=>	1,
     );

%city_tz =
    (
     'Atlanta'		=>	-5,
     'Austin'		=>	-6,
     'Berlin'		=>	1,
     'Baltimore'	=>	-5,
     'Bogota'		=>	-5,
     'Boston'		=>	-5,
     'Buenos Aires'	=>	-3,
     'Buffalo'		=>	-5,
     'Chicago'		=>	-6,
     'Cincinnati'	=>	-5,
     'Cleveland'	=>	-5,
     'Dallas'		=>	-6,
     'Denver'		=>	-7,
     'Detroit'		=>	-5,
     'Gibraltar'	=>	-10,
     'Hawaii'		=>	-10,
     'Houston'		=>	-6,
     'Jerusalem'	=>	2,
     'Johannesburg'	=>	1,
     'London'		=>	0,
     'Los Angeles'	=>	-8,
     'Miami'		=>	-5,
     'Mexico City'	=>	-6,
     'New York'		=>	-5,
     'Omaha'		=>	-7,
     'Philadelphia'	=>	-5,
     'Phoenix'		=>	-7,
     'Pittsburgh'	=>	-5,
     'Saint Louis'	=>	-6,
     'San Francisco'	=>	-8,
     'Seattle'		=>	-8,
     'Toronto'		=>	-5,
     'Vancouver'	=>	-8,
     'Washington DC'	=>	-5,
     );

# this doesn't work for weeks that have double parashiot
# todo: automatically get URL from hebrew year
%sedrot = (
   "Bereshit"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Bereshis"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Noach"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Lech-Lecha"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Vayera"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Chayei Sara" =>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Toldot"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Toldos"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Vayetzei"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Vayishlach"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Vayeshev"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Miketz"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Vayigash"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Vayechi"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#gen',
   "Shemot"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Shemos"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Vaera"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Bo"		=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Beshalach"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Yitro"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Yisro"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Mishpatim"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Terumah"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Tetzaveh"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Ki Tisa"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Ki Sisa"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Vayakhel"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Pekudei"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#exo',
   "Vayikra"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Tzav"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Shmini"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Tazria"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Sazria"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Metzora"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Achrei Mot"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Achrei Mos"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Kedoshim"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Emor"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Behar"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Bechukotai"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Bechukosai"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#lev',
   "Bamidbar"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Nasso"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Beha'alotcha" =>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Beha'aloscha" =>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Sh'lach"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Korach"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Chukat"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Chukas"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Balak"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Pinchas"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Matot"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Matos"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Masei"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#num',
   "Devarim"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#deu',
   "Vaetchanan"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#deu',
   "Vaeschanan"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#deu',
   "Eikev"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#deu',
   "Re'eh"	=>	'http://www.virtualjerusalem.com/education/education/ohr/tw/5759/devarim/reeh.htm',
   "Shoftim"	=>	'http://www.virtualjerusalem.com/education/education/ohr/tw/5759/devarim/shoftim.htm',
   "Ki Teitzei"	=>	'http://www.virtualjerusalem.com/education/education/ohr/tw/5759/devarim/kiseitze.htm',
   "Ki Seitzei"	=>	'http://www.virtualjerusalem.com/education/education/ohr/tw/5759/devarim/kiseitze.htm',
   "Ki Tavo"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#deu',
   "Ki Savo"	=>	'http://learn.jtsa.edu/topics/parashah/archive.shtml#deu',
   "Nitzavim"	=>	'http://www.virtualjerusalem.com/education/education/ohr/tw/5759/devarim/nitzavim.htm',
   "Vayeilech"	=>	'http://www.virtualjerusalem.com/education/education/ohr/tw/5758/devarim/vayelech.htm',
   "Ha'Azinu"	=>	'http://www.virtualjerusalem.com/education/education/ohr/tw/5759/devarim/haazinu.htm',
	   );

%tz_names = (
     'auto' => '- Attempt to auto-detect -',
     '-5'   => 'GMT -05:00 (U.S. Eastern)',
     '-6'   => 'GMT -06:00 (U.S. Central)',
     '-7'   => 'GMT -07:00 (U.S. Mountain)',
     '-8'   => 'GMT -08:00 (U.S. Pacific)',
     '-9'   => 'GMT -09:00 (U.S. Alaskan)',
     '-10'  => 'GMT -10:00 (U.S. Hawaii)',
     '-11'  => 'GMT -11:00',
     '-12'  => 'GMT -12:00',
     '12'   => 'GMT +12:00',
     '11'   => 'GMT +11:00',
     '10'   => 'GMT +10:00',
     '9'    => 'GMT +09:00',
     '8'    => 'GMT +08:00',
     '7'    => 'GMT +07:00',
     '6'    => 'GMT +06:00',
     '5'    => 'GMT +05:00',
     '4'    => 'GMT +04:00',
     '3'    => 'GMT +03:00',
     '2'    => 'GMT +02:00',
     '1'    => 'GMT +01:00',
     '0'    => 'Greenwich Mean Time',
     '-1'   => 'GMT -01:00',
     '-2'   => 'GMT -02:00',
     '-3'   => 'GMT -03:00',
     '-4'   => 'GMT -04:00',
     );

local($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
$year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($hhmts) = "<!-- hhmts start -->
Last modified: Tue May 30 16:22:11 PDT 2000
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated:\n/g;

$html_footer = "<hr
noshade size=\"1\"><small>$hhmts ($rcsrev)<br><br>Copyright
&copy; $year <a href=\"/michael/contact.html\">Michael J. Radwin</a>.
All rights reserved.<br><a
href=\"/michael/projects/hebcal/\">Frequently
asked questions about this service.</a></small></body></html>
";

# boolean options
@opts = ('c','o','s','i','a','d','D');
$cmd  = "/home/users/mradwin/bin/hebcal";

# process form params
$q = new CGI;
$q->delete('.s');		# we don't care about submit button

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;
my($server_name) = $q->server_name();
$server_name =~ s/^www\.//;

$q->default_dtd("-//W3C//DTD HTML 4.0 Transitional//EN\"\n" .
		"\t\"http://www.w3.org/TR/REC-html40/loose.dtd");

if (! $q->param('v') &&
    defined $q->raw_cookie() &&
    $q->raw_cookie() =~ /[\s;,]*C=([^\s,;]+)/)
{
    &process_cookie($1);
}

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
foreach $key ($q->param())
{
    $val = $q->param($key);
    $val =~ s/[^\w\s-]//g;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

# decide whether this is a results page or a blank form
&form('') unless $q->param('v');

&form("Please specify a year.")
    if !defined $q->param('year') || $q->param('year') eq '';

&form("Sorry, invalid year\n<b>" . $q->param('year') . "</b>.")
    if $q->param('year') !~ /^\d+$/ || $q->param('year') == 0;

&form("Sorry, invalid Havdalah minutes\n<b>" . $q->param('m') . "</b>.")
    if defined $q->param('m') &&
    $q->param('m') ne '' && $q->param('m') !~ /^\d+$/;

&form("Please select at least one event option.")
    if ((!defined $q->param('nh') || $q->param('nh') eq 'off') &&
	(!defined $q->param('nx') || $q->param('nx') eq 'off') &&
	(!defined $q->param('o') || $q->param('o') eq 'off') &&
	(!defined $q->param('c') || $q->param('c') eq 'off') &&
	(!defined $q->param('d') || $q->param('d') eq 'off') &&
	(!defined $q->param('s') || $q->param('s') eq 'off'));

if ($q->param('c') && $q->param('c') ne 'off' &&
    defined $q->param('city'))
{
    &form("Sorry, invalid city\n<b>" . $q->param('city') . "</b>.")
	unless defined($city_tz{$q->param('city')});

    $q->param('geo','city');
    $q->param('tz',$city_tz{$q->param('city')});
    $q->delete('dst');

    $cmd .= " -C '" . $q->param('city') . "'";

    $city_descr = "Closest City: " . $q->param('city');
    $lat_descr  = '';
    $long_descr = '';
    $dst_tz_descr = '';
}
elsif (defined $q->param('lodeg') && defined $q->param('lomin') &&
       defined $q->param('lodir') &&
       defined $q->param('ladeg') && defined $q->param('lamin') &&
       defined $q->param('ladir'))
{
    &form("Sorry, all latitude/longitude\narguments must be numeric.")
	if (($q->param('lodeg') !~ /^\d*$/) ||
	    ($q->param('lomin') !~ /^\d*$/) ||
	    ($q->param('ladeg') !~ /^\d*$/) ||
	    ($q->param('lamin') !~ /^\d*$/));

    $q->param('lodir','w') unless ($q->param('lodir') eq 'e');
    $q->param('ladir','n') unless ($q->param('ladir') eq 's');

    $q->param('lodeg',0) if $q->param('lodeg') eq '';
    $q->param('lomin',0) if $q->param('lomin') eq '';
    $q->param('ladeg',0) if $q->param('ladeg') eq '';
    $q->param('lamin',0) if $q->param('lamin') eq '';

    &form("Sorry, longitude degrees\n" .
	  "<b>" . $q->param('lodeg') . "</b> out of valid range 0-180.")
	if ($q->param('lodeg') > 180);

    &form("Sorry, latitude degrees\n" .
	  "<b>" . $q->param('ladeg') . "</b> out of valid range 0-90.")
	if ($q->param('ladeg') > 90);

    &form("Sorry, longitude minutes\n" .
	  "<b>" . $q->param('lomin') . "</b> out of valid range 0-60.")
	if ($q->param('lomin') > 60);

    &form("Sorry, latitude minutes\n" .
	  "<b>" . $q->param('lamin') . "</b> out of valid range 0-60.")
	if ($q->param('lamin') > 60);

    ($long_deg,$long_min,$lat_deg,$lat_min) =
	($q->param('lodeg'),$q->param('lomin'),
	 $q->param('ladeg'),$q->param('lamin'));

    $q->param('dst','none')
	unless $q->param('dst');
    $q->param('tz','0')
	unless $q->param('tz');
    $q->param('geo','pos');

    $city_descr = "Geographic Position";
    $lat_descr  = "${lat_deg}d${lat_min}' " .
	uc($q->param('ladir')) . " latitude";
    $long_descr = "${long_deg}d${long_min}' " .
	uc($q->param('lodir')) . " longitude";
    $dst_tz_descr = "Daylight Saving Time: " .
	$q->param('dst') . "</small>\n<dd><small>Time zone: " .
	    $tz_names{$q->param('tz')};

    # don't multiply minutes by -1 since hebcal does it internally
    $long_deg *= -1  if ($q->param('lodir') eq 'e');
    $lat_deg  *= -1  if ($q->param('ladir') eq 's');

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}
elsif ($q->param('c') && $q->param('c') ne 'off' &&
       defined $q->param('zip'))
{
    $q->param('dst','usa')
	unless $q->param('dst');
    $q->param('tz','auto')
	unless $q->param('tz');
    $q->param('geo','zip');

    &form("Please specify a 5-digit zip code\n" .
	  "OR uncheck the candle lighting times box.")
	if $q->param('zip') eq '';

    &form("Sorry, <b>" . $q->param('zip') . "</b> does\n" .
	  "not appear to be a 5-digit zip code.")
	unless $q->param('zip') =~ /^\d\d\d\d\d$/;

    $dbmfile = 'zips.db';
    tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	|| die "Can't tie $dbmfile: $!\n";

    $val = $DB{$q->param('zip')};
    untie(%DB);

    &form("Sorry, can't find\n".  "<b>" . $q->param('zip') .
	  "</b> in the zip code database.\n",
          "<ul><li>Please try a nearby zip code or select candle\n" .
	  "lighting times by\n" .
          "<a href=\"" . $script_name .
	  "?c=on&amp;geo=city\">city</a> or\n" .
          "<a href=\"" . $script_name .
	  "?c=on&amp;geo=pos\">latitude/longitude</a></li></ul>")
	unless defined $val;

    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));

    if (($state eq 'HI' || $state eq 'AZ') &&
	$q->param('dst') eq 'usa')
    {
	$q->param('dst','none');
    }

    my(@city) = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = lc($_);
	$_ = "\u$_";		# inital cap
	$city .= $_;
    }

    $city_descr = "$city, $state &nbsp;" . $q->param('zip');

    if ($q->param('tz') !~ /^-?\d+$/)
    {
	$ok = 0;
	if (defined $known_timezones{$q->param('zip')})
	{
	    if ($known_timezones{$q->param('zip')} ne '??')
	    {
		$q->param('tz',$known_timezones{$q->param('zip')});
		$ok = 1;
	    }
	}
	elsif (defined $known_timezones{substr($q->param('zip'),0,3)})
	{
	    if ($known_timezones{substr($q->param('zip'),0,3)} ne '??')
	    {
		$q->param('tz',$known_timezones{substr($q->param('zip'),0,3)});
		$ok = 1;
	    }
	}
	elsif (defined $known_timezones{$state})
	{
	    if ($known_timezones{$state} ne '??')
	    {
		$q->param('tz',$known_timezones{$state});
		$ok = 1;
	    }
	}

	if ($ok == 0)
	{
	    &form("Sorry, can't auto-detect\n" .
		  "timezone for <b>" . $city_descr . "</b>\n".
		  "(state <b>" . $state . "</b> spans multiple time zones).",
		  "<ul><li>Please select your time zone below.</li></ul>");
	}
    }

    $lat_descr  = "${lat_deg}d${lat_min}' N latitude";
    $long_descr = "${long_deg}d${long_min}' W longitude";
    $dst_tz_descr = "Daylight Saving Time: " .
	$q->param('dst') . "</small>\n<dd><small>Time zone: " .
	    $tz_names{$q->param('tz')};

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}
else
{
    $q->delete('c');
    $q->delete('zip');
    $q->delete('city');
    $q->delete('geo');
}

foreach (@opts)
{
    $cmd .= ' -' . $_
	if defined $q->param($_) &&
	    ($q->param($_) eq 'on' || $q->param($_) eq '1');
}

$cmd .= ' -h' if !defined $q->param('nh') || $q->param('nh') eq 'off';
$cmd .= ' -x' if !defined $q->param('nx') || $q->param('nx') eq 'off';

if ($q->param('c') && $q->param('c') ne 'off')
{
    $cmd .= " -m " . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    $cmd .= " -z " . $q->param('tz')
	if (defined $q->param('tz') && $q->param('tz') ne '');

    $cmd .= " -Z " . $q->param('dst')
	if (defined $q->param('dst') && $q->param('dst') ne '');
}

$cmd .= " " . $q->param('month')
    if (defined $q->param('month') && $q->param('month') =~ /^\d+$/ &&
	$q->param('month') >= 1 && $q->param('month') <= 12);

$cmd .= " " . $q->param('year');


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

sub invoke_hebcal {
    local($cmd) = @_;
    local(*HEBCAL,@events,$prev,$loc,$_);

    @events = ();
    open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";

    $prev = '';
    $loc = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';
    $loc =~ s/\s*&nbsp;\s*/ /g;

    while(<HEBCAL>)
    {
	next if $_ eq $prev;
	$prev = $_;
	chop;
	($date,$descr) = split(/ /, $_, 2);

	push(@events,
	     join("\cA", &parse_date_descr($date,$descr),$descr,$loc));
    }
    close(HEBCAL);

    @events;
}

sub dba_display {
    local(@events) = &invoke_hebcal($cmd);
    local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;
    print $q->header(-type =>
		     "application/x-palm-dba; filename=\"$path_info\"",
		     -content_disposition =>
		     "inline; filename=$path_info",
		     -last_modified => &http_date($time));

    &dba_header($path_info);
    &dba_contents(@events);
}

sub csv_display {
    local(@events) = &invoke_hebcal($cmd);
    local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;
    print $q->header(-type => "text/x-csv; filename=\"$path_info\"",
		     -content_disposition =>
		     "inline; filename=$path_info",
		     -last_modified => &http_date($time));

    $endl = "\012";			# default Netscape and others
    if (defined $q->user_agent() && $q->user_agent() !~ /^\s*$/)
    {
	$endl = "\015\012"
	    if $q->user_agent() =~ /Microsoft Internet Explorer/;
	$endl = "\015\012" if $q->user_agent() =~ /MSP?IM?E/;
    }

    print STDOUT "\"Subject\",\"Start Date\",\"Start Time\",\"End Date\",",
    "\"End Time\",\"All day event\",\"Description\",",
    "\"Show time as\"$endl";

    foreach (@events)
    {
	($subj,$date,$start_time,$end_date,$end_time,$all_day,
	 $hour,$min,$mon,$mday,$year,$descr,$loc) = split(/\cA/);

	$loc =~ s/,//g;
	print STDOUT '"', $subj, '","', $date, '",', $start_time, ',',
	    ($end_date eq '' ? '' : "\"$end_date\""),
	    ',', $end_time, ',', $all_day, ',"',
	    ($start_time eq '' ? '' : $loc), '","3"', $endl;
    }

    1;
}

sub form
{
    local($message,$help) = @_;
    my($key,$val,$JSCRIPT);

    $JSCRIPT=<<JSCRIPT_END;
function s1(geo) {
document.f1.geo.value=geo;
document.f1.c.value='on';
document.f1.v.value='0';
document.f1.submit();
return false;
}
function s2() {
if (document.f1.nh.checked == false) {
document.f1.nx.checked = false;
}
return false;
}
function s3() {
if (document.f1.i.checked == true) {
document.f1.s.checked = true;
}
return false;
}
function s4() {
if (document.f1.s.checked == false) {
document.f1.i.checked = false;
}
return false;
}
function s5() {
if (document.f1.nx.checked == true) {
document.f1.nh.checked = true;
}
}
JSCRIPT_END

    print STDOUT $q->header(),
    $q->start_html(-title => "Hebcal Interactive Jewish Calendar",
		   -target=>'_top',
		   -head => [
			   "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			   $q->Link({-rel => 'SCHEMA.dc',
				     -href => 'http://purl.org/metadata/dublin_core_elements'}),
			   $q->Link({-rev => 'made',
				     -href => "mailto:$author"}),
			   ],
		   -meta => {
		       'description' =>
		       'Generates a list of Jewish holidays and candle lighting times customized to your zip code, city, or latitude/longitude',

		       'keywords' =>
		       'hebcal, Jewish calendar, Hebrew calendar, candle lighting, Shabbat, Havdalah, sedrot, Sadinoff',

		       'DC.Title' => 'Hebcal Interactive Jewish Calendar',
		       'DC.Creator.PersonalName' => 'Radwin, Michael',
		       'DC.Creator.PersonalName.Address' => $author,
		       'DC.Subject' => 'Jewish calendar, Hebrew calendar, hebcal',
		       'DC.Type' => 'Text.Form',
		       'DC.Identifier' => "http://www." .
			   $server_name . $script_name,
		       'DC.Language' => 'en',
		       'DC.Date.X-MetadataLastModified' => '1999-12-24',
		       },
		   -script=>$JSCRIPT,
		   ),
    "<table border=\"0\" width=\"100%\" cellpadding=\"0\"\nclass=\"navbar\">",
    "<tr valign=\"top\"><td><small>",
    "<a\nhref=\"/\">$server_name</a>\n<tt>-&gt;</tt>\n",
    "hebcal</small></td>",
    "<td align=\"right\"><small><a\n",
    "href=\"/search/\">Search</a></small>",
    "</td></tr></table>",
    "<h1>Hebcal\nInteractive Jewish Calendar</h1>";

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">";
    }

    print STDOUT $message, "\n",
    "<form id=\"f1\" name=\"f1\"\naction=\"",
    $script_name, "\">",
    "<strong>Jewish Holidays for:</strong>&nbsp;&nbsp;&nbsp;\n",
    "<label for=\"year\">Year:\n",
    $q->textfield(-name => 'year',
		  -id => 'year',
		  -default => $year,
		  -size => 4,
		  -maxlength => 4),
    "</label>\n",
    $q->hidden(-name => 'v',-value => 1,-override => 1),
    "\n&nbsp;&nbsp;&nbsp;\n",
    "<label for=\"month\">Month:\n",
    $q->popup_menu(-name => 'month',
		   -id => 'month',
		   -values => ['x',1..12],
		   -default => $mon + 1,
		   -labels => \%MoY_long),
    "</label>\n",
    "<br>",
    $q->small("Use all digits to specify a year.\nYou probably aren't",
	      "interested in 93, but rather 1993.\n");

    print STDOUT "<p><strong>Include events:</strong>",
    "<br><label\nfor=\"nh\">",
    $q->checkbox(-name => 'nh',
		 -id => 'nh',
		 -checked => 'checked',
		 -onClick => "s2()",
		 -label => "\nAll default Holidays"),
    "</label><small>(<a\n",
    "href=\"/michael/projects/hebcal/defaults.html\">What\n",
    "are the default Holidays?</a>)</small>",
    "<br><label\nfor=\"nx\">",
    $q->checkbox(-name => 'nx',
		 -id => 'nx',
		 -checked => 'checked',
		 -onClick => "s5()",
		 -label => "\nRosh Chodesh"),
    "</label>",
    "<br><label\nfor=\"o\">",
    $q->checkbox(-name => 'o',
		 -id => 'o',
		 -label => "\nDays of the Omer"),
    "</label>",
    "<br><label\nfor=\"s\">",
    $q->checkbox(-name => 's',
		 -id => 's',
		 -onClick => "s4()",
		 -label => "\nWeekly sedrot on Saturday"),
    "</label>\n(<label\nfor=\"i\">",
    $q->checkbox(-name => 'i',
		 -id => 'i',
		 -onClick => "s3()",
		 -label => "\nUse Israeli sedra scheme"),
    "</label>)";

    $q->param('c','off') unless defined $q->param('c');

    my $type = (defined $q->param('geo') && $q->param('geo') eq 'city') ?
	"closest city" :
	    (defined $q->param('geo') && $q->param('geo') eq 'pos') ?
		"latitude/longitude" : "zip code";

    print STDOUT "<br><label\nfor=\"c\">",
    $q->checkbox(-name => 'c',
		 -id => 'c',
		 -checked => 'checked',
		 -label => "\nCandle lighting times for $type:"),
    "</label>",
    "<br><small>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;(or select by\n";

    if (defined $q->param('geo') && $q->param('geo') eq 'city')
    {
	print STDOUT
	    $q->a({-href => $script_name . "?c=on&amp;geo=zip",
		   -onClick => "return s1('zip')",
	           },
		  "zip code"), " or\n",
	    $q->a({-href => $script_name . "?c=on&amp;geo=pos",
		   -onClick => "return s1('pos')",
	           },
		  "latitude/longitude");
    }
    elsif (defined $q->param('geo') && $q->param('geo') eq 'pos')
    {
	print STDOUT
	    $q->a({-href => $script_name . "?c=on&amp;geo=zip",
		   -onClick => "return s1('zip')",
	           },
		  "zip code"), " or\n",
	    $q->a({-href => $script_name . "?c=on&amp;geo=city",
		   -onClick => "return s1('city')",
	           },
		  "closest city");
    }
    else
    {
	print STDOUT
	    $q->a({-href => $script_name . "?c=on&amp;geo=city",
		   -onClick => "return s1('city')",
	           },
		  "closest city"), " or\n",
	    $q->a({-href => $script_name . "?c=on&amp;geo=pos",
		   -onClick => "return s1('pos')",
	           },
		  "latitude/longitude");
    }
    print STDOUT ")</small><br>";

    if (defined $q->param('geo') && $q->param('geo') eq 'city')
    {
	print STDOUT $q->hidden(-name => 'geo',
				-value => 'city',
				-id => 'geo'),
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"city\">",
	"Closest City:\n",
	$q->popup_menu(-name => 'city',
		       -id => 'city',
		       -values => [sort keys %city_tz],
		       -default => 'Jerusalem'),
	"</label><br>";
    }
    elsif (defined $q->param('geo') && $q->param('geo') eq 'pos')
    {
	print STDOUT $q->hidden(-name => 'geo',
				-value => 'pos',
				-id => 'geo'),
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"ladeg\">",
	$q->textfield(-name => 'ladeg',
		      -id => 'ladeg',
		      -size => 3,
		      -maxlength => 2),
	"&nbsp;deg</label>&nbsp;&nbsp;\n",
	"<label for=\"lamin\">",
	$q->textfield(-name => 'lamin',
		      -id => 'lamin',
		      -size => 2,
		      -maxlength => 2),
	"&nbsp;min</label>&nbsp;\n",
	$q->popup_menu(-name => 'ladir',
		       -id => 'ladir',
		       -values => ['n','s'],
		       -default => 'n',
		       -labels => {'n' => 'North Latitude',
				   's' => 'South Latitude'}),
	"<br>",
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"lodeg\">",
	$q->textfield(-name => 'lodeg',
		      -id => 'lodeg',
		      -size => 3,
		      -maxlength => 3),
	"&nbsp;deg</label>&nbsp;&nbsp;\n",
	"<label for=\"lomin\">",
	$q->textfield(-name => 'lomin',
		      -id => 'lomin',
		      -size => 2,
		      -maxlength => 2),
	"&nbsp;min</label>&nbsp;\n",
	$q->popup_menu(-name => 'lodir',
		       -id => 'lodir',
		       -values => ['w','e'],
		       -default => 'w',
		       -labels => {'e' => 'East Longitude',
				   'w' => 'West Longitude'}),
	"<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\n";
    }
    else
    {
	print STDOUT $q->hidden(-name => 'geo',
				-value => 'zip',
				-id => 'geo'),
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor=\"zip\">\n",
	"Zip code:\n",
	$q->textfield(-name => 'zip',
		      -id => 'zip',
		      -size => 5,
		      -maxlength => 5),
	"</label>&nbsp;&nbsp;&nbsp;\n";
    }

    if (!defined $q->param('geo') || $q->param('geo') ne 'city')
    {
	print STDOUT "<label for=\"tz\">Time zone:\n",
	$q->popup_menu(-name => 'tz',
		       -id => 'tz',
		       -values =>
		       (defined $q->param('geo') && $q->param('geo') eq 'pos')
		       ? [-5,-6,-7,-8,-9,-10,-11,-12,
			  12,11,10,9,8,7,6,5,4,3,2,1,0,
			  -1,-2,-3,-4]
		       : ['auto',-5,-6,-7,-8,-9,-10],
		       -default =>
		       (defined $q->param('geo') && $q->param('geo') eq 'pos')
		       ? 0 : 'auto',
		       -labels => \%tz_names),
	"</label><br>",
	"&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Daylight Saving Time:\n",
	$q->radio_group(-name => 'dst',
			-values =>
			(defined $q->param('geo') && $q->param('geo') eq 'pos')
			? ['usa','israel','none']
			: ['usa','none'],
			-default =>
			(defined $q->param('geo') && $q->param('geo') eq 'pos')
			? 'none' : 'usa',
			-labels =>
			{'usa' => "\nUSA (except AZ, HI, and IN) ",
			 'israel' => "\nIsrael ",
			 'none' => "\nnone ", }),
	"<br>";
    }

    print STDOUT "<label\nfor=\"m\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;",
    "Havdalah minutes past sundown:\n",
    $q->textfield(-name => 'm',
		  -id => 'm',
		  -size => 3,
		  -maxlength => 3,
		  -default => 72),
    "</label></p>\n";

    print STDOUT "<p><strong>Other options:</strong>",
    "<br><label\nfor=\"a\">",
    $q->checkbox(-name => 'a',
		 -id => 'a',
		 -label => "\nUse Ashkenazis Hebrew"),
    "</label>",
    "<br><label\nfor=\"D\">",
    $q->checkbox(-name => 'D',
		 -id => 'D',
		 -label => "\nPrint Hebrew date for dates with some event"),
    "</label>",
    "<br><label\nfor=\"d\">",
    $q->checkbox(-name => 'd',
		 -id => 'd',
		 -label => "\nPrint Hebrew date for entire date range"),
    "</label>",
    "<br><label\nfor=\"set\">",
    $q->checkbox(-name => 'set',
		 -id => 'set',
		 -checked => 'checked',
		 -label => "\nSave my preferences in a cookie"),
    "</label><small>(<a\n",
    "href=\"http://www.zdwebopedia.com/TERM/c/cookie.html\">What's\n",
    "a cookie?</a>)</small>",
    "</p>\n",
    $q->submit(-name => '.s',-value => 'Get Calendar'),
    $q->hidden(-name => '.cgifields',
	       -values => ['nx', 'nh', 'set'],
	       '-override'=>1),
    "</form>", $html_footer;

    exit(0);
    1;
}

sub results_page
{
    local($date);
    local($filename) = 'hebcal_' . $q->param('year');
    local($ycal) = (defined($q->param('y')) && $q->param('y') eq '1') ? 1 : 0;
    local($prev_url,$next_url,$prev_title,$next_title);

    if ($q->param('month') =~ /^\d+$/ &&
	$q->param('month') >= 1 && $q->param('month') <= 12)
    {
	$filename .= '_' . lc($MoY_short[$q->param('month')-1]);
	$date = $MoY_long{$q->param('month')} . ' ' . $q->param('year');
    }
    else
    {
	$date = $q->param('year');
    }

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	if (defined $q->param('zip'))
	{
	    $filename .= '_' . $q->param('zip');
	}
	elsif (defined $q->param('city'))
	{
	    $tmp = lc($q->param('city'));
	    $tmp =~ s/[^\w]/_/g;
	    $filename .= '_' . $tmp;
	}
    }

    # process cookie, delete before we generate next/prev URLS
    if ($q->param('set')) {
	$newcookie = &gen_cookie();
	if (! defined $q->raw_cookie())
	{
	    print STDOUT "Set-Cookie: ", $newcookie, "; expires=",
	    $expires_date, "; path=/\015\012";
	}
	else
	{
	    my($cmp1) = $newcookie;
	    my($cmp2) = $q->raw_cookie();

	    $cmp1 =~ s/\bC=t=\d+\&//;
	    $cmp2 =~ s/\bC=t=\d+\&//;

	    print STDOUT "Set-Cookie: ", $newcookie, "; expires=",
	    $expires_date, "; path=/\015\012"
		if $cmp1 ne $cmp2;
	}

	$q->delete('set');
    }

    # next and prev urls
    if ($q->param('month') =~ /^\d+$/ &&
	$q->param('month') >= 1 && $q->param('month') <= 12)
    {
	my($pm,$nm,$py,$ny);

	if ($q->param('month') == 1)
	{
	    $pm = 12;
	    $nm = 2;
	    $py = $q->param('year') - 1;
	    $ny = $q->param('year');
	}
	elsif ($q->param('month') == 12)
	{
	    $pm = 11;
	    $nm = 1;
	    $py = $q->param('year');
	    $ny = $q->param('year') + 1;
	}
	else
	{
	    $pm = $q->param('month') - 1;
	    $nm = $q->param('month') + 1;
	    $ny = $py = $q->param('year');
	}

	$prev_url = $script_name . "?year=" . $py . "&amp;month=" . $pm;
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    $prev_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$prev_title = $MoY_short[$pm-1] . " " . $py;

	$next_url = $script_name . "?year=" . $ny . "&amp;month=" . $nm;
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    $next_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$next_title = $MoY_short[$nm-1] . " " . $ny;
    }
    else
    {
	$prev_url = $script_name . "?year=" . ($q->param('year') - 1);
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    $prev_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year';
	}
	$prev_title = ($q->param('year') - 1);

	$next_url = $script_name . "?year=" . ($q->param('year') + 1);
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    $next_url .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year';
	}
	$next_title = ($q->param('year') + 1);
    }

    print STDOUT $q->header(-expires => $expires_date),
    $q->start_html(-title => "Hebcal: Jewish Calendar $date",
		   -target=>'_top',
		   -head => [
			   "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			   $q->Link({-rel => 'prev',
				     -href => $prev_url,
				     -title => $prev_title}),
			   $q->Link({-rel => 'next',
				     -href => $next_url,
				     -title => $next_title}),
			   $q->Link({-rel => 'start',
				     -href => $script_name,
				     -title => 'Hebcal Interactive Jewish Calendar'})
			   ],
		   -meta => {'robots' => 'noindex'});
    print STDOUT
	"<table border=\"0\" width=\"100%\" cellpadding=\"0\" ",
	"class=\"navbar\">\n",
	"<tr valign=\"top\"><td><small>\n",
	"<a href=\"/\">", $server_name, "</a>\n",
	"<tt>-&gt;</tt>\n",
	"<a href=\"", $script_name, "?v=0";

    foreach $key ($q->param())
    {
	$val = $q->param($key);
	print STDOUT "&amp;$key=", &url_escape($val)
	    unless $key eq 'v';
    }

    print STDOUT "\">hebcal</a>\n<tt>-&gt;</tt> $date</small>\n",
    "<td align=\"right\"><small><a\n",
    "href=\"/search/\">Search</a></small>\n",
    "</td></tr></table>\n",
    "<h1>Jewish Calendar $date</h1>\n";

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	print STDOUT "<dl>\n<dt>", $city_descr, "\n";
	print STDOUT "<dd><small>", $lat_descr, "</small>\n"
	    if $lat_descr ne '';
	print STDOUT "<dd><small>", $long_descr, "</small>\n"
	    if $long_descr ne '';
	print STDOUT "<dd><small>", $dst_tz_descr, "</small>\n"
	    if $dst_tz_descr ne '';
	print STDOUT "</dl>\n";

	if ($city_descr =~ / IN &nbsp;/)
	{
	    print STDOUT "<p><font color=\"#ff0000\">",
	    "Indiana has confusing time zone &amp;\n",
	    "Daylight Saving Time rules.</font>\n",
	    "You might want to read <a\n",
	    "href=\"http://www.mccsc.edu/time.html\">What time is it in\n",
	    "Indiana?</a> to make sure the above settings are\n",
	    "correct.</p>";
	}
    }

    print STDOUT
"<div><small>
<p>Your personal <a href=\"http://calendar.yahoo.com/\">Yahoo!
Calendar</a> is a free web-based calendar that can synchronize with Palm
Pilot, Outlook, etc.</p>
<ul>
<li>If you wish to upload <strong>all</strong> of the below holidays to
your Yahoo!  Calendar, do the following:
<ol>
<li>Click the \"Download as an Outlook CSV file\" link at the bottom of
this page.
<li>Save the hebcal CSV file on your computer.
<li>Go to <a
href=\"http://calendar.yahoo.com/?v=81\">Import/Export page</a> of
Yahoo! Calendar.
<li>Find the \"Import from Outlook\" section and choose \"Import Now\"
to import your CSV file to your online calendar.
</ol>
<li>To import selected holidays <strong>one at a time</strong>, use
the \"add\" links below.  These links will pop up a new browser window
so you can keep this window open.
</ul></small></div>
" if $ycal;

    my($goto) = "<p><b>" .
	"<a\nhref=\"$prev_url\">&lt;&lt;</a>\n" .
	$date . "\n" .
	"<a\nhref=\"$next_url\">&gt;&gt;</a></b>";

    if ($date !~ /^\d+$/)
    {
	$goto .= "\n&nbsp;&nbsp;&nbsp; <small>[ month view | " .
	    "<a\nhref=\"$script_name?year=" . $q->param('year') .
	    "&amp;month=x";
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    $goto .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$goto .= "\">year\nview</a> ]</small>";
    }
    else
    {
	$goto .= "\n&nbsp;&nbsp;&nbsp; <small>[ " .
	    "<a\nhref=\"$script_name?year=" . $q->param('year') .
	    "&amp;month=1";
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    $goto .= "&amp;$key=" . &url_escape($val)
		unless $key eq 'year' || $key eq 'month';
	}
	$goto .= "\">month\nview</a> | year view ]</small>";
    }

    $goto .= "</p>\n";

    print STDOUT $goto;

    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename
    print STDOUT "<!-- $cmd_pretty -->\n";

    local(@events) = &invoke_hebcal($cmd);
    print STDOUT "<pre>";

    foreach (@events)
    {
	($subj,$date,$start_time,$end_date,$end_time,$all_day,
	 $hour,$min,$mon,$mday,$year,$descr,$loc) = split(/\cA/);

	if ($ycal)
	{
	    $ST  = sprintf("%04d%02d%02d", $year, $mon, $mday);
	    if ($hour >= 0 && $min >= 0)
	    {
		$loc = (defined $city_descr && $city_descr ne '') ?
		    "in $city_descr" : '';
	        $loc =~ s/\s*&nbsp;\s*/ /g;

		$hour += 12 if $hour < 12 && $hour > 0;
		$ST .= sprintf("T%02d%02d00", $hour, $min);

		if ($q->param('tz') ne '')
		{
		    $abstz = ($q->param('tz') >= 0) ?
			$q->param('tz') : -$q->param('tz');
		    $signtz = ($q->param('tz') < 0) ? '-' : '';

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

	if ($descr =~ /^(Parshas\s+|Parashat\s+)(.+)/)
	{
	    $parashat = $1;
	    $sedra = $2;
	    if (defined $sedrot{$sedra} && $sedrot{$sedra} !~ /^\s*$/)
	    {
		$descr = '<a href="' . $sedrot{$sedra} .
		    '">' . $parashat . $sedra . '</a>';
	    }
	    elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
		   (defined $sedrot{$1} && $sedrot{$1} !~ /^\s*$/))
	    {
		$descr = '<a href="' . $sedrot{$1} .
		    '">' . $parashat . $sedra . '</a>';
	    }
	}

	$dow = ($year > 1969 && $year < 2038) ?
	    $DoW[&get_dow($year - 1900, $mon - 1, $mday)] . ' ' : '';
	printf STDOUT "%s%04d-%02d-%02d  %s\n",
	$dow, $year, $mon, $mday, $descr;
    }

    print STDOUT "</pre>", $goto;

    # download links
    print STDOUT "<p>Advanced options:\n",
    "<small>[ <a href=\"", $script_name,
    "index.html/$filename.csv?dl=1";
    foreach $key ($q->param())
    {
	$val = $q->param($key);
	print STDOUT "&amp;$key=", &url_escape($val);
    }
    print STDOUT "&amp;filename=$filename.csv";
    print STDOUT "\">Download&nbsp;Outlook&nbsp;CSV&nbsp;file</a>";

    # only offer DBA export when we know timegm() will work
    if ($q->param('year') > 1969 && $q->param('year') < 2038 &&
	(!defined($q->param('dst')) || $q->param('dst') ne 'israel'))
    {
	print STDOUT "\n- <a href=\"",
	$script_name, "index.html/$filename.dba?dl=1";
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    print STDOUT "&amp;$key=", &url_escape($val);
	}
	print STDOUT "&amp;filename=$filename.dba";
	print STDOUT "\">Download&nbsp;Palm&nbsp;Date&nbsp;Book&nbsp;Archive&nbsp;(.DBA)</a>";
    }

    if ($ycal == 0)
    {
	print STDOUT "\n- <a href=\"", $script_name, "?y=1";
	foreach $key ($q->param())
	{
	    $val = $q->param($key);
	    print STDOUT "&amp;$key=", &url_escape($val);
	}
	print STDOUT "\">Show&nbsp;Yahoo!&nbsp;Calendar&nbsp;links</a>";
    }
    print STDOUT "\n]</small></p>\n";

    print STDOUT  $html_footer;

    1;
}

sub get_dow
{
    local($year,$mon,$mday) = @_;
    local($time) = &Time::Local::timegm(0,0,9,$mday,$mon,$year,0,0,0); # 9am

    (localtime($time))[6];	# $wday
}

sub parse_date_descr
{
    local($date,$descr) = @_;

    local($mon,$mday,$year) = split(/\//, $date);
    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hour,$min) = ($1,$2,$3);
	$start_time = sprintf("\"%d:%02d PM\"", $hour, $min);

	if ($subj eq 'Candle lighting')
	{
	    $min += 18;
	}
	else
	{
	    $min += 15;
	}

	if ($min >= 60)
	{
	    $hour++;
	    $min -= 60;
	}
	$end_time = sprintf("\"%d:%02d PM\"", $hour, $min);
	$end_date = $date;
#	$end_time = $end_date = '';
	$all_day = '"false"';
    }
    else
    {
	$hour = $min = -1;
	$start_time = $end_time = $end_date = '';
	$all_day = '"true"';
	$subj = $descr;
    }

    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    ($subj,$date,$start_time,$end_date,$end_time,$all_day,
     $hour,$min,$mon,$mday,$year);
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
    local($sec,$min,$hour,$mday,$mon,$year,$wday) =
	gmtime($time);

    sprintf("%s, %02d %s %4d %02d:%02d:%02d GMT",
	    $DoW[$wday],$mday,$MoY_short[$mon],$year+1900,$hour,$min,$sec);
}

sub gen_cookie {
    local($retval);

    $retval = 'C=t=' . time;

    if ($q->param('c') && $q->param('c') ne 'off')
    {
	if ($q->param('geo') eq 'zip') {
	    $retval .= '&zip=' . $q->param('zip');
	    $retval .= '&dst=' . $q->param('dst')
	        if defined $q->param('dst') && $q->param('dst') ne '';
	    $retval .= '&tz=' . $q->param('tz')
	        if defined $q->param('tz') && $q->param('tz') ne '';
	} elsif ($q->param('geo') eq 'city') {
	    $retval .= '&city=' . &url_escape($q->param('city'));
	} elsif ($q->param('geo') eq 'pos') {
	    $retval .= '&lodeg=' . $q->param('lodeg');
	    $retval .= '&lomin=' . $q->param('lomin');
	    $retval .= '&lodir=' . $q->param('lodir');
	    $retval .= '&ladeg=' . $q->param('ladeg');
	    $retval .= '&lamin=' . $q->param('lamin');
	    $retval .= '&ladir=' . $q->param('ladir');
	    $retval .= '&dst=' . $q->param('dst')
	        if defined $q->param('dst') && $q->param('dst') ne '';
	    $retval .= '&tz=' . $q->param('tz')
	        if defined $q->param('tz') && $q->param('tz') ne '';
	}
	$retval .= '&m=' . $q->param('m')
	    if defined $q->param('m') && $q->param('m') ne '';
    }

    foreach (@opts)
    {
	next if $_ eq 'c';
	$retval .= "&$_=" . $q->param($_)
	    if defined $q->param($_) && $q->param($_) ne '';
    }
    $retval .= '&nh=off'
	if !defined $q->param('nh') || $q->param('nh') eq 'off';
    $retval .= '&nx=off'
	if !defined $q->param('nx') || $q->param('nx') eq 'off';

    $retval;
}


sub process_cookie {
    local($cookieval) = @_;

    my($c) = new CGI($cookieval);

    if ((! defined $q->param('c')) ||
	($q->param('c') eq 'on') ||
	($q->param('c') eq '1')) {
	if (defined $c->param('zip') && $c->param('zip') =~ /^\d{5}$/ &&
	    (! defined $q->param('geo') || $q->param('geo') eq 'zip')) {
	    $q->param('zip',$c->param('zip'))
		unless $q->param('zip');
	    $q->param('geo','zip');
	    $q->param('c','on');
	    $q->param('dst',$c->param('dst'))
		if (defined $c->param('dst') && ! defined $q->param('dst'));
	    $q->param('tz',$c->param('tz'))
		if (defined $c->param('tz') && ! defined $q->param('tz'));
	} elsif (defined $c->param('city') && $c->param('city') ne '' &&
		 (! defined $q->param('geo') || $q->param('geo') eq 'city')) {
	    $q->param('city',$c->param('city'))
		unless $q->param('city');
	    $q->param('geo','city');
	    $q->param('c','on');
	} elsif (defined $c->param('lodeg') &&
		 defined $c->param('lomin') &&
		 defined $c->param('lodir') &&
		 defined $c->param('ladeg') &&
		 defined $c->param('lamin') &&
		 defined $c->param('ladir') &&
		 (! defined $q->param('geo') || $q->param('geo') eq 'pos')) {
	    $q->param('lodeg',$c->param('lodeg'))
		unless $q->param('lodeg');
	    $q->param('lomin',$c->param('lomin'))
		unless $q->param('lomin');
	    $q->param('lodir',$c->param('lodir'))
		unless $q->param('lodir');
	    $q->param('ladeg',$c->param('ladeg'))
		unless $q->param('ladeg');
	    $q->param('lamin',$c->param('lamin'))
		unless $q->param('lamin');
	    $q->param('ladir',$c->param('ladir'))
		unless $q->param('ladir');
	    $q->param('geo','pos');
	    $q->param('c','on');
	    $q->param('dst',$c->param('dst'))
		if (defined $c->param('dst') && ! defined $q->param('dst'));
	    $q->param('tz',$c->param('tz'))
		if (defined $c->param('tz') && ! defined $q->param('tz'));
	}
    }

    $q->param('m',$c->param('m'))
	if (defined $c->param('m') && ! defined $q->param('m'));

    foreach (@opts)
    {
	next if $_ eq 'c';
	$q->param($_,$c->param($_))
	    if (! defined $q->param($_) && defined $c->param($_));
    }

    $q->param('nh','off')
	if (defined $c->param('h') && $c->param('h') eq 'on');
    $q->param('nx','off')
	if (defined $c->param('x') && $c->param('x') eq 'on');

    $q->param('nh',$c->param('nh'))
	if (! defined $q->param('nh') && defined $c->param('nh'));
    $q->param('nx',$c->param('nx'))
	if (! defined $q->param('nx') && defined $c->param('nx'));

    1;
}

########################################################################
# export to Palm Date Book Archive (.DBA)
########################################################################

sub writeInt {
    print STDOUT pack("V", $_[0]);
}

sub writeByte {
    print STDOUT pack("C", $_[0]);
}

sub writePString {
    local($len) = length($_[0]);

    if ($len > 64) { $len = 64; }
    &writeByte($len);
    print STDOUT substr($_[0], 0, $len);
}

sub dba_header {
    local($filename) = @_;

    &writeInt($PALM_DBA_MAGIC);
    &writePString($filename);
    &writeByte(0);
    &writeInt(8);
    &writeInt(0);

    # magic OLE graph table
    &writeInt(0x36);
    &writeInt(0x0F);
    &writeInt(0x00);
    &writeInt(0x01);
    &writeInt(0x02);
    &writeInt(0x1000F);
    &writeInt(0x10001);
    &writeInt(0x10003);
    &writeInt(0x10005);
    &writeInt(0x60005);
    &writeInt(0x10006);
    &writeInt(0x10006);
    &writeInt(0x80001);

    1;
}

sub dba_contents {
    local(@events) = @_;
    local($numEntries) = scalar(@events);
    local($memo,$untimed,$startTime,$i,$z,$secsEast,$local2local);

    # compute diff seconds between GMT and whatever our local TZ is
    # pick 1999/01/15 as a date that we're certain is standard time
    $startTime = &Time::Local::timegm(0,34,12,15,0,90,0,0,0);
    $secsEast = $startTime - &Time::Local::timelocal(0,34,12,15,0,90,0,0,0);
    if ($q->param('tz') =~ /^-?\d+$/)
    {
	# add secsEast to go from our localtime to GMT
	# then sub destination tz secsEast to get into local time
	$local2local = $secsEast - ($q->param('tz') * 60 * 60);
    }
    else
    {
	# the best we can do with unknown TZ is assume GMT
	$local2local = $secsEast;
    }

    $numEntries = $PALM_DBA_MAXENTRIES if ($numEntries > $PALM_DBA_MAXENTRIES);
    &writeInt($numEntries*15);

    for ($i = 0; $i < $numEntries; $i++) {
	local($subj,$z,$z,$z,$z,$all_day,
	      $hour,$min,$mon,$mday,$year) = split(/\cA/, $events[$i]);

        next if $year <= 1969 || $year >= 2038;

	if ($hour == -1 && $min == -1) {
#	    $hour = $min = 0;
	    $hour = 12;		# try all-day/untimed events as 12 noon
	    $min = 0;
	} elsif ($hour > 0 || $min > 0) {
	    $hour += 12;	# candle-lighting times are always PM
	}

	if (!defined($q->param('dst')) || $q->param('dst') eq 'none' ||
	    ((defined $q->param('geo') && $q->param('geo') eq 'city' &&
	      defined $q->param('city') && $q->param('city') ne '' &&
	      defined $city_nodst{$q->param('city')})))
	{
	    # no DST, so just use gmtime and then add that city offset
	    $startTime = &Time::Local::timegm(0,$min,$hour,$mday,$mon-1,
					      $year-1900,0,0,0);
	    $startTime -= ($q->param('tz') * 60 * 60); # move into local tz
	}
	else
	{
	    $startTime = &Time::Local::timelocal(0,$min,$hour,$mday,$mon-1,
						 $year-1900,0,0,0);
	    $startTime += $local2local; # move into their local tz
	}

	$untimed = ($all_day eq '"true"') ? 1 : 0;

	&writeInt($PALM_DBA_INTEGER);
	&writeInt(0);		# recordID

	&writeInt($PALM_DBA_INTEGER);
	&writeInt(1);		# status

	&writeInt($PALM_DBA_INTEGER);
	&writeInt(0x7FFFFFFF);	# position

	&writeInt($PALM_DBA_DATE);
	&writeInt($startTime);

	&writeInt($PALM_DBA_INTEGER);
	if ($untimed) {
	    &writeInt($startTime); # endTime
	} elsif ($subj eq 'Candle lighting') {
	    &writeInt($startTime+(60*18)); # endTime
	} else {
	    &writeInt($startTime+(60*15)); # endTime
	}

	&writeInt(5);		# spacer
	&writeInt(0);		# spacer

	if ($subj eq '') {
	    &writeByte(0);
	} else {
	    &writePString($subj);
	}

	&writeInt($PALM_DBA_INTEGER);
	&writeInt(0);		# duration

	&writeInt(5);		# spacer
	&writeInt(0);		# spacer

	$memo = '';
	if ($memo eq '') {
	    &writeByte(0);
	} else {
	    &writePString($memo);
	}

	&writeInt($PALM_DBA_BOOL);
	&writeInt($untimed);

	&writeInt($PALM_DBA_BOOL);
	&writeInt(0);		# isPrivate

	&writeInt($PALM_DBA_INTEGER);
	&writeInt(1);		# category

	&writeInt($PALM_DBA_BOOL);
	&writeInt(0);		# alarm

	&writeInt($PALM_DBA_INTEGER);
	&writeInt(0xFFFFFFFF);	# alarmAdv

	&writeInt($PALM_DBA_INTEGER);
	&writeInt(0);		# alarmTyp

	&writeInt($PALM_DBA_REPEAT);
	&writeInt(0);		# repeat
    }

    1;
}
