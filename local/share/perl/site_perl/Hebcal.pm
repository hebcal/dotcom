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

my($HOLIDAY_IDX_ANCHOR) = 0;	# index of html anchor
my($HOLIDAY_IDX_YOMTOV) = 1;	# is holiday yom tov
my($HOLIDAY_IDX_TITLE_HE) = 2;	# title of holiday in hebrew

my(%holidays) = 
    (
     "Asara B'Tevet"		=>
     ["tevet",			0, 'עֲשָׂרָה בְּטֵבֵת'],

     "Chanukah: 1 Candle"	=>
     ["chanukah",		0, 'חֲנוּכָּה: א׳ נֵר'],
     "Chanukah: 2 Candles"	=>
     ["chanukah",		0, 'חֲנוּכָּה: ב׳ נֵרוֹת'],
     "Chanukah: 3 Candles"	=>
     ["chanukah",		0, 'חֲנוּכָּה: ג׳ נֵרוֹת'],
     "Chanukah: 4 Candles"	=>
     ["chanukah",		0, 'חֲנוּכָּה: ד׳ נֵרוֹת'],
     "Chanukah: 5 Candles"	=>
     ["chanukah",		0, 'חֲנוּכָּה: ה׳ נֵרוֹת'],
     "Chanukah: 6 Candles"	=>
     ["chanukah",		0, 'חֲנוּכָּה: ו׳ נֵרוֹת'],
     "Chanukah: 7 Candles"	=>
     ["chanukah",		0, 'חֲנוּכָּה: ז׳ נֵרוֹת'],
     "Chanukah: 8 Candles"	=>
     ["chanukah",		0, 'חֲנוּכָּה: ח׳ נֵרוֹת'],
     "Chanukah: 8th Day"	=>
     ["chanukah",		0, 'חֲנוּכָּה: יוֹם ח׳'],

     "Lag B'Omer"		=>
     ["lagbaomer",		0, 'לג׳ בְּעוֹמֶר'],

     "Erev Pesach"		=>
     ["pesach",			0, 'עֶרֶב פֶּסַח'],
     "Pesach I"			=>
     ["pesach",			1, 'פֶּסַח א׳'],
     "Pesach II"		=>
     ["pesach",			1, 'פֶּסַח ב׳'],
     "Pesach III (CH''M)"	=>
     ["pesach",			0, 'פֶּסַח ג׳ חֹל הַמוֹעד'],
     "Pesach IV (CH''M)"	=>
     ["pesach",			0, 'פֶּסַח ד׳ חֹל הַמוֹעד'],
     "Pesach V (CH''M)"	=>
     ["pesach",			0, 'פֶּסַח ה׳ חֹל הַמוֹעד'],
     "Pesach VI (CH''M)"	=>
     ["pesach",			0, 'פֶּסַח ו׳ חֹל הַמוֹעד'],
     "Pesach VII"		=>
     ["pesach",			1, 'פֶּסַח ז׳'],
     "Pesach VIII"		=>
     ["pesach",			1, 'פֶּסַח ח׳'],

     "Purim Katan"		=>
     ["katan",			0, 'פֶּסַח קָטָן'],
     "Purim"			=>
     ["purim",			0, 'פּוּרִים'],

     "Erev Rosh Hashana"	=>
     ["rosh",			0, 'עֶרֶב רֹאשׁ הַשָּׁנָה'],
     "Rosh Hashana"		=>
     ["rosh",			1, 'רֹאשׁ הַשָּׁנָה'],
     "Rosh Hashana II"		=>
     ["rosh",			1, 'רֹאשׁ הַשָּׁנָה ב׳'],

     "Shabbat HaChodesh"	=>
     ["hachodesh",		1, 'שַׁבָּת הַחֹדֶשׁ'],
     "Shabbat HaGadol"		=>
     ["hagadol",		1, 'שַׁבָּת הַגָּדוֹל'],
     "Shabbat Hazon"		=>
     ["hazon",			1, 'שַׁבָּת הַזוֹן'],
     "Shabbat Nachamu"		=>
     ["nachamu",		1, 'שַׁבָּת נַחֲמוּ'],
     "Shabbat Parah"		=>
     ["parah",			1, 'שַׁבָּת פּרה'],
     "Shabbat Shekalim"		=>
     ["shekalim",		1, 'שַׁבָּת שְׁקָלִים'],
     "Shabbat Shuva"		=>
     ["shuva",			1, 'שַׁבָּת שׁוּבָה'],
     "Shabbat Zachor"		=>
     ["zachor",			1, 'שַׁבָּת זָכוֹר'],

     "Erev Shavuot"		=>
     ["shavuot",		0, 'עֶרֶב שָׁבוּעוֹת'],
     "Shavuot I"		=>
     ["shavuot",		1, 'שָׁבוּעוֹת א׳'],
     "Shavuot II"		=>
     ["shavuot",		1, 'שָׁבוּעוֹת ב׳'],

     "Shmini Atzeret"		=>
     ["shmini",			1, 'שְׁמִינִי עֲצֶרֶת'],
     "Shushan Purim"		=>
     ["shushan",		0, 'שׁוּשָׁן פּוּרִים'],
     "Simchat Torah"		=>
     ["simchatorah",		1, 'שִׂמְחַת תּוֹרָה'],

     "Erev Sukkot"		=>
     ["sukkot",			0, 'עֶרֶב סוּכּוֹת'],
     "Sukkot I"			=>
     ["sukkot",			1, 'סוּכּוֹת א׳'],
     "Sukkot II"		=>
     ["sukkot",			1, 'סוּכּוֹת ב׳'],
     "Sukkot III (CH''M)"	=>
     ["sukkot",			0, 'סוּכּוֹת ג׳ חֹל הַמוֹעד'],
     "Sukkot IV (CH''M)"	=>
     ["sukkot",			0, 'סוּכּוֹת ד׳ חֹל הַמוֹעד'],
     "Sukkot V (CH''M)"	=>
     ["sukkot",			0, 'סוּכּוֹת ה׳ חֹל הַמוֹעד'],
     "Sukkot VI (CH''M)"	=>
     ["sukkot",			0, 'סוּכּוֹת ו׳ חֹל הַמוֹעד'],
     "Sukkot VII (Hoshana Raba)"	=>
     ["sukkot",			1, 'סוּכּוֹת ז׳ (הוֹשַׁנָא רַבָּה)'],
     "Ta'anit Bechorot"		=>
     ["bechorot",		0, 'תַּעֲנִית בְּכוֹרוֹת'],
     "Ta'anit Esther"		=>
     ["esther",			0, 'תַּעֲנִית אֶסְתֵּר'],
     "Tish'a B'Av"		=>
     ["9av",			0, 'תִּשְׁעָה בְּאָב'],
     "Tu B'Shvat"		=>
     ["tubshvat",		0, 'טוּ בִּשְׁבָט'],
     "Tzom Gedaliah"		=>
     ["gedaliah",		0, 'צוֹם ***'],
     "Tzom Tammuz"		=>
     ["tammuz",			0, 'צוֹם תָּמוּז'],
     "Yom HaAtzma'ut"		=>
     ["haatzmaut",		0, 'יוֹם הָעַצְמָאוּת'],
     "Yom HaShoah"		=>
     ["hashoah",		0, 'יוֹם הַשּׁוֹאָה'],
     "Yom HaZikaron"		=>
     ["hazikaron",		0, 'יוֹם הַזִּכָּרוֹן'],

     "Erev Yom Kippur"		=>
     ["yomkippur",		0, 'עֶרֶב יוֹם כִּפּוּר'],
     "Yom Kippur"		=>
     ["yomkippur",		1, 'יוֹם כִּפּוּר'],
     "Yom Yerushalayim"		=>
     ["yerushalayim",		0, 'יוֹם יְרוּשָׁלַיִם'],

     'Rosh Chodesh Iyyar'	=>
     ['rc_iyyar', 0, 'רֹאשׁ חֹדֶשׁ אִיָיר'],
     'Rosh Chodesh Sivan'	=>
     ['rc_sivan', 0, 'רֹאשׁ חֹדֶשׁ סִיוָן'],
     'Rosh Chodesh Tamuz'	=>
     ['rc_tamuz	', 0, 'רֹאשׁ חֹדֶשׁ תָּמוּז'],
     'Rosh Chodesh Av'	=>
     ['rc_av', 0, 'רֹאשׁ חֹדֶשׁ אָב'],
     'Rosh Chodesh Elul'	=>
     ['rc_elul', 0, 'רֹאשׁ חֹדֶשׁ אֱלוּל'],
     'Rosh Chodesh Tishrei'	=>
     ['rc_tishrei', 0, 'רֹאשׁ חֹדֶשׁ תִּשְׁרֵי'],
     'Rosh Chodesh Cheshvan'	=>
     ['rc_cheshvan', 0, 'רֹאשׁ חֹדֶשׁ חֶשְׁוָן'],
     'Rosh Chodesh Kislev'	=>
     ['rc_kislev', 0, 'רֹאשׁ חֹדֶשׁ כִּסְלֵו'],
     'Rosh Chodesh Tevet'	=>
     ['rc_tevet', 0, 'רֹאשׁ חֹדֶשׁ טֵבֵת'],
     "Rosh Chodesh Sh'vat"=>
     ['rc_shvat', 0, 'רֹאשׁ חֹדֶשׁ שְׁבָת'],
     'Rosh Chodesh Adar'	=>
     ['rc_adar', 0, 'רֹאשׁ חֹדֶשׁ אַדָר'],
     'Rosh Chodesh Adar I'	=>
     ['rc_adar', 0, 'רֹאשׁ חֹדֶשׁ אַדָר א׳'],
     'Rosh Chodesh Adar II'	=>
     ['rc_adar', 0, 'רֹאשׁ חֹדֶשׁ אַדָר ב׳'],
     'Rosh Chodesh Nisan'	=>
     ['rc_nisan', 0, 'רֹאשׁ חֹדֶשׁ נִיסָן'],

		    );

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


# todo: automatically get URL from hebrew year
my($SEDROT_IDX_DRASH_EN) = 0;
my($SEDROT_IDX_VERSE_EN) = 1;
my($SEDROT_IDX_TORAH_EN) = 2;
my($SEDROT_IDX_TITLE_HE) = 3;
my($SEDROT_IDX_HAFT_ASHK) = 4;	# Askhenazic Haftarah
my($SEDROT_IDX_HAFT_SEPH) = 5;	# Sephardic Haftarah

my(%sedrot) = (
 "Bereshit"	=> [
		    '/5761/bereshit.shtml', 'Genesis 1:1 - 6:8',
		    '/jpstext/bereshit.shtml',
		    'בְּרֵאשִׁית',
		    'Isaiah 42:5 - 43:11', 'Isaiah 42:5 - 42:21',
		    ],
 "Noach"	=> [
		    '/5761/noah.shtml', 'Genesis 6:9 - 11:32',
		    '/jpstext/noah.shtml',
		    'נֹחַ',
		    'Isaiah 54:1 - 55:5', 'Isaiah 54:1 - 10',
		    ],
 "Lech-Lecha"	=> [
		    '/5761/lekhlekha.shtml', 'Genesis 12:1 - 17:27',
		    '/jpstext/lekhlekha.shtml',
		    'לֶךְ־לְךָ',
		    'Isaiah 40:27 - 41:16', '',
		    ],
 "Vayera"	=> [
		    '/5761/vayera.shtml', 'Genesis 18:1 - 22:24',
		    '/jpstext/vayera.shtml',
		    'וַיֵּרָא',
		    'II Kings 4:1 - 4:37', 'II Kings 4:1 - 4:23',
		    ],
 "Chayei Sara"	=> [
		    '/5761/hayyeisarah.shtml', 'Genesis 23:1 - 25:18',
		    '/jpstext/hayyeisarah.shtml',
		    'חַיֵּי שָֹרָה',
		    'I Kings 1:1 - 1:31', '',
		    ],
 "Toldot"	=> [
		    '/5761/toledot.shtml', 'Genesis 25:19 - 28:9',
		    '/jpstext/toledot.shtml',
		    'תּוֹלְדוֹת',
		    'Malachi 1:1 - 2:7', '',
		    ],
 "Vayetzei"	=> [
		    '/5761/vayetze.shtml', 'Genesis 28:10 - 32:3',
		    '/jpstext/vayetze.shtml',
		    'וַיֵּצֵא',
		    'Hosea 12:13 - 14:10', 'Hosea 11:7 - 12:12',
		    ],
 "Vayishlach"	=> [
		    '/5761/vayishlah.shtml', 'Genesis 32:4 - 36:43',
		    '/jpstext/vayishlah.shtml',
		    'וַיִּשְׁלַח',
		    'Hosea 11:7 - 12:12', 'Obadiah 1:1 - 1:21',
		    ],
 "Vayeshev"	=> [
		    '/5761/vayeshev.shtml', 'Genesis 37:1 - 40:23',
		    '/jpstext/vayeshev.shtml',
		    'וַיֵּשֶׁב',
		    'Amos 2:6 - 3:8', '',
		    ],
 "Miketz"	=> [
		    '/5761/mikketz.shtml', 'Genesis 41:1 - 44:17',
		    '/jpstext/mikketz.shtml',
		    'מִקֵּץ',
		    'I Kings 3:15 - 4:1', '',
		    ],
 "Vayigash"	=> [
		    '/5761/vayiggash.shtml', 'Genesis 44:18 - 47:27',
		    '/jpstext/vayiggash.shtml',
		    'וַיִּגַּשׁ',
		    'Ezekiel 37:15 - 37:28', '',
		    ],
 "Vayechi"	=> [
		    '/5761/vayehi.shtml', 'Genesis 47:28 - 50:26',
		    '/jpstext/vayehi.shtml',
		    'וַיְחִי',
		    'I Kings 2:1 - 12', '',
		    ],
 "Shemot"	=> [
		    '/5761/shemot.shtml', 'Exodus 1:1 - 5:26',
		    '/jpstext/shemot.shtml',
		    'שְׁמוֹת',
		    'Isaiah 27:6 - 28:13; 29:22 - 29:23', 'Jeremiah 1:1 - 2:3',
		    ],
 "Vaera"	=> [
		    '/5761/vaera.shtml', 'Exodus 6:2 - 9:35',
		    '/jpstext/vaera.shtml',
		    'וָאֵרָא',
		    'Ezekiel 28:25 - 29:21', '',
		    ],
 "Bo"		=> [
		    '/5761/bo.shtml', 'Exodus 10:1 - 13:16',
		    '/jpstext/bo.shtml',
		    'בֹּא',
		    'Jeremiah 46:13 - 46:28', '',
		    ],
 "Beshalach"	=> [
		    '/5761/beshallah.shtml', 'Exodus 13:17 - 17:16',
		    '/jpstext/beshallah.shtml',
		    'בְּשַׁלַּח',
		    'Judges 4:4 - 5:31', 'Judges 5:1 - 5:31',
		    ],
 "Yitro"	=> [
		    '/5761/yitro.shtml', 'Exodus 18:1 - 20:23',
		    '/jpstext/yitro.shtml',
		    'יִתְרוֹ',
		    'Isaiah 6:1 - 7:6; 9:5 - 9:6', 'Isaiah 6:1 - 6:13',
		    ],
 "Mishpatim"	=> [
		    '/5761/mishpatim.shtml', 'Exodus 21:1 - 24:18',
		    '/jpstext/mishpatim.shtml',
		    'מִּשְׁפָּטִים',
		    'Jeremiah 34:8 - 34:22; 33:25 - 33:26', '',
		    ],
 "Terumah"	=> [
		    '/5761/terumah.shtml', 'Exodus 25:1 - 27:19',
		    '/jpstext/terumah.shtml',
		    'תְּרוּמָה',
		    'I Kings 5:26 - 6:13', '',
		    ],
 "Tetzaveh"	=> [
		    '/5760/tetsavveh.shtml', 'Exodus 27:20 - 30:10',
		    '/jpstext/tetsavveh.shtml',
		    'תְּצַוֶּה',
		    'Ezekiel 43:10 - 43:27', '',
		    ],
 "Ki Tisa"	=> [
		    '/5760/kitissa.shtml', 'Exodus 30:11 - 34:35',
		    '/jpstext/kitissa.shtml',
		    'כִּי תִשָּׂא',
		    'I Kings 18:1 - 18:39', 'I Kings 18:20 - 18:39',
		    ],
 "Vayakhel"	=> [
		    '/5760/vayakhel.shtml', 'Exodus 35:1 - 38:20',
		    '/jpstext/vayakhel.shtml',
		    'וַיַּקְהֵל',
		    'I Kings 7:40 - 7:50', 'I Kings 7:13 - 7:26',
		    ],
 "Pekudei"	=> [
		    '/5760/pekuday.shtml', 'Exodus 38:21 - 40:38',
		    '/jpstext/pekudey.shtml',
		    'פְקוּדֵי',
		    'I Kings 7:51 - 8:21', 'I Kings 7:40 - 7:50',
		    ],
 "Vayikra"	=> [
		    '/5760/vayikra.shtml', 'Leviticus 1:1 - 5:26',
		    '/jpstext/vayikra.shtml',
		    'וַיִּקְרָא',
		    'Isaiah 43:21 - 44:23', '',
		    ],
 "Tzav"		=> [
		    '/5760/tsav.shtml', 'Leviticus 6:1 - 8:36',
		    '/jpstext/tsav.shtml',
		    'צַו',
		    'Jeremiah 7:21 - 8:3; 9:22 - 9:23', '',
		    ],
 "Shmini"	=> [
		    '/5760/shemini.shtml', 'Leviticus 9:1 - 11:47',
		    '/jpstext/shemini.shtml',
		    'שְּׁמִינִי',
		    'II Samuel 6:1 - 7:17', 'II Samuel 6:1 - 6:19',
		    ],
 "Tazria"	=> [
		    '/5760/tazria.shtml', 'Leviticus 12:1 - 13:59',
		    '/jpstext/tazria.shtml',
		    'תַזְרִיעַ',
		    'II Kings 4:42 - 5:19', '',
		    ],
 "Metzora"	=> [
		    '/5759/tazriametzora.shtml', 'Leviticus 14:1 - 15:33',
		    '/jpstext/metsora.shtml',
		    'מְּצֹרָע',
		    'II Kings 7:3 - 7:20', '',
		    ],
 "Achrei Mot"	=> [
		    '/5755/ahareymot.shtml', 'Leviticus 16:1 - 18:30',
		    '/jpstext/ahareimot.shtml',
		    'אַחֲרֵי מוֹת',
		    'Ezekiel 22:1 - 22:19', 'Ezekiel 22:1 - 22:16',
		    ],
 "Kedoshim"	=> [
		    '/5760/kedoshim.shtml', 'Leviticus 19:1 - 20:27',
		    '/jpstext/kedoshim.shtml',
		    'קְדשִׁים',
		    'Amos 9:7 - 9:15', 'Ezekiel 20:2 - 20:20',
		    ],
 "Emor"		=> [
		    '/5760/emor.shtml', 'Leviticus 21:1 - 24:23',
		    '/jpstext/emor.shtml',
		    'אֱמוֹר',
		    'Ezekiel 44:15 - 44:31', '',
		    ],
 "Behar"	=> [
		    '/5760/behar.shtml', 'Leviticus 25:1 - 26:2',
		    '/jpstext/behar.shtml',
		    'בְּהַר',
		    'Jeremiah 32:6 - 32:27', '',
		    ],
 "Bechukotai"	=> [
		    '/5760/behukkotai.shtml', 'Leviticus 26:3 - 27:34',
		    '/jpstext/behukkotai.shtml',
		    'בְּחֻקֹּתַי',
		    'Jeremiah 16:19 - 17:14', '',
		    ],
 "Bamidbar"	=> [
		    '/5760/bemidbar.shtml', 'Numbers 1:1 - 4:20',
		    '/jpstext/bemidbar.shtml',
		    'בְּמִדְבַּר',
		    'Hosea 2:1 - 2:22', '',
		    ],
 "Nasso"	=> [
		    '/5760/naso.shtml', 'Numbers 4:21 - 7:89',
		    '/jpstext/naso.shtml',
		    'נָשׂא',
		    'Judges 13:2 - 13:25', '',
		    ],
 "Beha'alotcha" => [
		    '/5760/behaalothekha.shtml', 'Numbers 8:1 - 12:16',
		    '/jpstext/behaalothekha.shtml',
		    'בְּהַעֲלֹתְךָ',
		    'Zechariah 2:14 - 4:7', '',
		    ],
 "Sh'lach"	=> [
		    '/5760/shelahlekha.shtml', 'Numbers 13:1 - 15:41',
		    '/jpstext/shelahlekha.shtml',
		    'שְׁלַח־לְךָ',
		    'Joshua 2:1 - 2:24', '',
		    ],
 "Korach"	=> [
		    '/5760/korah.shtml', 'Numbers 16:1 - 18:32',
		    '/jpstext/korah.shtml',
		    'קוֹרַח',
		    'I Samuel 11:14 - 12:22', '', 
		    ],
 "Chukat"	=> [
		    '/5760/hukkatbalak.shtml', 'Numbers 19:1 - 22:1',
		    '/jpstext/hukkat.shtml',
		    'חֻקַּת',
		    'Judges 11:1 - 11:33', '',
		    ],
 "Balak"	=> [
		    '/5760/hukkatbalak.shtml', 'Numbers 22:2 - 25:9',
		    '/jpstext/balak.shtml',
		    'בָּלָק',
		    'Micah 5:6 - 6:8', '',
		    ],
 "Pinchas"	=> [
		    '/5760/pinhas.shtml', 'Numbers 25:10 - 30:1',
		    '/jpstext/pinhas.shtml',
		    'פִּינְחָס',
		    'I Kings 18:46 - 19:21', '',
		    ],
 "Matot"	=> [
		    '/5760/mattotmaseei.shtml', 'Numbers 30:2 - 32:42',
		    '/jpstext/mattot.shtml',
		    'מַּטּוֹת',
		    'Jeremiah 1:1 - 2:3', '',
		    ],
 "Masei"	=> [
		    '/5760/mattotmaseei.shtml', 'Numbers 33:1 - 36:13',
		    '/jpstext/maseei.shtml',
		    'מַסְעֵי',
		    'Jeremiah 2:4 - 28; 3:4', 'Jeremiah 2:4 - 28; 4:1 - 4:2',
		    ],
 "Devarim"	=> [
		    '/5760/devarim.shtml', 'Deuteronomy 1:1 - 3:22',
		    '/jpstext/devarim.shtml',
		    'דְּבָרִים',
		    'Isaiah 1:1 - 1:27', '',
		    ],
 "Vaetchanan"	=> [
		    '/5760/vaethannan.shtml', 'Deuteronomy 3:23 - 7:11',
		    '/jpstext/vaethannan.shtml',
		    'וָאֶתְחַנַּן',
		    'Isaiah 40:1 - 40:26', '',
		    ],
 "Eikev"	=> [
		    '/5760/ekev.shtml', 'Deuteronomy 7:12 - 11:25',
		    '/jpstext/ekev.shtml',
		    'עֵקֶב',
		    'Isaiah 49:14 - 51:3', '',
		    ],
 "Re'eh"	=> [
		    '/5760/reeh.shtml', 'Deuteronomy 11:26 - 16:17',
		    '/jpstext/reeh.shtml',
		    'רְאֵה',
		    'Isaiah 54:11 - 55:5', '',
		    ],
 "Shoftim"	=> [
		    '/5760/shofetim.shtml', 'Deuteronomy 16:18 - 21:9',
		    '/jpstext/shofetim.shtml',
		    'שׁוֹפְטִים',
		    'Isaiah 51:12 - 52:12', '',
		    ],
 "Ki Teitzei"	=> [
		    '/5760/kitetse.shtml', 'Deuteronomy 21:10 - 25:19',
		    '/jpstext/kitetse.shtml',
		    'כִּי־תֵצֵא',
		    'Isaiah 54:1 - 54:10', '',
		    ],
 "Ki Tavo"	=> [
		    '/5760/kitavo.shtml', 'Deuteronomy 26:1 - 29:8',
		    '/jpstext/kitavo.shtml',
		    'כִּי־תָבוֹא',
		    'Isaiah 60:1 - 60:22', '',
		    ],
 "Nitzavim"	=> [
		    '/5760/nitsavimvayelekh.shtml',
		    'Deuteronomy 29:9 - 30:20',
		    '/jpstext/nitsavim.shtml',
		    'נִצָּבִים',
		    'Isaiah 61:10 - 63:9', '',
		    ],
 "Vayeilech"	=> [
		    '/5760/nitsavimvayelekh.shtml',
		    'Deuteronomy 31:1 - 31:30',
		    '/jpstext/vayelekh.shtml',
		    'וַיֵּלֶךְ',
		    'Isaiah 55:6 - 56:8', '',
		    ],
 "Ha'Azinu"	=> [
		    'http://www.ohr.org.il/tw/5759/devarim/haazinu.htm',
		    'Deuteronomy 32:1 - 31:52',
		    '/jpstext/haazinu.shtml',
		    'הַאֲזִינוּ',
		    'II Samuel 22:1 - 22:51', '',
		    ],
 "Vezot Haberakhah"
	        => ['',
		    'Deuteronomy 33:1 - 34:12',
		    '',
		    '',
		    'Joshua 1:1 - 1:18', 'Joshua 1:1 - 1:9',
		    ],

 "Rosh Hashana"	=> ['/5761/roshhashanah.shtml', '', '', ''],
 "Yom Kippur"	=> ['/5759/yk.shtml', '', '', ''],
 "Sukkot"	=> ['/5761/sukkot.shtml', '', '', ''],
 "Simchat Torah" => ['/5761/simhattorah.shtml', '', '', 'וְזֹאת הַבְּרָכָה'],
 "Pesach"	=> ['/5760/pesah.shtml', '', '', ''],
 "Shavuot"	=> ['/5760/shavuot.shtml', '', '', ''],
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

    $yomtov = 1  if (defined $holidays{$subj_copy} &&
	$holidays{$subj_copy}->[$HOLIDAY_IDX_YOMTOV]);

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
    my($time) = &Time::Local::timegm(0,0,9,$mday,$mon,$year,0,0,0); # 9am

    (localtime($time))[6];	# $wday
}

sub get_holiday_anchor($$)
{
    my($subj,$want_sephardic) = @_;
    my($href) = '';
    my($hebrew) = '';
    my($memo) = '';
    my($haftarah_href) = '';
    my($torah_href) = '';

    if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)$/)
    {
	my($parashat) = $1;
	my($sedra) = $2;

	$hebrew = 'פרשת ';
	$sedra = $ashk2seph{$sedra} if (defined $ashk2seph{$sedra});

	if (defined $sedrot{$sedra})
	{
	    $href = $sedrot{$sedra}->[$SEDROT_IDX_DRASH_EN];
	    $torah_href = $sedrot{$sedra}->[$SEDROT_IDX_TORAH_EN];
	    if ($torah_href =~ m,^/jpstext/,)
	    {
		$haftarah_href = $torah_href;
		$haftarah_href =~ s/.shtml$/_haft.shtml/;
	    }

	    $hebrew .= $sedrot{$sedra}->[$SEDROT_IDX_TITLE_HE];
	    $memo = "Torah: " . $sedrot{$sedra}->[$SEDROT_IDX_VERSE_EN] .
		" -- Haftarah: ";
	    
	    if ($want_sephardic &&
		defined $sedrot{$sedra}->[$SEDROT_IDX_HAFT_SEPH])
	    {
		$memo .= $sedrot{$sedra}->[$SEDROT_IDX_HAFT_SEPH];
	    }
	    else
	    {
		$memo .= $sedrot{$sedra}->[$SEDROT_IDX_HAFT_ASHK];
	    }
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
	       (defined $sedrot{$1} || defined($sedrot{$ashk2seph{$1}})))
	{
	    my($p1,$p2) = ($1,$2);

	    $p1 = $ashk2seph{$p1} if (defined $ashk2seph{$p1});
	    $p2 = $ashk2seph{$p2} if (defined $ashk2seph{$p2});

	    $href = $sedrot{$p1}->[$SEDROT_IDX_DRASH_EN];
	    $torah_href = $sedrot{$p1}->[$SEDROT_IDX_TORAH_EN];
	    if ($torah_href =~ m,^/jpstext/,)
	    {
		$haftarah_href = $torah_href;
		$haftarah_href =~ s/.shtml$/_haft.shtml/;
	    }

	    $hebrew .= $sedrot{$p1}->[$SEDROT_IDX_TITLE_HE];
	    $memo = "Torah: " . $sedrot{$p1}->[$SEDROT_IDX_VERSE_EN];

	    if (defined $sedrot{$p2})
	    {
		$hebrew .= '־' . $sedrot{$p2}->[$SEDROT_IDX_TITLE_HE];
		$memo .= '; ' . $sedrot{$p2}->[$SEDROT_IDX_VERSE_EN];
	    }

	    $memo .= " -- Haftarah: ";
	    if ($want_sephardic &&
		defined $sedrot{$p1}->[$SEDROT_IDX_HAFT_SEPH])
	    {
		$memo .= $sedrot{$p1}->[$SEDROT_IDX_HAFT_SEPH];
	    }
	    else
	    {
		$memo .= $sedrot{$p1}->[$SEDROT_IDX_HAFT_ASHK];
	    }

	    if (defined $sedrot{$p2})
	    {
		$memo .= '; ';
		if ($want_sephardic &&
		    defined $sedrot{$p2}->[$SEDROT_IDX_HAFT_SEPH])
		{
		    $memo .= $sedrot{$p2}->[$SEDROT_IDX_HAFT_SEPH];
		}
		else
		{
		    $memo .= $sedrot{$p2}->[$SEDROT_IDX_HAFT_ASHK];
		}
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

	if (defined $holidays{$subj_copy})
	{
	    $href = "/hebcal/help/defaults.html#" .
		$holidays{$subj_copy}->[$HOLIDAY_IDX_ANCHOR];

	    if (defined $holidays{$subj_copy}->[$HOLIDAY_IDX_TITLE_HE])
	    {
		$hebrew = $holidays{$subj_copy}->[$HOLIDAY_IDX_TITLE_HE]
		    unless $holidays{$subj_copy}->[$HOLIDAY_IDX_TITLE_HE]
			=~ /\*\*\*/;
	    }
	}
    }

    return (wantarray()) ? ($href,$hebrew,$memo,$torah_href,$haftarah_href)
	: $href;
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
