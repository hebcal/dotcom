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

my(%holidays) = (
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

my($SEDROT_IDX_DRASH_EN) = 0;
my($SEDROT_IDX_VERSE_EN) = 1;
my($SEDROT_IDX_TORAH_EN) = 2;
my($SEDROT_IDX_TITLE_HE) = 3;

my(%sedrot) = (
 "Bereshit"	=> ['/5761/bereshit.shtml', 'Genesis 1:1 - 6:8',
		    '/jpstext/bereshit.shtml',
		    'áÌÀøÅàùÑÄéú'],
 "Bereshis"	=> ['/5761/bereshit.shtml', 'Genesis 1:1 - 6:8',
		    '/jpstext/bereshit.shtml',
		    'áÌÀøÅàùÑÄéú'],
 "Noach"	=> ['/5761/noah.shtml', 'Genesis 6:9 - 11:32',
		    '/jpstext/noah.shtml',
		    'ðÉçÇ'],
 "Lech-Lecha"	=> ['/5761/lekhlekha.shtml', 'Genesis 12:1 - 17:27',
		    '/jpstext/lechlecha.shtml',
		    'ìÆêÀÎìÀêÈ'],
 "Vayera"	=> ['/5761/vayera.shtml', 'Genesis 18:1 - 22:24',
		    '/jpstext/vayera.shtml',
		    'åÇéÌÅøÈà'],
 "Chayei Sara"	=> ['/5761/hayyeisarah.shtml', 'Genesis 23:1 - 25:18',
		    '/jpstext/hayyeisarah.shtml',
		    'çÇéÌÅé ùÈÉøÈä'],
 "Toldot"	=> ['/5761/toledot.shtml', 'Genesis 25:19 - 28:9',
		    '/jpstext/toledot.shtml',
		    'úÌÍåÉìÀãÉú'],
 "Toldos"	=> ['/5761/toeldot.shtml', 'Genesis 25:19 - 28:9',
		    '/jpstext/toledot.shtml',
		    'úÌÍåÉìÀãÉú'],
 "Vayetzei"	=> ['/5761/vayetze.shtml', 'Genesis 28:10 - 32:3',
		    '/jpstext/vayetze.shtml',
		    'åÇéÌÅöÅà'],
 "Vayishlach"	=> ['/5761/vayishlah.shtml', 'Genesis 32:4 - 36:43',
		    '/jpstext/vayishlah.shtml',
		    'åÇéÌÄùÑÀìÇç'],
 "Vayeshev"	=> ['/5761/vayeshev.shtml', 'Genesis 37:1 - 40:23',
		    '/jpstext/vayeshev.shtml',
		    'åÇéÌÅùÑÆá'],
 "Miketz"	=> ['/5761/mikketz.shtml', 'Genesis 41:1 - 44:17',
		    '/jpstext/mikketz.shtml',
		    'îÄ÷ÌÅõ'],
 "Vayigash"	=> ['/5761/vayiggash.shtml', 'Genesis 44:18 - 47:27',
		    '/jpstext/vayiggash.shtml',
		    'åÇéÌÄâÌÇùÑ'],
 "Vayechi"	=> ['/5761/vayehi.shtml', 'Genesis 47:28 - 50:26',
		    '/jpstext/vayehi.shtml',
		    'åÇéÀçÄé'],
 "Shemot"	=> ['/5761/shemot.shtml', 'Exodus 1:1 - 5:26',
		    '/jpstext/shemot.shtml',
		    ''],
 "Shemos"	=> ['/5761/shemot.shtml', 'Exodus 1:1 - 5:26',
		    '/jpstext/shemot.shtml',
		    'ùÑÀîåÉú'],
 "Vaera"	=> ['/5761/vaera.shtml', 'Exodus 6:2 - 9:35',
		    '/jpstext/vaera.shtml',
		    'åÈÍàÅøÈà'],
 "Bo"		=> ['/5760/bo.shtml', 'Exodus 10:1 - 13:16',
		    '/jpstext/bo.shtml',
		    'áÌÉà'],
 "Beshalach"	=> ['/5760/beshalah.shtml', 'Exodus 13:17 - 17:16',
		    '/jpstext/beshallah.shtml',
		    'áÌÀùÑÇìÌÇç'],
 "Yitro"	=> ['/5760/yitro.shtml', 'Exodus 18:1 - 20:23',
		    '/jpstext/yitro.shtml',
		    'éÄúÀøåÉ'],
 "Yisro"	=> ['/5760/yitro.shtml', 'Exodus 18:1 - 20:23',
		    '/jpstext/yitro.shtml',
		    'éÄúÀøåÉ'],
 "Mishpatim"	=> ['/5760/mishpatim.shtml', 'Exodus 21:1 - 24:18',
		    '/jpstext/mishpatim.shtml',
		    'îÌÄùÑÀôÌÈèÄéí'],
 "Terumah"	=> ['/5760/terumah.shtml', 'Exodus 25:1 - 27:19',
		    '/jpstext/terumah.shtml',
		    'úÌÀøåÌîÈä'],
 "Tetzaveh"	=> ['/5760/tetsavveh.shtml', 'Exodus 27:20 - 30:10',
		    '/jpstext/tetsavveh.shtml',
		    'úÌÀöÇåÌÆä'],
 "Ki Tisa"	=> ['/5760/kitissa.shtml', 'Exodus 30:11 - 34:35',
		    '/jpstext/kitissa.shtml',
		    'ëÌÄé úÄùÌÒÈà'],
 "Ki Sisa"	=> ['/5760/kitissa.shtml', 'Exodus 30:11 - 34:35',
		    '/jpstext/kitissa.shtml',
		    'ëÌÄé úÄùÌÒÈà'],
 "Vayakhel"	=> ['/5760/vayakhel.shtml', 'Exodus 35:1 - 38:20',
		    '/jpstext/vayakhel.shtml',
		    'åÇéÌÇ÷ÀäÅì'],
 "Pekudei"	=> ['/5760/pekuday.shtml', 'Exodus 38:21 - 40:38',
		    '/jpstext/pekudey.shtml',
		    'ôÀ÷åÌãÅé'],
 "Vayikra"	=> ['/5760/vayikra.shtml', 'Leviticus 1:1 - 5:26',
		    '/jpstext/vayikra.shtml',
		    'åÇéÌÄ÷ÀøÈà'],
 "Tzav"		=> ['/5760/tsav.shtml', 'Leviticus 6:1 - 8:36',
		    '/jpstext/tzav.shtml',
		    'öÇå'],
 "Shmini"	=> ['/5760/shemini.shtml', 'Leviticus 9:1 - 11:47',
		    '/jpstext/shemini.shtml',
		    'ùÌÑÀîÄéðÄé'],
 "Tazria"	=> ['/5760/tazria.shtml', 'Leviticus 12:1 - 13:59',
		    '/jpstext/tazria.shtml',
		    'úÇæÀøÄéòÇ'],
 "Sazria"	=> ['/5760/tazria.shtml', 'Leviticus 12:1 - 13:59',
		    '/jpstext/tazria.shtml',
		    'úÇæÀøÄéòÇ'],
 "Metzora"	=> ['/5759/tazriametzora.shtml', 'Leviticus 14:1 - 15:33',
		    '/jpstext/metsora.shtml',
		    'îÌÀöåÉøÈò'],
 "Achrei Mot"	=> ['/5755/ahareymot.shtml', 'Leviticus 16:1 - 18:30',
		    '/jpstext/ahareimot.shtml',
		    'àÇÍçÂøÅé îåÉú'],
 "Achrei Mos"	=> ['/5755/ahareymot.shtml', 'Leviticus 16:1 - 18:30',
		    '/jpstext/ahareimot.shtml',
		    'àÇÍçÂøÅé îåÉú'],
 "Kedoshim"	=> ['/5760/kedoshim.shtml', 'Leviticus 19:1 - 20:27',
		    '/jpstext/kedoshim.shtml',
		    '÷ÀãùÑÄéí'],
 "Emor"		=> ['/5760/emor.shtml', 'Leviticus 21:1 - 24:23',
		    '/jpstext/emor.shtml',
		    'àÁîåÉø'],
 "Behar"	=> ['/5760/behar.shtml', 'Leviticus 25:1 - 26:2',
		    '/jpstext/behar.shtml',
		    'áÌÀäÇø'],
 "Bechukotai"	=> ['/5760/behukkotai.shtml', 'Leviticus 26:3 - 27:34',
		    '/jpstext/behukkotai.shtml',
		    'áÌÀçË÷ÌÉúÇé'],
 "Bechukosai"	=> ['/5760/behukkotai.shtml', 'Leviticus 26:3 - 27:34',
		    '/jpstext/behukkotai.shtml',
		    'áÌÀçË÷ÌÉúÇé'],
 "Bamidbar"	=> ['/5760/bemidbar.shtml', 'Numbers 1:1 - 4:20',
		    '/jpstext/bemidbar.shtml',
		    'áÌÀîÄãÀáÌÇø'],
 "Nasso"	=> ['/5760/naso.shtml', 'Numbers 4:21 - 7:89',
		    '/jpstext/naso.shtml',
		    'ðÈùÒà'],
 "Beha'alotcha" => ['/5760/behaalothekha.shtml', 'Numbers 8:1 - 12:16',
		    '/jpstext/behaalothekha.shtml',
		    'áÌÀäÇÍòÂìÉÍúÀêÈ'],
 "Beha'aloscha" => ['/5760/behaalothekha.shtml', 'Numbers 8:1 - 12:16',
		    '/jpstext/behaalothekha.shtml',
		    'áÌÀäÇÍòÂìÉÍúÀêÈ'],
 "Sh'lach"	=> ['/5760/shelahlekha.shtml', 'Numbers 13:1 - 15:41',
		    '/jpstext/shelahlekha.shtml',
		    'ùÑÀìÇçÎìÀêÈ'],
 "Korach"	=> ['/5760/korah.shtml', 'Numbers 16:1 - 18:32',
		    '/jpstext/korah.shtml',
		    '÷ÉøÇç'],
 "Chukat"	=> ['/5760/hukkatbalak.shtml', 'Numbers 19:1 - 22:1',
		    '/jpstext/hukkat.shtml',
		    'çË÷ÌÇú'],
 "Chukas"	=> ['/5760/hukkatbalak.shtml', 'Numbers 19:1 - 22:1',
		    '/jpstext/hukkat.shtml',
		    'çË÷ÌÇú'],
 "Balak"	=> ['/5760/hukkatbalak.shtml', 'Numbers 22:2 - 25:9',
		    '/jpstext/balak.shtml',
		    'áÌÈìÈ÷'],
 "Pinchas"	=> ['/5760/pinhas.shtml', 'Numbers 25:10 - 30:1',
		    '/jpstext/pinhas.shtml',
		    'ôÌÄÍéðÀçÈñ'],
 "Matot"	=> ['/5760/mattotmaseei.shtml', 'Numbers 30:2 - 32:42',
		    '/jpstext/mattot.shtml',
		    'îÌÇèÌåÉú'],
 "Matos"	=> ['/5760/mattotmaseei.shtml', 'Numbers 30:2 - 32:42',
		    '/jpstext/mattot.shtml',
		    'îÌÇèÌåÉú'],
 "Masei"	=> ['/5760/mattotmaseei.shtml', 'Numbers 33:1 - 36:13',
		    '/jpstext/maseei.shtml',
		    'îÇñÀòÅé'],
 "Devarim"	=> ['/5760/devarim.shtml', 'Deuteronomy 1:1 - 3:22',
		    '/jpstext/devarim.shtml',
		    'ãÌÀáÈøÄéí'],
 "Vaetchanan"	=> ['/5760/vaethannan.shtml', 'Deuteronomy 3:23 - 7:11',
		    '/jpstext/vaethannan.shtml',
		    'åÈÍàÆúÀçÇðÌÇï'],
 "Vaeschanan"	=> ['/5760/vaethannan.shtml', 'Deuteronomy 3:23 - 7:11',
		    '/jpstext/vaethannan.shtml',
		    'åÈÍàÆúÀçÇðÌÇï'],
 "Eikev"	=> ['/5760/ekev.shtml', 'Deuteronomy 7:12 - 11:25',
		    '/jpstext/ekev.shtml',
		    'òÅ÷Æá'],
 "Re'eh"	=> ['/5760/reeh.shtml', 'Deuteronomy 11:26 - 16:17',
		    '/jpstext/reeh.shtml',
		    'øÀàÅä'],
 "Shoftim"	=> ['/5760/shofetim.shtml', 'Deuteronomy 16:18 - 21:9',
		    '/jpstext/shofetim.shtml',
		    'ùÑÍÉôÀèÄéí'],
 "Ki Teitzei"	=> ['/5760/kitetse.shtml', 'Deuteronomy 21:10 - 25:19',
		    '/jpstext/kitetse.shtml',
		    'ëÌÄÍéÎúÅöÅà'],
 "Ki Seitzei"	=> ['/5760/kitetse.shtml', 'Deuteronomy 21:10 - 25:19',
		    '/jpstext/kitetse.shtml',
		    'ëÌÄÍéÎúÅöÅà'],
 "Ki Tavo"	=> ['/5760/kitavo.shtml', 'Deuteronomy 26:1 - 29:8',
		    '/jpstext/kitavo.shtml',
		    'ëÌÄÍéÎúÈáåÉà'],
 "Ki Savo"	=> ['/5760/kitavo.shtml', 'Deuteronomy 26:1 - 29:8',
		    '/jpstext/kitavo.shtml',
		    'ëÌÄÍéÎúÈáåÉà'],
 "Nitzavim"	=> ['/5760/nitsavimvayelekh.shtml',
		    'Deuteronomy 29:9 - 30:20',
		    '/jpstext/nitsavim.shtml',
		    'ðÄöÌÈáÄéí'],
 "Vayeilech"	=> ['/5760/nitsavimvayelekh.shtml',
		    'Deuteronomy 31:1 - 31:30',
		    '/jpstext/vayelekh.shtml',
		    'åÇéÌÅìÆêÀ'],
 "Ha'Azinu"	=> ['http://www.ohr.org.il/tw/5759/devarim/haazinu.htm',
		    'Deuteronomy 32:1 - 31:52',
		    '/jpstext/haazinu.shtml',
		    'äÇÍàÂæÄéðåÌ'],

 "Rosh Hashana"	=> ['/5761/roshhashanah.shtml', '', '', ''],
 "Yom Kippur"	=> ['/5759/yk.shtml', '', '', ''],
 "Sukkot"	=> ['/5761/sukkot.shtml', '', '', ''],
 "Sukkos"	=> ['/5761/sukkot.shtml', '', '', ''],
 "Simchat Torah" => ['/5761/simhattorah.shtml', '', '', 'åÀæÉàú äÇáÌÀøÈëÈä'],
 "Simchas Torah" => ['/5761/simhattorah.shtml', '', '', 'åÀæÉàú äÇáÌÀøÈëÈä'],
 "Pesach"	=> ['/5760/pesah.shtml', '', '', ''],
 "Shavuot"	=> ['/5760/shavuot.shtml', '', '', ''],
 "Shavuos"	=> ['/5760/shavuot.shtml', '', '', ''],
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
$Hebcal::EVT_IDX_MDAY = 4;		# day of month, [0 .. 31]
$Hebcal::EVT_IDX_MON = 5;		# month of year, [0 .. 1]
$Hebcal::EVT_IDX_YEAR = 6;		# year [1970 .. 2037]
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
	my($href);

	if (defined $sedrot{$sedra})
	{
	    $href = $sedrot{$sedra}->[$SEDROT_IDX_DRASH_EN];
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) && defined $sedrot{$1})
	{
	    $href = $sedrot{$1}->[$SEDROT_IDX_DRASH_EN];
	}

	if (defined $href)
	{
	    if ($href =~ m,^/,)
	    {
		return 'http://learn.jtsa.edu/topics/parashah' . $href;
	    }
	    else
	    {
		return $href;
	    }
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

    if ($len > 64) { $len = 64; }
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

	if ($dst == 0)
	{
	    # no DST, so just use gmtime and then add that city offset
	    $startTime =
		&Time::Local::timegm(0,
				     $events->[$i]->[$Hebcal::EVT_IDX_MIN],
				     $events->[$i]->[$Hebcal::EVT_IDX_HOUR],
				     $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
				     $events->[$i]->[$Hebcal::EVT_IDX_MON],
				     $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
				     0,0,0);
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
					$events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
					0,0,0);
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

1;
