########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting times
# are calculated from your latitude and longitude (which can be
# determined by your zip code or closest city).
#
# Copyright (c) 2001  Michael John Radwin.  All rights reserved.
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

package Hebcal;
require 5.000;
use Time::Local;
use CGI;
use lib "/home/users/mradwin/local/lib/perl5/$]";
use lib "/home/users/mradwin/local/lib/perl5/site_perl/$]";
use Unicode::String;
use Config::IniFiles;
use Date::Calc;
use strict;

########################################################################
# constants
########################################################################

my($VERSION) = '$Revision$'; #'

# boolean options
@Hebcal::opts = ('c','o','s','i','a','d','D');

$Hebcal::PALM_DBA_MAGIC      = 1145176320;
$Hebcal::PALM_DBA_INTEGER    = 1;
$Hebcal::PALM_DBA_DATE       = 3;
$Hebcal::PALM_DBA_BOOL       = 6;
$Hebcal::PALM_DBA_REPEAT     = 7;
$Hebcal::PALM_DBA_MAXENTRIES = 2500;

@Hebcal::DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
@Hebcal::MoY_short =
    ('Jan','Feb','Mar','Apr','May','Jun',
     'Jul','Aug','Sep','Oct','Nov','Dec');
%Hebcal::MoY_long = (
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
%Hebcal::known_timezones =
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
%Hebcal::city_nodst =
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

%Hebcal::city_tz =
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


my($ini_path) = '/home/web/hebcal.com/docs/hebcal';
my($holidays) = new Config::IniFiles(-file => "$ini_path/holidays.ini");
my($sedrot)   = new Config::IniFiles(-file => "$ini_path/sedrot.ini");

# translate from Askenazic transiliterations to Separdic
my(%ashk2seph) =
 (
  # parshiot translations
  "Bereshis"			=>	"Bereshit",
  "Toldos"			=>	"Toldot",
  "Shemos"			=>	"Shemot",
  "Yisro"			=>	"Yitro",
  "Ki Sisa"			=>	"Ki Tisa",
  "Sazria"			=>	"Tazria",
  "Achrei Mos"			=>	"Achrei Mot",
  "Bechukosai"			=>	"Bechukotai",
  "Beha'aloscha"		=>	"Beha'alotcha",
  "Chukas"			=>	"Chukat",
  "Matos"			=>	"Matot",
  "Vaeschanan"			=>	"Vaetchanan",
  "Ki Seitzei"			=>	"Ki Teitzei",
  "Ki Savo"			=>	"Ki Tavo",

  # fixed holiday translations
  "Erev Sukkos"			=>	"Erev Sukkot",
  "Sukkos I"			=>	"Sukkot I",
  "Sukkos II"			=>	"Sukkot II",
  "Sukkos III (CH''M)"		=>	"Sukkot III (CH''M)",
  "Sukkos IV (CH''M)"		=>	"Sukkot IV (CH''M)",
  "Sukkos V (CH''M)"		=>	"Sukkot V (CH''M)",
  "Sukkos VI (CH''M)"		=>	"Sukkot VI (CH''M)",
  "Sukkos VII (Hoshana Raba)"	=>	"Sukkot VII (Hoshana Raba)",
  "Shmini Atzeres"		=>	"Shmini Atzeret",
  "Simchas Torah"		=>	"Simchat Torah",
  "Erev Shavuos"		=>	"Erev Shavuot",
  "Shavuos I"			=>	"Shavuot I",
  "Shavuos II"			=>	"Shavuot II",

  # variable holidays
  "Ta'anis Esther"		=>	"Ta'anit Esther",
  "Purim Koson"			=>	"Purim Katan",
  "Ta'anis Bechoros"		=>	"Ta'anit Bechorot",

  # special shabbatot
  "Shabbas Shuvah"		=>	"Shabbat Shuva",
  "Shabbas Shekalim"		=>	"Shabbat Shekalim",
  "Shabbas Zachor"		=>	"Shabbat Zachor",
  "Shabbas Parah"		=>	"Shabbat Parah",
  "Shabbas HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbas HaGadol"		=>	"Shabbat HaGadol",
  "Shabbas Hazon"		=>	"Shabbat Hazon",
  "Shabbas Nachamu"		=>	"Shabbat Nachamu",
  );

%Hebcal::tz_names = (
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

# @events is an array of arrays.  these are the indices into each
# event structure:

$Hebcal::EVT_IDX_SUBJ = 0;		# title of event
$Hebcal::EVT_IDX_UNTIMED = 1;		# 0 if all-day, non-zero if timed
$Hebcal::EVT_IDX_MIN = 2;		# minutes, [0 .. 59]
$Hebcal::EVT_IDX_HOUR = 3;		# hour of day, [0 .. 23]
$Hebcal::EVT_IDX_MDAY = 4;		# day of month, [1 .. 31]
$Hebcal::EVT_IDX_MON = 5;		# month of year, [0 .. 11]
$Hebcal::EVT_IDX_YEAR = 6;		# year [1 .. 9999]
$Hebcal::EVT_IDX_DUR = 7;		# duration in minutes
$Hebcal::EVT_IDX_MEMO = 8;		# memo text
$Hebcal::EVT_IDX_YOMTOV = 9;		# is the holiday Yom Tov?

########################################################################
# invoke hebcal unix app and create perl array of output
########################################################################

sub parse_date_descr($$)
{
    my($date,$descr) = @_;
    my($dur,$untimed);
    my($subj,$hour,$min);

    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hour,$min) = ($1,$2,$3);
	$hour += 12;		# timed events are always evening

	if ($subj eq 'Candle lighting')
	{
	    $dur = 18;
	}
	else
	{
	    $dur = 1;
	}

	$untimed = 0;
    }
    else
    {
	$hour = $min = -1;
	$dur = 0;
	$untimed = 1;
	$subj = $descr;
	$subj =~ s/Channukah/Chanukah/; # make spelling consistent
    }

    my($yomtov) = 0;
    my($subj_copy) = $subj;

    $subj_copy = $ashk2seph{$subj_copy}
	if defined $ashk2seph{$subj_copy};
    $subj_copy =~ s/ \d{4}$//; # fix Rosh Hashana

    $yomtov = 1  if $holidays->val($subj_copy, 'yomtov');

    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    my($mon,$mday,$year) = split(/\//, $date);

    ($subj,$untimed,$min,$hour,$mday,$mon - 1,$year,$dur,$yomtov);
}

sub invoke_hebcal($$$)
{
    my($cmd,$memo,$want_sephardic) = @_;
    my(@events,$prev);
    local($_);
    local(*HEBCAL);

    @events = ();
    open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";

    $prev = '';
    while (<HEBCAL>)
    {
	next if $_ eq $prev;
	$prev = $_;
	chop;

	my($date,$descr) = split(/ /, $_, 2);
	my($subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,$yomtov) =
	    &parse_date_descr($date,$descr);

	my($href,$hebrew,$memo2) = &get_holiday_anchor($subj,$want_sephardic);

	push(@events,
	     [$subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,
	      ($untimed ? $memo2 : $memo),$yomtov]);
    }
    close(HEBCAL);

    @events;
}

sub get_dow($$$)
{
    my($year,$mon,$mday) = @_;

    my($dow) = &Date::Calc::Day_of_Week($year,$mon,$mday);
    $dow == 7 ? 0 : $dow;
}

sub get_holiday_anchor($$$)
{
    my($subj,$want_sephardic,$q) = @_;
    my($href) = '';
    my($hebrew) = '';
    my($memo) = '';
    my($haftarah_href) = '';
    my($torah_href) = '';

    if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)$/)
    {
	my($parashat) = $1;
	my($sedra) = $2;

	# 'פרשת ' == UTF-8 for "parashat "
	$hebrew = "\xD7\xA4\xD7\xA8\xD7\xA9\xD7\xAA ";
	$sedra = $ashk2seph{$sedra} if (defined $ashk2seph{$sedra});

	if (defined $sedrot->Parameters($sedra))
	{
	    $href = $sedrot->val($sedra, 'drash');
	    $torah_href = $sedrot->val($sedra, 'torah');
	    if ($torah_href =~ m,^/jpstext/,)
	    {
		$haftarah_href = $torah_href;
		$haftarah_href =~ s/.shtml$/_haft.shtml/;
	    }

	    $hebrew .= $sedrot->val($sedra, 'hebrew');
	    $memo = "Torah: " . $sedrot->val($sedra, 'verse') .
		" / Haftarah: ";
	    
	    if ($want_sephardic &&
		defined $sedrot->val($sedra, 'haft_seph'))
	    {
		$memo .= $sedrot->val($sedra, 'haft_seph');
	    }
	    else
	    {
		$memo .= $sedrot->val($sedra, 'haft_ashk');
	    }
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
	       (defined $sedrot->Parameters($1) ||
		defined $sedrot->Parameters($ashk2seph{$1})))
	{
	    my($p1,$p2) = ($1,$2);

	    $p1 = $ashk2seph{$p1} if (defined $ashk2seph{$p1});
	    $p2 = $ashk2seph{$p2} if (defined $ashk2seph{$p2});

	    $href = $sedrot->val($p1, 'drash');
	    $torah_href = $sedrot->val($p1, 'torah');
	    if ($torah_href =~ m,^/jpstext/,)
	    {
		$haftarah_href = $torah_href;
		$haftarah_href =~ s/.shtml$/_haft.shtml/;
	    }

	    $hebrew .= $sedrot->val($p1, 'hebrew');

	    die "sedrot.ini missing $p2!"
		unless (defined $sedrot->Parameters($p2));

	    # hypenate hebrew reading
	    # '־' == UTF-8 for HEBREW PUNCTUATION MAQAF (U+05BE)
	    $hebrew .= "\xD6\xBE" . $sedrot->val($p2, 'hebrew');

	    # second part of torah reading
	    my($torah_end) = $sedrot->val($p2, 'verse');
	    $torah_end =~ s/^.+\s+(\d+:\d+)\s*$/$1/;

	    $memo = "Torah: " . $sedrot->val($p1, 'verse');
	    $memo =~ s/\s+\d+:\d+\s*$/ $torah_end/;

	    # on doubled parshiot, read only the second Haftarah
	    $haftarah_href = $sedrot->val($p2, 'torah');
	    $haftarah_href =~ s/.shtml$/_haft.shtml/;

	    $memo .= " / Haftarah: ";
	    if ($want_sephardic &&
		defined $sedrot->val($p2, 'haft_seph'))
	    {
		$memo .= $sedrot->val($p2, 'haft_seph');
	    }
	    else
	    {
		$memo .= $sedrot->val($p2, 'haft_ashk');
	    }
	}

	$href = 'http://learn.jtsa.edu/topics/parashah' . $href
	    if ($href =~ m,^/,);
	$torah_href = 'http://learn.jtsa.edu/topics/parashah' . $torah_href
	    if ($torah_href =~ m,^/,);
	$haftarah_href = 'http://learn.jtsa.edu/topics/parashah' . $haftarah_href
	    if ($haftarah_href =~ m,^/,);
    }
    else
    {
	my($subj_copy) = $subj;

	$subj_copy = $ashk2seph{$subj_copy}
	    if defined $ashk2seph{$subj_copy};

	$subj_copy =~ s/ \d{4}$//; # fix Rosh Hashana

	if (defined $holidays->Parameters($subj_copy))
	{
	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/help/defaults.html#" .
		$holidays->val($subj_copy, 'anchor');

	    if (defined $holidays->val($subj_copy, 'hebrew'))
	    {
		$hebrew = $holidays->val($subj_copy, 'hebrew');
	    }
	}
    }

    return (wantarray()) ? ($href,$hebrew,$memo,$torah_href,$haftarah_href)
	: $href;
}
    


########################################################################
# web page utils
########################################################################


sub guess_timezone($$$)
{
    my($tz,$zip,$state) = @_;

    return $tz if ($tz =~ /^-?\d+$/);

    if (defined $Hebcal::known_timezones{$zip})
    {
	return $Hebcal::known_timezones{$zip}
	if ($Hebcal::known_timezones{$zip} ne '??');
    }
    elsif (defined $Hebcal::known_timezones{substr($zip,0,3)})
    {
	return $Hebcal::known_timezones{substr($zip,0,3)}
	if ($Hebcal::known_timezones{substr($zip,0,3)} ne '??');
    }
    elsif (defined $Hebcal::known_timezones{$state})
    {
	return $Hebcal::known_timezones{$state}
	if ($Hebcal::known_timezones{$state} ne '??');
    }

    undef;
}

sub display_hebrew {
    my($q,$class,@args) = @_;

    if ($q->user_agent('MSIE'))
    {
	my(@args2);
	foreach (@args)
	{
	    s/  /&nbsp;&nbsp;/g;
	    push(@args2, $_);
	}

	return join('',
		    qq{<span dir="rtl" lang="he"\nclass="$class">},
		    @args2,
		    qq{</span>}
		    );
    }
    else
    {
	my($str) = &utf8_hebrew_to_netscape(join('', @args));
	$str =~ s/  /&nbsp;&nbsp;/g;

	return join('',
		    qq{<span dir="ltr" lang="he"\nclass="${class}-ltr">},
		    $str,
		    qq{</span>}
		    );
    }
}

sub utf8_hebrew_to_netscape($) {
    my($str) = @_;

    my($u) = Unicode::String::utf8($str);
    my(@array) = $u->unpack();
    my(@result) = ();

    for (my $i = scalar(@array) - 1; $i >= 0; --$i)
    {
	# skip hebrew punctuation range
	next if $array[$i] > 0x0590 && $array[$i] < 0x05D0;

	if ($array[$i] == 0x0028)
	{
	    push(@result, 0x0029); # reverse parens
	}
	elsif ($array[$i] == 0x0029)
	{
	    push(@result, 0x0028); # reverse parens
	}
	else
	{
	    push(@result, $array[$i]);
	}
    }

#    $u->pack(0x202D, @result);	# LEFT-TO-RIGHT OVERRIDE
    $u->pack(@result);
    return $u->utf8();
}

sub html_footer($$)
{
    my($q,$rcsrev) = @_;

    my($mtime) = (defined $ENV{'SCRIPT_FILENAME'}) ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    $rcsrev =~ s/\s*\$//g;

    my($server_name) = $q->virtual_host();
    $server_name =~ s/^www\.//;

    my($this_year) = (localtime)[5];
    $this_year += 1900;

    my($hhmts) = "Software last updated:\n" . localtime($mtime);

    return qq{
<hr noshade size="1"><font size=-2 face=Arial><a
name="copyright">Copyright &copy; $this_year
Michael J. Radwin. All rights reserved.</a>
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a>
<br>This website uses <a href="http://www.sadinoff.com/hebcal/">hebcal
3.2 for UNIX</a>, Copyright &copy; 1994 <a
href="http://www.sadinoff.com/">Danny Sadinoff</a>.  All rights reserved.
<br>$hhmts ($rcsrev)
</font></body></html>
};
}

sub navbar2($$$$$)
{
    my($q,$title,$help,$parent_title,$parent_href) = @_;

    my($server_name) = $q->virtual_host();
    $server_name =~ s/^www\.//;

    my($help_html) = ($help) ? "href=\"/help/\">Help</a> -\n<a\n" : '';

    my($parent_html) = ($parent_title && $parent_href) ? 
	qq{<tt>-&gt;</tt>\n<a\nhref="$parent_href">$parent_title</a>\n} :
	'';

    return "<table width=\"100%\"\nclass=\"navbar\">" .
	"<tr><td><small>" .
	"<strong><a\nhref=\"/\">" . $server_name . "</a></strong>\n" .
	$parent_html .
	"<tt>-&gt;</tt>\n" .
	$title . "</small></td>" .
	"<td align=\"right\"><small><a\n" .
	$help_html .
	"href=\"/search/\">Search</a></small>\n" .
	"</td></tr></table>";
}

sub start_html($$$$)
{
    my($q,$title,$head,$meta) = @_;

    $q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		    "\t\"http://www.w3.org/TR/html4/loose.dtd");

    my($server_name) = $q->virtual_host();
    $meta = {} unless defined $meta;
    $head = [] unless defined $head;

    my($author) = $server_name;
    $author =~ s/^www\.//;
    $author = "webmaster\@$author";

    return $q->start_html
	(
	 -dir => 'ltr',
	 -lang => 'en',
	 -title => $title,
	 -target => '_top',
	 -head => [
		   qq{<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://$server_name" r (n 0 s 0 v 0 l 0))'>},
		   $q->Link({-rel => 'stylesheet',
			     -href => '/style.css',
			     -type => 'text/css'}),
		   $q->Link({-rel => 'p3pv1',
			     -href => "http://$server_name/w3c/p3p.xml"}),
		   $q->Link({-rev => 'made',
			     -href => "mailto:$author"}),
		   @{$head},
		   ],
	 -meta => $meta,
	 );
}

sub url_escape($)
{
    local($_) = @_;
    my($res) = '';

    foreach (split(//))
    {
	if (/ /)
	{
	    $res .= '+';
	}
	elsif (/[^a-zA-Z0-9_.*-]/)
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

sub http_date($)
{
    my($time) = @_;
    my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime($time);

    sprintf("%s, %02d %s %4d %02d:%02d:%02d GMT",
	    $Hebcal::DoW[$wday],$mday,$Hebcal::MoY_short[$mon],
	    $year+1900,$hour,$min,$sec);
}

sub gen_cookie($)
{
    my($q) = @_;
    my($retval);

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

    foreach (@Hebcal::opts)
    {
	next if $_ eq 'c';
	$retval .= "&$_=" . $q->param($_)
	    if defined $q->param($_) && $q->param($_) ne '';
    }
    $retval .= '&nh=off'
	if !defined $q->param('nh') || $q->param('nh') eq 'off';
    $retval .= '&nx=off'
	if !defined $q->param('nx') || $q->param('nx') eq 'off';

    if (defined $q->param('heb') && $q->param('heb') ne '')
    {
	$retval .= "&heb=" . $q->param('heb');
    }
    else
    {
	$retval .= '&heb=off';
    }

    $retval;
}


sub process_cookie($$)
{
    my($q,$cookieval) = @_;

    my($c) = new CGI($cookieval);

    if ((! defined $q->param('c')) ||
	($q->param('c') eq 'on') ||
	($q->param('c') eq '1')) {
	if (defined $c->param('zip') && $c->param('zip') =~ /^\d{5}$/ &&
	    (! defined $q->param('geo') || $q->param('geo') eq 'zip')) {
	    $q->param('geo','zip');
	    $q->param('c','on');
	    if (! defined $q->param('zip') || $q->param('zip') =~ /^\s*$/)
	    {
		$q->param('zip',$c->param('zip'));
		$q->param('dst',$c->param('dst'))
		    if defined $c->param('dst');
		$q->param('tz',$c->param('tz'))
		    if defined $c->param('tz');
	    }
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

    foreach (@Hebcal::opts)
    {
	next if $_ eq 'c';
	$q->param($_,$c->param($_))
	    if (! defined $q->param($_) && defined $c->param($_));
    }

#    $q->param('nh','off')
#	if (defined $c->param('h') && $c->param('h') eq 'on');
#    $q->param('nx','off')
#	if (defined $c->param('x') && $c->param('x') eq 'on');

    $q->param('nh',$c->param('nh'))
	if (! defined $q->param('nh') && defined $c->param('nh'));
    $q->param('nx',$c->param('nx'))
	if (! defined $q->param('nx') && defined $c->param('nx'));
    $q->param('heb',$c->param('heb'))
	if (! defined $q->param('heb') && defined $c->param('heb'));

    $c;
}


########################################################################
# export to Outlook CSV
########################################################################

sub csv_write_contents($$)
{
    my($events,$endl) = @_;
    my($numEntries) = scalar(@{$events});

    print STDOUT
	qq{"Subject","Start Date","Start Time","End Date",},
	qq{"End Time","All day event","Description","Show time as"$endl};

    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($memo) = $events->[$i]->[$Hebcal::EVT_IDX_MEMO];

	my($date) = sprintf("\"%d/%d/%04d\"",
			    $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1,
			    $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			    $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);

	my($start_time) = '';
	my($end_time) = '';
	my($end_date) = '';
	my($all_day) = '"true"';

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];

	    $hour -= 12 if $hour > 12;
	    $start_time = sprintf("\"%d:%02d PM\"", $hour, $min);

	    $hour += 12 if $hour < 12;
	    $min += $events->[$i]->[$Hebcal::EVT_IDX_DUR];

	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $hour -= 12 if $hour > 12;
	    $end_time = sprintf("\"%d:%02d PM\"", $hour, $min);
	    $end_date = $date;
	    $all_day = '"false"';
	}

	$subj =~ s/,//g;
	$memo =~ s/,//g;

	$subj =~ s/\"/''/g;
	$memo =~ s/\"/''/g;

	print STDOUT
	    qq{"$subj",$date,$start_time,$end_date,$end_time,},
	    qq{$all_day,"$memo",};

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0 ||
	    $events->[$i]->[$Hebcal::EVT_IDX_YOMTOV] == 1)
	{
	    print STDOUT qq{"4"};
	}
	else
	{
	    print STDOUT qq{"3"};
	}

	print STDOUT $endl;
    }

    1;
}


########################################################################
# export to Palm Date Book Archive (.DBA)
########################################################################

sub dba_write_int($)
{
    print STDOUT pack("V", $_[0]);
}

sub dba_write_byte($)
{
    print STDOUT pack("C", $_[0]);
}

sub dba_write_pstring($)
{
    my($len) = length($_[0]);

    $len = 254 if $len > 254;
    &dba_write_byte($len);
    print STDOUT substr($_[0], 0, $len);
}

sub dba_write_header($)
{
    my($filename) = @_;

    &dba_write_int($Hebcal::PALM_DBA_MAGIC);
    &dba_write_pstring($filename);
    &dba_write_byte(0);
    &dba_write_int(8);
    &dba_write_int(0);

    # magic OLE graph table
    &dba_write_int(0x36);
    &dba_write_int(0x0F);
    &dba_write_int(0x00);
    &dba_write_int(0x01);
    &dba_write_int(0x02);
    &dba_write_int(0x1000F);
    &dba_write_int(0x10001);
    &dba_write_int(0x10003);
    &dba_write_int(0x10005);
    &dba_write_int(0x60005);
    &dba_write_int(0x10006);
    &dba_write_int(0x10006);
    &dba_write_int(0x80001);

    1;
}

sub dba_write_contents($$$)
{
    my($events,$tz,$dst) = @_;
    my($numEntries) = scalar(@{$events});
    my($startTime,$i,$secsEast,$local2local);

    # compute diff seconds between GMT and whatever our local TZ is
    # pick 1990/01/15 as a date that we're certain is standard time
    $startTime = &Time::Local::timegm(0,34,12,15,0,90,0,0,0);
    $secsEast = $startTime - &Time::Local::timelocal(0,34,12,15,0,90,0,0,0);

    $tz = 0 unless (defined $tz && $tz =~ /^-?\d+$/);

    if ($tz == 0)
    {
	# assume GMT
	$local2local = $secsEast;
    }
    else
    {
	# add secsEast to go from our localtime to GMT
	# then sub destination tz secsEast to get into local time
	$local2local = $secsEast - ($tz * 60 * 60);
    }

#    warn "DBG: tz=$tz,dst=$dst,local2local=$local2local,secsEast=$secsEast\n";

    $numEntries = $Hebcal::PALM_DBA_MAXENTRIES
	if ($numEntries > $Hebcal::PALM_DBA_MAXENTRIES);
    &dba_write_int($numEntries*15);

    for ($i = 0; $i < $numEntries; $i++)
    {
	# skip events that can't be expressed in a 31-bit time_t
        next if $events->[$i]->[$Hebcal::EVT_IDX_YEAR] <= 1969 ||
	    $events->[$i]->[$Hebcal::EVT_IDX_YEAR] >= 2038;

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] != 0)
	{
	    # all-day/untimed: 12 noon
	    $events->[$i]->[$Hebcal::EVT_IDX_HOUR] = 12;
	    $events->[$i]->[$Hebcal::EVT_IDX_MIN] = 0;
	}

	if (!$dst)
	{
	    # no DST, so just use gmtime and then add that city offset
	    $startTime =
		&Time::Local::timegm(0,
				     $events->[$i]->[$Hebcal::EVT_IDX_MIN],
				     $events->[$i]->[$Hebcal::EVT_IDX_HOUR],
				     $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
				     $events->[$i]->[$Hebcal::EVT_IDX_MON],
				     $events->[$i]->[$Hebcal::EVT_IDX_YEAR]
				     - 1900);
	    $startTime -= ($tz * 60 * 60); # move into local tz
	}
	else
	{
	    $startTime =
		&Time::Local::timelocal(0,
					$events->[$i]->[$Hebcal::EVT_IDX_MIN],
					$events->[$i]->[$Hebcal::EVT_IDX_HOUR],
					$events->[$i]->[$Hebcal::EVT_IDX_MDAY],
					$events->[$i]->[$Hebcal::EVT_IDX_MON],
					$events->[$i]->[$Hebcal::EVT_IDX_YEAR]
					- 1900);
	    $startTime += $local2local; # move into their local tz
	}

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);
	&dba_write_int(0);		# recordID

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);
	&dba_write_int(1);		# status

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);
	&dba_write_int(0x7FFFFFFF);	# position

	&dba_write_int($Hebcal::PALM_DBA_DATE);
	&dba_write_int($startTime);

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);

	# endTime
	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] != 0)
	{
	    &dba_write_int($startTime);
	}
	else
	{
	    &dba_write_int($startTime +
			   ($events->[$i]->[$Hebcal::EVT_IDX_DUR] * 60));
	}

	&dba_write_int(5);		# spacer
	&dba_write_int(0);		# spacer

	if (defined $events->[$i]->[$Hebcal::EVT_IDX_SUBJ] &&
	    $events->[$i]->[$Hebcal::EVT_IDX_SUBJ] ne '')
	{
	    &dba_write_pstring($events->[$i]->[$Hebcal::EVT_IDX_SUBJ]);
	}
	else
	{
	    &dba_write_byte(0);
	}

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);
	&dba_write_int(0);		# duration

	&dba_write_int(5);		# spacer
	&dba_write_int(0);		# spacer

	if (defined $events->[$i]->[$Hebcal::EVT_IDX_MEMO] &&
	    $events->[$i]->[$Hebcal::EVT_IDX_MEMO] ne '')
	{
	    &dba_write_pstring($events->[$i]->[$Hebcal::EVT_IDX_MEMO]);
	}
	else
	{
	    &dba_write_byte(0);
	}

	&dba_write_int($Hebcal::PALM_DBA_BOOL);
	&dba_write_int($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] ? 1 : 0);

	&dba_write_int($Hebcal::PALM_DBA_BOOL);
	&dba_write_int(0);		# isPrivate

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);
	&dba_write_int(1);		# category

	&dba_write_int($Hebcal::PALM_DBA_BOOL);
	&dba_write_int(0);		# alarm

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);
	&dba_write_int(0xFFFFFFFF);	# alarmAdv

	&dba_write_int($Hebcal::PALM_DBA_INTEGER);
	&dba_write_int(0);		# alarmTyp

	&dba_write_int($Hebcal::PALM_DBA_REPEAT);
	&dba_write_int(0);		# repeat
    }

    1;
}

# avoid warnings
if ($^W && 0)
{
    $_ = $Hebcal::city_nodst{'foo'};
    $_ = $Hebcal::tz_names{'foo'};
    $_ = $Hebcal::city_tz{'foo'};
    $_ = $Hebcal::MoY_long{'foo'};
    $_ = $Hebcal::known_timezones{'foo'};
}

1;
