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

package Hebcal;
require 5.000;
require Exporter;
use Time::Local;
use CGI;

@ISA = qw(Exporter);
@EXPORT = qw(csv_write_contents dba_write_contents dba_write_header
	     invoke_hebcal get_dow get_holiday_anchor
	     url_escape http_date gen_cookie process_cookie);

########################################################################
# constants
########################################################################

my($VERSION) = '$Revision$'; #'

# boolean options
@opts = ('c','o','s','i','a','d','D');

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

$HOLIDAY_IDX_ANCHOR = 0;	# index of html anchor
$HOLIDAY_IDX_YOMTOV = 1;	# is holiday yom tov

%holidays = (
    "Asara B'Tevet"		=> ["tevet",		0],
    "Channukah"			=> ["chanukah",		0],
    "Channukah: 8th Day"	=> ["chanukah",		0],
    "Chanukah: 8th Day"		=> ["chanukah",		0],
    "Chanukah"			=> ["chanukah",		0],
    "Erev Pesach"		=> ["pesach",		0],
    "Erev Rosh Hashana"		=> ["rosh",		0],
    "Erev Shavuos"		=> ["shavuot",		0],
    "Erev Shavuot"		=> ["shavuot",		0],
    "Erev Sukkos"		=> ["sukkot",		0],
    "Erev Sukkot"		=> ["sukkot",		0],
    "Erev Yom Kippur"		=> ["yomkippur",	0],
    "Lag B'Omer"		=> ["lagbaomer",	0],
    "Pesach"			=> ["pesach",		1],
    "Purim Katan"		=> ["katan",		0],
    "Purim Koson"		=> ["katan",		0],
    "Purim"			=> ["purim",		0],
    "Rosh Hashana"		=> ["rosh",		1],
    "Shabbas HaChodesh"		=> ["hachodesh",	1],
    "Shabbas HaGadol"		=> ["hagadol",		1],
    "Shabbas Hazon"		=> ["hazon",		1],
    "Shabbas Nachamu"		=> ["nachamu",		1],
    "Shabbas Parah"		=> ["parah",		1],
    "Shabbas Shekalim"		=> ["shekalim",		1],
    "Shabbas Shuvah"		=> ["shuva",		1],
    "Shabbas Zachor"		=> ["zachor",		1],
    "Shabbat HaChodesh"		=> ["hachodesh",	1],
    "Shabbat HaGadol"		=> ["hagadol",		1],
    "Shabbat Hazon"		=> ["hazon",		1],
    "Shabbat Nachamu"		=> ["nachamu",		1],
    "Shabbat Parah"		=> ["parah",		1],
    "Shabbat Shekalim"		=> ["shekalim",		1],
    "Shabbat Shuva"		=> ["shuva",		1],
    "Shabbat Zachor"		=> ["zachor",		1],
    "Shavuos"			=> ["shavuot",		1],
    "Shavuot"			=> ["shavuot",		1],
    "Shmini Atzeres"		=> ["shmini",		1],
    "Shmini Atzeret"		=> ["shmini",		1],
    "Shushan Purim"		=> ["shushan",		0],
    "Simchas Torah"		=> ["simchatorah",	1],
    "Simchat Torah"		=> ["simchatorah",	1],
    "Sukkos"			=> ["sukkot",		1],
    "Sukkos VII (Hoshana Raba)"	=> ["sukkot",		1],
    "Sukkot"			=> ["sukkot",		1],
    "Sukkot VII (Hoshana Raba)"	=> ["sukkot",		1],
    "Ta'anis Bechoros"		=> ["bechorot",		0],
    "Ta'anis Esther"		=> ["esther",		0],
    "Ta'anit Bechorot"		=> ["bechorot",		0],
    "Ta'anit Esther"		=> ["esther",		0],
    "Tish'a B'Av"		=> ["9av",		0],
    "Tu B'Shvat"		=> ["tubshvat",		0],
    "Tzom Gedaliah"		=> ["gedaliah",		0],
    "Tzom Tammuz"		=> ["tammuz",		0],
    "Yom HaAtzma'ut"		=> ["haatzmaut",	0],
    "Yom HaShoah"		=> ["hashoah",		0],
    "Yom HaZikaron"		=> ["hazikaron",	0],
    "Yom Kippur"		=> ["yomkippur",	1],
    "Yom Yerushalayim"		=> ["yerushalayim",	0],
		    );

# this doesn't work for weeks that have double parashiot
# todo: automatically get URL from hebrew year
%sedrot = (
 "Bereshit"	=> 'http://learn.jtsa.edu/topics/parashah/5761/bereshit.shtml',
 "Bereshis"	=> 'http://learn.jtsa.edu/topics/parashah/5761/bereshit.shtml',
 "Noach"	=> 'http://learn.jtsa.edu/topics/parashah/5761/noah.shtml',
 "Lech-Lecha"	=> 'http://learn.jtsa.edu/topics/parashah/5761/lekhlekha.shtml',
 "Vayera"	=> 'http://learn.jtsa.edu/topics/parashah/5761/vayera.shtml',
 "Chayei Sara"	=> 'http://learn.jtsa.edu/topics/parashah/5761/hayyeisarah.shtml',
 "Toldot"	=> 'http://learn.jtsa.edu/topics/parashah/5761/toledot.shtml',
 "Toldos"	=> 'http://learn.jtsa.edu/topics/parashah/5761/toeldot.shtml',
 "Vayetzei"	=> 'http://learn.jtsa.edu/topics/parashah/5761/vayetze.shtml',
 "Vayishlach"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vayishlah.shtml',
 "Vayeshev"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vayeshev.shtml',
 "Miketz"	=> 'http://learn.jtsa.edu/topics/parashah/5760/miketz.shtml',
 "Vayigash"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vayigash.shtml',
 "Vayechi"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vayehi.shtml',
 "Shemot"	=> 'http://learn.jtsa.edu/topics/parashah/5760/shmot.shtml',
 "Shemos"	=> 'http://learn.jtsa.edu/topics/parashah/5760/shmot.shtml',
 "Vaera"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vaayra.shtml',
 "Bo"		=> 'http://learn.jtsa.edu/topics/parashah/5760/bo.shtml',
 "Beshalach"	=> 'http://learn.jtsa.edu/topics/parashah/5760/beshalah.shtml',
 "Yitro"	=> 'http://learn.jtsa.edu/topics/parashah/5760/yitro.shtml',
 "Yisro"	=> 'http://learn.jtsa.edu/topics/parashah/5760/yitro.shtml',
 "Mishpatim"	=> 'http://learn.jtsa.edu/topics/parashah/5760/mishpatim.shtml',
 "Terumah"	=> 'http://learn.jtsa.edu/topics/parashah/5760/terumah.shtml',
 "Tetzaveh"	=> 'http://learn.jtsa.edu/topics/parashah/5760/tetsavveh.shtml',
 "Ki Tisa"	=> 'http://learn.jtsa.edu/topics/parashah/5760/kitissa.shtml',
 "Ki Sisa"	=> 'http://learn.jtsa.edu/topics/parashah/5760/kitissa.shtml',
 "Vayakhel"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vayakhel.shtml',
 "Pekudei"	=> 'http://learn.jtsa.edu/topics/parashah/5760/pekuday.shtml',
 "Vayikra"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vayikra.shtml',
 "Tzav"		=> 'http://learn.jtsa.edu/topics/parashah/5760/tsav.shtml',
 "Shmini"	=> 'http://learn.jtsa.edu/topics/parashah/5760/shemini.shtml',
 "Tazria"	=> 'http://learn.jtsa.edu/topics/parashah/5760/tazria.shtml',
 "Sazria"	=> 'http://learn.jtsa.edu/topics/parashah/5760/tazria.shtml',
 "Metzora"	=> 'http://learn.jtsa.edu/topics/parashah/5759/tazriametzora.shtml',
 "Achrei Mot"	=> 'http://learn.jtsa.edu/topics/parashah/5759/ahareymotkedoshim.shtml',
 "Achrei Mos"	=> 'http://learn.jtsa.edu/topics/parashah/5759/ahareymotkedoshim.shtml',
 "Kedoshim"	=> 'http://learn.jtsa.edu/topics/parashah/5760/kedoshim.shtml',
 "Emor"		=> 'http://learn.jtsa.edu/topics/parashah/5760/emor.shtml',
 "Behar"	=> 'http://learn.jtsa.edu/topics/parashah/5760/behar.shtml',
 "Bechukotai"	=> 'http://learn.jtsa.edu/topics/parashah/5760/behukkotai.shtml',
 "Bechukosai"	=> 'http://learn.jtsa.edu/topics/parashah/5760/behukkotai.shtml',
 "Bamidbar"	=> 'http://learn.jtsa.edu/topics/parashah/5760/bemidbar.shtml',
 "Nasso"	=> 'http://learn.jtsa.edu/topics/parashah/5760/naso.shtml',
 "Beha'alotcha" => 'http://learn.jtsa.edu/topics/parashah/5760/behaalothekha.shtml',
 "Beha'aloscha" => 'http://learn.jtsa.edu/topics/parashah/5760/behaalothekha.shtml',
 "Sh'lach"	=> 'http://learn.jtsa.edu/topics/parashah/5760/shelahlekha.shtml',
 "Korach"	=> 'http://learn.jtsa.edu/topics/parashah/5760/korah.shtml',
 "Chukat"	=> 'http://learn.jtsa.edu/topics/parashah/5760/hukkatbalak.shtml',
 "Chukas"	=> 'http://learn.jtsa.edu/topics/parashah/5760/hukkatbalak.shtml',
 "Balak"	=> 'http://learn.jtsa.edu/topics/parashah/5760/hukkatbalak.shtml',
 "Pinchas"	=> 'http://learn.jtsa.edu/topics/parashah/5760/pinhas.shtml',
 "Matot"	=> 'http://learn.jtsa.edu/topics/parashah/5760/mattotmaseei.shtml',
 "Matos"	=> 'http://learn.jtsa.edu/topics/parashah/5760/mattotmaseei.shtml',
 "Masei"	=> 'http://learn.jtsa.edu/topics/parashah/5760/mattotmaseei.shtml',
 "Devarim"	=> 'http://learn.jtsa.edu/topics/parashah/5760/devarim.shtml',
 "Vaetchanan"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vaethannan.shtml',
 "Vaeschanan"	=> 'http://learn.jtsa.edu/topics/parashah/5760/vaethannan.shtml',
 "Eikev"	=> 'http://learn.jtsa.edu/topics/parashah/5760/ekev.shtml',
 "Re'eh"	=> 'http://learn.jtsa.edu/topics/parashah/5760/reeh.shtml',
 "Shoftim"	=> 'http://learn.jtsa.edu/topics/parashah/5760/shofetim.shtml',
 "Ki Teitzei"	=> 'http://learn.jtsa.edu/topics/parashah/5760/kitetse.shtml',
 "Ki Seitzei"	=> 'http://learn.jtsa.edu/topics/parashah/5760/kitetse.shtml',
 "Ki Tavo"	=> 'http://learn.jtsa.edu/topics/parashah/5760/kitavo.shtml',
 "Ki Savo"	=> 'http://learn.jtsa.edu/topics/parashah/5760/kitavo.shtml',
 "Nitzavim"	=> 'http://learn.jtsa.edu/topics/parashah/5760/nitsavimvayelekh.shtml',
 "Vayeilech"	=> 'http://learn.jtsa.edu/topics/parashah/5760/nitsavimvayelekh.shtml',
 "Ha'Azinu"	=> 'http://www.ohr.org.il/tw/5759/devarim/haazinu.htm',

 "Rosh Hashana"	=> 'http://learn.jtsa.edu/topics/parashah/5761/roshhashanah.shtml',
 "Yom Kippur"	=> 'http://learn.jtsa.edu/topics/parashah/5759/yk.shtml',
 "Sukkot"	=> 'http://learn.jtsa.edu/topics/parashah/5761/sukkot.shtml',
 "Sukkos"	=> 'http://learn.jtsa.edu/topics/parashah/5761/sukkot.shtml',
 "Simchat Torah" => 'http://learn.jtsa.edu/topics/parashah/5761/simhattorah.shtml',
 "Simchas Torah" => 'http://learn.jtsa.edu/topics/parashah/5761/simhattorah.shtml',
 "Pesach"	=> 'http://learn.jtsa.edu/topics/parashah/5760/pesah.shtml',
 "Shavuot"	=> 'http://learn.jtsa.edu/topics/parashah/5760/shavuot.shtml',
 "Shavuos"	=> 'http://learn.jtsa.edu/topics/parashah/5760/shavuot.shtml',
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

# @events is an array of arrays.  these are the indices into each
# event structure:

$EVT_IDX_SUBJ = 0;		# title of event
$EVT_IDX_UNTIMED = 1;		# 0 if all-day, non-zero if timed
$EVT_IDX_MIN = 2;		# minutes, [0 .. 59]
$EVT_IDX_HOUR = 3;		# hour of day, [0 .. 23]
$EVT_IDX_MDAY = 4;		# day of month, [0 .. 31]
$EVT_IDX_MON = 5;		# month of year, [0 .. 1]
$EVT_IDX_YEAR = 6;		# year [1970 .. 2037]
$EVT_IDX_DUR = 7;		# duration in minutes
$EVT_IDX_MEMO = 8;		# memo text
$EVT_IDX_YOMTOV = 9;		# is the holiday Yom Tov?

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
	    $dur = 15;
	}

	$untimed = 0;
    }
    else
    {
	$hour = $min = -1;
	$dur = 0;
	$untimed = 1;
	$subj = $descr;
	$subj =~ s/Channukah/Chanukah/; # fix spelling error
    }

    my($yomtov) = 0;
    if ($subj !~ / \(CH''M\)$/)
    {
	my($subj_copy) = $subj;
    
	$subj_copy =~ s/ I+$//;
	$subj_copy =~ s/ VI*$//;
	$subj_copy =~ s/ IV$//;
	$subj_copy =~ s/ \d{4}$//;
	$subj_copy =~ s/: \d Candles?$//;

	$yomtov = 1  if (defined $holidays{$subj_copy} &&
			 $holidays{$subj_copy}->[$HOLIDAY_IDX_YOMTOV]);
    }

    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    my($mon,$mday,$year) = split(/\//, $date);

    ($subj,$untimed,$min,$hour,$mday,$mon - 1,$year,$dur,$yomtov);
}

sub invoke_hebcal($$)
{
    my($cmd,$memo) = @_;
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

	push(@events,
	     [$subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,
	      ($untimed ? '' : $memo),$yomtov]);
    }
    close(HEBCAL);

    @events;
}

sub get_dow($$$)
{
    my($year,$mon,$mday) = @_;
    my($time) = &Time::Local::timegm(0,0,9,$mday,$mon,$year,0,0,0); # 9am

    (localtime($time))[6];	# $wday
}

sub get_holiday_anchor($)
{
    my($subj) = @_;

    if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)/)
    {
	my($parashat) = $1;
	my($sedra) = $2;
	if (defined $sedrot{$sedra} && $sedrot{$sedra} !~ /^\s*$/)
	{
	    return $sedrot{$sedra};
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
	       (defined $sedrot{$1} && $sedrot{$1} !~ /^\s*$/))
	{
	    return $sedrot{$1};
	}
    }
    else
    {
	$subj =~ s/ \(CH''M\)$//;
	$subj =~ s/ I+$//;
	$subj =~ s/ VI*$//;
	$subj =~ s/ IV$//;
	$subj =~ s/ \d{4}$//;
	$subj =~ s/: \d Candles?$//;

	if (defined $holidays{$subj})
	{
	    return "/michael/projects/hebcal/defaults.html#" .
		$holidays{$subj}->[$HOLIDAY_IDX_ANCHOR];
	}
	else
	{
	    return "";
	}
    }
}
    


########################################################################
# web page utils
########################################################################

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
	my($subj) = $events->[$i]->[$EVT_IDX_SUBJ];
	my($memo) = $events->[$i]->[$EVT_IDX_MEMO];

	my($date) = sprintf("\"%d/%d/%04d\"",
			    $events->[$i]->[$EVT_IDX_MON] + 1,
			    $events->[$i]->[$EVT_IDX_MDAY],
			    $events->[$i]->[$EVT_IDX_YEAR]);

	my($start_time) = '';
	my($end_time) = '';
	my($end_date) = '';
	my($all_day) = '"true"';

	if ($events->[$i]->[$EVT_IDX_UNTIMED] == 0)
	{
	    my($hour) = $events->[$i]->[$EVT_IDX_HOUR];
	    my($min) = $events->[$i]->[$EVT_IDX_MIN];

	    $hour -= 12 if $hour > 12;
	    $start_time = sprintf("\"%d:%02d PM\"", $hour, $min);

	    $hour += 12 if $hour < 12;
	    $min += $events->[$i]->[$EVT_IDX_DUR];

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

	if ($events->[$i]->[$EVT_IDX_UNTIMED] == 0 ||
	    $events->[$i]->[$EVT_IDX_YOMTOV] == 1)
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

    if ($len > 64) { $len = 64; }
    &dba_write_byte($len);
    print STDOUT substr($_[0], 0, $len);
}

sub dba_write_header($)
{
    my($filename) = @_;

    &dba_write_int($PALM_DBA_MAGIC);
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
    # pick 1999/01/15 as a date that we're certain is standard time
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

    $numEntries = $PALM_DBA_MAXENTRIES if ($numEntries > $PALM_DBA_MAXENTRIES);
    &dba_write_int($numEntries*15);

    for ($i = 0; $i < $numEntries; $i++)
    {
	# skip events that can't be expressed in a 31-bit time_t
        next if $events->[$i]->[$EVT_IDX_YEAR] <= 1969 ||
	    $events->[$i]->[$EVT_IDX_YEAR] >= 2038;

	if ($events->[$i]->[$EVT_IDX_UNTIMED] != 0)
	{
	    $events->[$i]->[$EVT_IDX_HOUR] = 12; # all-day/untimed: 12 noon
	    $events->[$i]->[$EVT_IDX_MIN] = 0;
	}

	if ($dst == 0)
	{
	    # no DST, so just use gmtime and then add that city offset
	    $startTime =
		&Time::Local::timegm(0,
				     $events->[$i]->[$EVT_IDX_MIN],
				     $events->[$i]->[$EVT_IDX_HOUR],
				     $events->[$i]->[$EVT_IDX_MDAY],
				     $events->[$i]->[$EVT_IDX_MON],
				     $events->[$i]->[$EVT_IDX_YEAR] - 1900,
				     0,0,0);
	    $startTime -= ($tz * 60 * 60); # move into local tz
	}
	else
	{
	    $startTime =
		&Time::Local::timelocal(0,
					$events->[$i]->[$EVT_IDX_MIN],
					$events->[$i]->[$EVT_IDX_HOUR],
					$events->[$i]->[$EVT_IDX_MDAY],
					$events->[$i]->[$EVT_IDX_MON],
					$events->[$i]->[$EVT_IDX_YEAR] - 1900,
					0,0,0);
	    $startTime += $local2local; # move into their local tz
	}

	&dba_write_int($PALM_DBA_INTEGER);
	&dba_write_int(0);		# recordID

	&dba_write_int($PALM_DBA_INTEGER);
	&dba_write_int(1);		# status

	&dba_write_int($PALM_DBA_INTEGER);
	&dba_write_int(0x7FFFFFFF);	# position

	&dba_write_int($PALM_DBA_DATE);
	&dba_write_int($startTime);

	&dba_write_int($PALM_DBA_INTEGER);

	# endTime
	if ($events->[$i]->[$EVT_IDX_UNTIMED] != 0)
	{
	    &dba_write_int($startTime);
	}
	else
	{
	    &dba_write_int($startTime + ($events->[$i]->[$EVT_IDX_DUR] * 60));
	}

	&dba_write_int(5);		# spacer
	&dba_write_int(0);		# spacer

	if (defined $events->[$i]->[$EVT_IDX_SUBJ] &&
	    $events->[$i]->[$EVT_IDX_SUBJ] ne '')
	{
	    &dba_write_pstring($events->[$i]->[$EVT_IDX_SUBJ]);
	}
	else
	{
	    &dba_write_byte(0);
	}

	&dba_write_int($PALM_DBA_INTEGER);
	&dba_write_int(0);		# duration

	&dba_write_int(5);		# spacer
	&dba_write_int(0);		# spacer

	if (defined $events->[$i]->[$EVT_IDX_MEMO] &&
	    $events->[$i]->[$EVT_IDX_MEMO] ne '')
	{
	    &dba_write_pstring($events->[$i]->[$EVT_IDX_MEMO]);
	}
	else
	{
	    &dba_write_byte(0);
	}

	&dba_write_int($PALM_DBA_BOOL);
	&dba_write_int($events->[$i]->[$EVT_IDX_UNTIMED] ? 1 : 0);

	&dba_write_int($PALM_DBA_BOOL);
	&dba_write_int(0);		# isPrivate

	&dba_write_int($PALM_DBA_INTEGER);
	&dba_write_int(1);		# category

	&dba_write_int($PALM_DBA_BOOL);
	&dba_write_int(0);		# alarm

	&dba_write_int($PALM_DBA_INTEGER);
	&dba_write_int(0xFFFFFFFF);	# alarmAdv

	&dba_write_int($PALM_DBA_INTEGER);
	&dba_write_int(0);		# alarmTyp

	&dba_write_int($PALM_DBA_REPEAT);
	&dba_write_int(0);		# repeat
    }

    1;
}

1;
