########################################################################
# Hebcal Interactive Jewish Calendar is a web site that lets you
# generate a list of Jewish holidays for any year. Candle lighting
# times are calculated from your latitude and longitude (which can
# be determined by your zip code or closest city).
#
# Copyright (c) 2010  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

package Hebcal;

use strict;
use CGI qw(-no_xhtml);
use POSIX qw(strftime);
use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";
use Date::Calc ();
use DBI;
use HebcalConst;
use Digest::MD5 ();

if ($^V && $^V ge v5.8.1) {
    binmode(STDOUT, ":utf8");
}

########################################################################
# constants
########################################################################

my $WEBDIR = "/home/hebcal/web/hebcal.com";
my $EMAIL_PASSFILE = "$WEBDIR/email/hebcal-email-pass.cgi";
my $ZIP_SQLITE_FILE = "$WEBDIR/hebcal/zips.sqlite3";

my($this_year) = (localtime)[5];
$this_year += 1900;

my $VERSION = '$Revision$$';
if ($VERSION =~ /(\d+)/) {
    $VERSION = $1;
}

my $HOSTNAME;
my $CACHE_DIR = $ENV{"DOCUMENT_ROOT"} || ($ENV{"HOME"} . "/tmp");
$CACHE_DIR .= "/cache/";

$Hebcal::gregorian_warning = "<p><span style=\"color:red;font-size:large\">WARNING:
Results for year 1752 C.E. and before may not be accurate.</span>
Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation. For more information, read about the <a
href=\"http://en.wikipedia.org/wiki/Gregorian_calendar#Adoption_in_Europe\">adoption
of the Gregorian Calendar</a>.</p>";

$Hebcal::indiana_warning = "<p><span style=\"color: red\">WARNING:
Indiana has confusing time zone &amp; Daylight Saving Time
rules.</span><br>Please check <a
href=\"http://www.mccsc.edu/time.html#WHAT\">What time is it in
Indiana?</a> to make sure the above settings are correct.</p>";

$Hebcal::usno_warning = "<p><span style=\"color: red\">WARNING:
Candle-lighting times are guaranteed to be wrong at extreme
northern or southern latitudes.</span><br>Please consult your
local halachic authority for correct candle-lighting times.</p>";

# boolean options
@Hebcal::opts = ('c','o','s','i','a','d','D');

$Hebcal::havdalah_min = 72;
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

%Hebcal::lang_names =
    (
     "s"  => "Sephardic transliterations",
     "sh" => "Sephardic translit. + Hebrew",
     "a"  => "Ashkenazis transliterations",
     "ah" => "Ashkenazis translit. + Hebrew",
     "h"  => "Hebrew only",
     );

%Hebcal::dst_names =
    (
     'none'    => 'none',
     'usa'     => 'USA and Canada',
     'mx'     =>  'Mexico',
     'israel'  => 'Israel',
     'eu'      => 'European Union',
     'aunz'    => 'Australia and NZ',
     );

%Hebcal::city_tz =
    (
     );

%Hebcal::city_dst =
    (
     );

while (my($key,$val) = each %HebcalConst::CITIES)
{
    $Hebcal::city_tz{$key} = $val->[0];
    $Hebcal::city_dst{$key} = $val->[1];
}


# translate from Askenazic transiliterations to Separdic
%Hebcal::ashk2seph =
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
  "Purim Koton"			=>	"Purim Katan",
  "Ta'anis Bechoros"		=>	"Ta'anit Bechorot",

  # special shabbatot
  "Shabbas Shuvah"		=>	"Shabbat Shuva",
  "Shabbas Shekalim"		=>	"Shabbat Shekalim",
  "Shabbas Zachor"		=>	"Shabbat Zachor",
  "Shabbas Parah"		=>	"Shabbat Parah",
  "Shabbas HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbas HaGadol"		=>	"Shabbat HaGadol",
  "Shabbas Chazon"		=>	"Shabbat Chazon",
  "Shabbas Nachamu"		=>	"Shabbat Nachamu",
  "Shabbos Shuvah"		=>	"Shabbat Shuva",
  "Shabbos Shekalim"		=>	"Shabbat Shekalim",
  "Shabbos Zachor"		=>	"Shabbat Zachor",
  "Shabbos Parah"		=>	"Shabbat Parah",
  "Shabbos HaChodesh"		=>	"Shabbat HaChodesh",
  "Shabbos HaGadol"		=>	"Shabbat HaGadol",
  "Shabbos Chazon"		=>	"Shabbat Chazon",
  "Shabbos Nachamu"		=>	"Shabbat Nachamu",
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

my %num2heb =
(
 1	=> "\x{5D0}",
 2	=> "\x{5D1}",
 3	=> "\x{5D2}",
 4	=> "\x{5D3}",
 5	=> "\x{5D4}",
 6	=> "\x{5D5}",
 7	=> "\x{5D6}",
 8	=> "\x{5D7}",
 9	=> "\x{5D8}",
 10	=> "\x{5D9}",
 20	=> "\x{5DB}",
 30	=> "\x{5DC}",
 40	=> "\x{5DE}",
 50	=> "\x{5E0}",
 60	=> "\x{5E1}",
 70	=> "\x{5E2}",
 80	=> "\x{5E4}",
 90	=> "\x{5E6}",
 100	=> "\x{5E7}",
 200	=> "\x{5E8}",
 300	=> "\x{5E9}",
 400	=> "\x{5EA}",
);

my %monthnames =
    (
     "Nisan"	=> "\x{5E0}\x{5B4}\x{5D9}\x{5E1}\x{5B8}\x{5DF}",
     "Iyyar"	=> "\x{5D0}\x{5B4}\x{5D9}\x{5B8}\x{5D9}\x{5E8}",
     "Sivan"	=> "\x{5E1}\x{5B4}\x{5D9}\x{5D5}\x{5B8}\x{5DF}",
     "Tamuz"	=> "\x{5EA}\x{5BC}\x{5B8}\x{5DE}\x{5D5}\x{5BC}\x{5D6}",
     "Av"	=> "\x{5D0}\x{5B8}\x{5D1}",
     "Elul"	=> "\x{5D0}\x{5B1}\x{5DC}\x{5D5}\x{5BC}\x{5DC}",
     "Tishrei"	=> "\x{5EA}\x{5BC}\x{5B4}\x{5E9}\x{5C1}\x{5B0}\x{5E8}\x{5B5}\x{5D9}",
     "Cheshvan"	=> "\x{5D7}\x{5B6}\x{5E9}\x{5C1}\x{5B0}\x{5D5}\x{5B8}\x{5DF}",
     "Kislev"	=> "\x{5DB}\x{5BC}\x{5B4}\x{5E1}\x{5B0}\x{5DC}\x{5B5}\x{5D5}",
     "Tevet"	=> "\x{5D8}\x{5B5}\x{5D1}\x{5B5}\x{5EA}",
     "Sh'vat"	=> "\x{5E9}\x{5C1}\x{5B0}\x{5D1}\x{5B8}\x{5D8}",
     "Adar"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8}",
     "Adar I"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8} \x{5D0}\x{5F3}",
     "Adar II"	=> "\x{5D0}\x{5B7}\x{5D3}\x{5B8}\x{5E8} \x{5D1}\x{5F3}",
     );

my $URCHIN = qq{<script src="http://www.google-analytics.com/urchin.js"
type="text/javascript">
</script>
<script type="text/javascript">
_uacct="UA-967247-1";
urchinTracker();
if(document.getElementsByTagName){
var e3=document.getElementsByTagName("a");
if(e3&&e3.length){
for(var i=0;i<e3.length;i++){if(e3[i]&&e3[i].className=="amzn"){
if(e3[i].id){e3[i].onclick=function(){urchinTracker("/amzn/"+this.id);}}
}}}
var e1=document.getElementById("export");
if(e1){var e2=e1.getElementsByTagName("a");if(e2&&e2.length){
for(var i=0;i<e2.length;i++){if(e2[i]&&e2[i].className=="download"){
if(e2[i].id){e2[i].onclick=function(){urchinTracker("/export/"+this.id);}}}}}}}
</script>
<script src="http://clearmark.anchorintelligence.com/j9999/track.js"
type="text/javascript">
</script>
};

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
	$subj =~ s/Purim Koson/Purim Koton/;
    }

    my($yomtov) = 0;
    my($subj_copy) = $subj;

    $subj_copy = $Hebcal::ashk2seph{$subj_copy}
	if defined $Hebcal::ashk2seph{$subj_copy};
    $subj_copy =~ s/ \d{4}$//; # fix Rosh Hashana

    $yomtov = 1 if $HebcalConst::YOMTOV{$subj_copy};

    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    my($mon,$mday,$year) = split(/\//, $date);

#    if (($subj eq 'Yom HaZikaron' || $subj eq "Yom HaAtzma'ut") &&
#	($year == 2004)) {
#	$mday++;
#    }

    ($subj,$untimed,$min,$hour,$mday,$mon - 1,$year,$dur,$yomtov);
}

sub invoke_hebcal
{
    my($cmd,$memo,$want_sephardic,$month_filter) = @_;
    my(@events,$prev);
    local($_);
    local(*HEBCAL);

    my $cmd_smashed = $cmd;
    $cmd_smashed =~ s/^\S+//;
    $cmd_smashed =~ s/\s+-([A-Za-z])/$1/g;
    $cmd_smashed =~ s/\s+//g;
    $cmd_smashed =~ s/\'//g;

    my $hccache;
    my $login = getlogin() || getpwuid($<) || "UNKNOWN";
    my $hccache_dir = "/tmp/${login}-cache/cmd";

    unless (-d $hccache_dir) {
	system("/bin/mkdir", "-p", $hccache_dir);
    }
    my $hccache_file = "$hccache_dir/$cmd_smashed";

    @events = ();
    if ($cmd_smashed eq "") {
	open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";
    } elsif (open(HEBCAL,"<$hccache_file")) {
	# will read data from cachefile, not pipe
    } else {
	open(HEBCAL,"$cmd |") || die "Can't exec '$cmd': $!\n";
	$hccache = open(HCCACHE,">$hccache_file.$$");
    }

    $prev = '';
    while (<HEBCAL>)
    {
	print HCCACHE $_ if $hccache;
	next if $_ eq $prev;
	$prev = $_;
	chop;

	my($date,$descr) = split(/ /, $_, 2);

	# exec hebcal with entire years, but only return events matching
	# the month requested
	if ($month_filter)
	{
	    my($mon,$mday,$year) = split(/\//, $date);
	    next if $month_filter != $mon;
	}

	my($subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,$yomtov) =
	    parse_date_descr($date,$descr);

	# if Candle lighting and Havdalah are on the same day it is
	# a bug in hebcal for unix involving shabbos and chag overlap.
	# suppress inconsistent times until we can get hebcal fixed.
	if ($subj =~ /^Havdalah/ && $#events >= 0 &&
	    $events[$#events]->[$Hebcal::EVT_IDX_MDAY] == $mday &&
	    $events[$#events]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Candle lighting/)
	{
	    pop(@events);
	    next;
	}

	next if $subj eq 'Havdalah (0 min)';

	my $memo2;
	if ($untimed) {
#	    $memo2 = (Hebcal::get_holiday_anchor($subj,$want_sephardic,
#						 undef))[2];
	    $memo2 = "";
	}

	push(@events,
	     [$subj,$untimed,$min,$hour,$mday,$mon,$year,$dur,
	      ($untimed ? $memo2 : $memo),$yomtov]);
    }
    close(HEBCAL);
    if ($hccache) {
	close(HCCACHE);
	rename("$hccache_file.$$", $hccache_file);
    }

    @events;
}

sub event_to_time
{
    my($evt) = @_;
    # holiday is at 12:00:01 am
    return Time::Local::timelocal(1,0,0,
				  $evt->[$Hebcal::EVT_IDX_MDAY],
				  $evt->[$Hebcal::EVT_IDX_MON],
				  $evt->[$Hebcal::EVT_IDX_YEAR] - 1900,
				  "","","");
}

sub events_to_dict
{
    my($events,$cfg,$q,$friday,$saturday) = @_;

    my $tz = 0;
    my $dst = $q->param("dst");
    if ($q->param("tz"))
    {
	$tz = $q->param("tz");
	$tz = 0 if $tz eq "auto";
    }
    elsif ($q->param("city") && 
	   defined($Hebcal::city_tz{$q->param("city")}))
    {
	$tz = $Hebcal::city_tz{$q->param("city")};
	$dst = $Hebcal::city_dst{$q->param("city")};
    }
    my $tz_save = $tz;

    my $url = "http://" . $q->virtual_host() .
	self_url($q, {"cfg" => undef,
		      "c" => undef,
		      "nh" => undef,
		      "nx" => undef,
		      "tz" => undef,
		      "dst" => undef,
		      });
    my @items;
    for (my $i = 0; $i < scalar(@{$events}); $i++)
    {
	my $time = event_to_time($events->[$i]);
	next if ($friday && $time < $friday) || ($saturday && $time > $saturday);

	my $subj = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my $year = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my $mon = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $mday = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my $min = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my $hour = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my %item;
	my $format = (defined $cfg && $cfg =~ /^[ij]$/) ?
	    "%A, %d %b %Y" : "%A, %d %B %Y";
	$item{"date"} = strftime($format, localtime($time));

	my $tz = $tz_save;
	if (defined $dst && $dst eq "usa") {
	    my($isdst) = (localtime($time))[8];
	    $tz++ if $isdst;
	}

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    $item{"dc:date"} =
		sprintf("%04d-%02d-%02dT%02d:%02d:%02d%s%02d:00",
			$year,$mon,$mday,
			$hour + 12,$min,0,
			$tz > 0 ? "+" : "-",
			abs($tz));

	    my $dow = $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)];
	    $item{"pubDate"} = sprintf("%s, %02d %s %d %02d:%02d:00 %s%02d00",
				       $dow, $mday,
				       $Hebcal::MoY_short[$mon - 1],
				       $year, $hour + 12, $min,
				       $tz > 0 ? "+" : "-",
				       abs($tz));
	}
	else
	{
	    $item{"dc:date"} = sprintf("%04d-%02d-%02d",$year,$mon,$mday);
	    $item{"dc:date"} .= sprintf("T00:00:00%s%02d:00",
					$tz > 0 ? "+" : "-",
					abs($tz));
	    my $dow = $Hebcal::DoW[Hebcal::get_dow($year, $mon, $mday)];
	    $item{"pubDate"} = sprintf("%s, %02d %s %d 00:00:00 %s%02d00",
				       $dow,
				       $mday,
				       $Hebcal::MoY_short[$mon - 1],
				       $year,
				       $tz > 0 ? "+" : "-",
				       abs($tz));
	}

	my $anchor = sprintf("%04d%02d%02d_",$year,$mon,$mday) . lc($subj);
	$anchor =~ s/[^\w]/_/g;
	$anchor =~ s/_+/_/g;
	$anchor =~ s/_$//g;
	$item{"about"} = $url . "#" . $anchor;
	$item{"subj"} = $subj;

	if ($subj eq "Candle lighting" || $subj =~ /Havdalah/)
	{
	    $item{"class"} = ($subj eq "Candle lighting") ?
		"candles" : "havdalah";
	    $item{"time"} = sprintf("%d:%02dpm", $hour, $min);
	    $item{"link"} = $url . "#" . $anchor;
	}
	elsif ($subj eq "No sunset today.")
	{
	    $item{"class"} = "candles";
	    $item{"link"} = $url . "#top";
	    $item{"time"} = "";
	}
	else
	{
	    if ($subj =~ /^(Parshas|Parashat)\s+/) {
		$item{"class"} = "parashat";
	    } elsif ($subj =~ /^(\d+)\w+ day of the Omer$/) {
		$item{"class"} = "omer";
	    } elsif ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/) {
		$item{"class"} = "hebdate";
	    } else {
		$item{"class"} = "holiday";
	    }

	    my($href,$hebrew) = get_holiday_anchor($subj,0,$q);
	    $item{"link"} = $href if $href;
	    $item{"hebrew"} = $hebrew if $hebrew;
	}

	push(@items, \%item);
    }

    \@items;
}

sub items_to_json
{
    my($items,$q,$city_descr,$latitude,$longitude) = @_;

    my $url = "http://" . $q->virtual_host() . self_url($q, {"cfg" => undef});
    $url =~ s,/,\\/,g;

    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime(time())) . "-00:00";

    my $cb = $q->param("callback");
    if ($cb && $cb =~ /^[A-Za-z_]\w*$/) {
	out_html(undef, $cb, "(");
    } else {
	$cb = undef;
    }

    out_html(undef, qq'{"title":"$city_descr",
"link":"$url",
"date":"$dc_date",
');

    if (defined $latitude) {
	out_html(undef, qq'"latitude":$latitude,
"longitude":$longitude,
');
    }

    out_html(undef, qq'"items":[\n');
    items_to_json_inner($items);
    out_html(undef, "]\n}\n");

    out_html(undef, ")\n") if $cb;
}

sub items_to_json_inner
{
    my($items) = @_;

    for (my $i = 0; $i < scalar(@{$items}); $i++) {
	my $subj = $items->[$i]->{"subj"};
	if (defined $items->[$i]->{"time"}) { 
	    $subj .= ": " . $items->[$i]->{"time"};
	}

	my $class = $items->[$i]->{"class"};
	my $date =  $items->[$i]->{"dc:date"};

	out_html(undef, qq'{"title":"$subj",
"category":"$class",
"date":"$date"');

	if ($class =~ /^(parashat|holiday)$/) {
	    my $link =  $items->[$i]->{"link"};
	    $link =~ s,/,\\/,g;
	    out_html(undef, qq',\n"link":"$link"');
	}

	if (defined $items->[$i]->{"hebrew"}) {
	    my $hebrew = $items->[$i]->{"hebrew"};
	    out_html(undef, qq',\n"hebrew":"$hebrew"');
	}

	out_html(undef, "\n}");
	out_html(undef, ",") unless $i+1 == scalar(@{$items});
	out_html(undef, "\n");
    }
}


sub get_dow($$$)
{
    my($year,$mon,$mday) = @_;

    my($dow) = &Date::Calc::Day_of_Week($year,$mon,$mday);
    $dow == 7 ? 0 : $dow;
}
sub hebnum_to_array {
    my($num) = @_;
    my(@result) = ();

    $num = $num % 1000;

    while ($num > 0)
    {
	my($incr) = 100;

	if ($num == 15 || $num == 16)
	{
	    push(@result, 9, $num - 9);
	    last;
	}

	my($i);
	for ($i = 400; $i > $num; $i -= $incr)
	{
	    if ($i == $incr)
	    {
		$incr = int($incr / 10);
	    }
	}

	push(@result, $i);

	$num -= $i;
    }

    @result;
}

sub hebnum_to_string {
    my($num) = @_;

    my(@array) = hebnum_to_array($num);
    my $digits = scalar(@array);
    my($result);

    if ($digits == 1)
    {
	$result = $num2heb{$array[0]} . "\x{5F3}"; # geresh
    }
    else
    {
	$result = '';
	for (my $i = 0; $i < $digits; $i++)
	{
	    $result .= "\x{5F4}" if (($i + 1) == $digits); # gershayim
	    $result .= $num2heb{$array[$i]};
	}
    }

    $result;
}

sub build_hebrew_date($$$)
{
    my($hm,$hd,$hy) = @_;

    hebnum_to_string($hd) . " \x{5D1}\x{5BC}\x{5B0}" .
	$monthnames{$hm} . " " . hebnum_to_string($hy);
}

sub hebrew_strip_nikkud($) {
    my($str) = @_;

    my $result = "";

    foreach my $c (split(//, $str))
    {
	if (ord($c) == 0x05BE) {
	    $result .= $c;
	} elsif (ord($c) > 0x0590 && ord($c) < 0x05D0) {
	    # skip hebrew punctuation range
	} else {
	    $result .= $c;
	}
    }

    return $result;
}


sub make_anchor($)
{
    my($f) = @_;

    my($anchor) = lc($f);
    $anchor =~ s/\'//g;
    $anchor =~ s/[^\w]/-/g;
    $anchor =~ s/-+/-/g;
    $anchor =~ s/^-//g;
    $anchor =~ s/-$//g;

    "$anchor.html";
}

sub get_holiday_anchor($$$)
{
    my($subj,$want_sephardic,$q) = @_;
    my($href) = '';
    my($hebrew) = '';

    if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)$/)
    {
	my($parashat) = $1;
	my($sedra) = $2;

	# Unicode for "parashat"
	$hebrew = "\x{5E4}\x{5E8}\x{5E9}\x{5EA} ";

	$sedra = $Hebcal::ashk2seph{$sedra} if (defined $Hebcal::ashk2seph{$sedra});

	if (defined $HebcalConst::SEDROT{$sedra})
	{
	    my($anchor) = $sedra;
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/sedrot/$anchor.html";

	    $hebrew .= $HebcalConst::SEDROT{$sedra};
	}
	elsif (($sedra =~ /^([^-]+)-(.+)$/) &&
	       (defined $HebcalConst::SEDROT{$1}
		|| defined $HebcalConst::SEDROT{$Hebcal::ashk2seph{$1}}))
	{
	    my($p1,$p2) = ($1,$2);

	    $p1 = $Hebcal::ashk2seph{$p1} if (defined $Hebcal::ashk2seph{$p1});
	    $p2 = $Hebcal::ashk2seph{$p2} if (defined $Hebcal::ashk2seph{$p2});

	    die "aliyah.xml missing $p2!" unless defined $HebcalConst::SEDROT{$p2};

	    my($anchor) = "$p1-$p2";
	    $anchor = lc($anchor);
	    $anchor =~ s/[^\w]//g;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/sedrot/$anchor.html";

	    $hebrew .= $HebcalConst::SEDROT{$p1};

	    # hypenate hebrew reading
	    # HEBREW PUNCTUATION MAQAF (U+05BE)
	    $hebrew .= "\x{5BE}" . $HebcalConst::SEDROT{$p2};
	}
    }
    elsif ($subj =~ /^(\d+)\w+ day of the Omer$/)
    {
	$hebrew = hebnum_to_string($1) .
	    " \x{5D1}\x{5BC}\x{5B0}\x{5E2}\x{5D5}\x{5B9}\x{5DE}\x{5B6}\x{5E8}";
    }
    elsif ($subj =~ /^(\d+)\w+ of ([^,]+), (\d+)$/)
    {
	my($hm,$hd,$hy) = ($2,$1,$3);

	$hebrew = build_hebrew_date($hm,$hd,$hy);
    }
    elsif ($subj =~ /^Yizkor \(.+\)$/ ||
	   $subj =~ /\'s (Hebrew Anniversary|Hebrew Birthday|Yahrzeit)/)
    {
	# don't generate holiday anchors for yahrzeit calendar
    }
    else
    {
	my($subj_copy) = $subj;

	$subj_copy = $Hebcal::ashk2seph{$subj_copy}
	    if defined $Hebcal::ashk2seph{$subj_copy};

	# fix Rosh Hashana and Havdalah
	my $subj_suffix;
	if ($subj_copy =~ / (\d{4})$/) {
	    $subj_suffix = " $1";
	    $subj_copy =~ s/ \d{4}$//;
	} elsif ($subj_copy =~ /^Havdalah \((\d+) min\)$/) {
	    $subj_copy = "Havdalah";
	    $subj_suffix = " - $1 \x{05D3}\x{05E7}\x{05D5}\x{05EA}";
    	}

	if (defined $HebcalConst::HOLIDAYS{$subj_copy})
	{
	    $hebrew = $HebcalConst::HOLIDAYS{$subj_copy};
	    if ($subj_suffix) {
		$hebrew .= $subj_suffix;
	    }
	}

	if ($subj ne 'Candle lighting' && $subj !~ /^Havdalah/ &&
	    $subj ne 'No sunset today.')
	{
	    $subj_copy =~ s/ \(CH\'\'M\)$//;
	    $subj_copy =~ s/ \(Hoshana Raba\)$//;
	    $subj_copy =~ s/ [IV]+$//;
	    $subj_copy =~ s/: \d Candles?$//;
	    $subj_copy =~ s/: 8th Day$//;
	    $subj_copy =~ s/^Erev //;

	    $href = 'http://' . $q->virtual_host()
		if ($q);
	    $href .= "/holidays/" . make_anchor($subj_copy);
	}
    }

    if ($hebrew) {
	$hebrew = hebrew_strip_nikkud($hebrew);
    }

    return (wantarray()) ?
	($href,$hebrew,"")
	: $href;
}
    


########################################################################
# web page utils
########################################################################

sub script_name($)
{
    my($q) = @_;

    my $script_name;
    if (defined $ENV{"SCRIPT_URL"}) {
	$script_name = $ENV{"SCRIPT_URL"};
    } else {
	$script_name = $q->script_name();
	$script_name =~ s,/\w+\.cgi$,/,;
    }

    $script_name;
}


my $cache = undef;
sub cache_begin($)
{
    my($q) = @_;

    return undef unless $ENV{'QUERY_STRING'} || $ENV{'REDIRECT_QUERY_STRING'};

    my $script_name = $q->script_name();
    $script_name =~ s/\./_/g;

    my $qs = $ENV{'QUERY_STRING'} || $ENV{'REDIRECT_QUERY_STRING'};
#    if ($qs =~ /v=1/) {
#	my $s = "v=1";
#	foreach my $key (sort $q->param()) {
#	    next if $key eq "v";
#	    my $val = $q->param($key) || "";
#	    $s .= ";" . url_escape($key) . "=" . url_escape($val);
#	}
#	$qs = $s;
#    }

    $qs =~ s/[&;]?(tag|set)=[^&;]+//g;
    $qs =~ s/[&;]?\.(from|cgifields|s)=[^&;]+//g;
    $qs =~ s/[&;]/,/g;
    $qs =~ s/\./_/g;
    $qs =~ s/\//-/g;
    $qs =~ s/\%20/+/g;
    $qs =~ s/[\<\>\s\"\'\`\?\*\$\|\[\]\{\}\\\~]//g; # unsafe chars

    my $dir = $CACHE_DIR . $script_name;
    unless (-d $dir) {
	system("/bin/mkdir", "-p", $dir) == 0 or return undef;
    }

    $cache = "$dir/$qs.$$";
    if (!open(CACHE, ">$cache")) {
	$cache = undef;
	return undef;
    }

    if ($^V && $^V ge v5.8.1) {
	binmode(CACHE, ":utf8");
    }

    $cache;
}

sub cache_end()
{
    if ($cache)
    {
	close(CACHE);
	my $fn = $cache;
	my $newfn = $fn;
	$newfn =~ s/\.\d+$//;	# no pid
	rename($fn, $newfn);
	$cache = undef;
    }

    1;
}

sub out_html
{
    my($cfg,@args) = @_;

    if (defined $cfg && $cfg eq 'j')
    {
	print STDOUT "document.write(\"";
	print CACHE "document.write(\"" if $cache;
	foreach (@args)
	{
	    s/\"/\\\"/g;
	    s/\n/\\n/g;
	    print STDOUT;
	    print CACHE if $cache;
	}
	print STDOUT "\");\n";
	print CACHE "\");\n" if $cache;
    }
    else
    {
	foreach (@args)
	{
	    print STDOUT;
	    print CACHE if $cache;
	}
    }

    1;
}

sub zipcode_open_db
{
    my($file) = $_[0] ? $_[0] : $ZIP_SQLITE_FILE;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$file", "", "")
	or die $DBI::errstr;
    $dbh;
}

sub zipcode_close_db($)
{
    my($dbh) = @_;
    $dbh->disconnect();
}

sub zipcode_get_zip($$)
{
    my($dbh,$zipcode) = @_;

    my $sql = qq{
SELECT zips_latitude, zips_longitude, zips_timezone, zips_dst, zips_city, zips_state
FROM hebcal_zips
WHERE zips_zipcode = '$zipcode'
};

    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute() or die $dbh->errstr;

    my($latitude,$longitude,$tz,$dst,$city,$state) = $sth->fetchrow_array;
    $sth->finish;
    ($latitude,$longitude,$tz,$dst,$city,$state);
}

sub zipcode_get_zip_fields($$)
{
    my($dbh,$zipcode) = @_;

    my($latitude,$longitude,$tz,$dst,$city,$state) =
	zipcode_get_zip($dbh,$zipcode);

    if (! defined $state)
    {
	warn "zipcode_get_zip_fields: $zipcode Not Found";
	return undef;
    }

    # remove any prefixed + signs from the strings
    $latitude =~ s/^\+//;
    $longitude =~ s/^\+//;

    # remove any leading zeros
    $latitude =~ s/^(-?)0+/$1/;
    $longitude =~ s/^(-?)0+/$1/;

    # in hebcal, negative longitudes are EAST (this is backwards)
    my $long_hebcal = $longitude * -1.0;

    my($long_deg,$long_min) = split(/\./, $long_hebcal, 2);
    my($lat_deg,$lat_min) = split(/\./, $latitude, 2);

    if (defined $long_min && $long_min ne '')
    {
	$long_min = '.' . $long_min;
    }
    else
    {
	$long_min = 0;
    }

    if (defined $lat_min && $lat_min ne '')
    {
	$lat_min = '.' . $lat_min;
    }
    else
    {
	$lat_min = 0;
    }

    $long_min = $long_min * 60;
#    $long_min *= -1 if $long_deg < 0;
    $long_min = sprintf("%.0f", $long_min);

    $lat_min = $lat_min * 60;
    $lat_min *= -1 if $lat_deg < 0;
    $lat_min = sprintf("%.0f", $lat_min);

    my(@city) = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = lc($_);
	$_ = "\u$_";		# inital cap
	$city .= $_;
    }

    if (($state eq 'HI' || $state eq 'AZ') && $dst == 1)
    {
	warn "[$city, $state, $zipcode] had DST=1 but should be 0";
	$dst = 0;
    }

    ($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state,
     $latitude,$longitude);
}

sub html_copyright2($$$)
{
    my($prefix,$break,$target) = @_;

    my($br) = $break ? '<br>' : '';
    my($tgt) = $target ? $target : '_top';

    return qq{<!--
<rdf:RDF xmlns="http://web.resource.org/cc/"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
<Work rdf:about="">
 <license rdf:resource="http://creativecommons.org/licenses/by/2.0/" />
</Work>
<License rdf:about="http://creativecommons.org/licenses/by/2.0/">
 <permits rdf:resource="http://web.resource.org/cc/Reproduction" />
 <permits rdf:resource="http://web.resource.org/cc/Distribution" />
 <requires rdf:resource="http://web.resource.org/cc/Notice" />
 <requires rdf:resource="http://web.resource.org/cc/Attribution" />
 <permits rdf:resource="http://web.resource.org/cc/DerivativeWorks" />
</License>
</rdf:RDF>
-->
<a rel="license" href="http://creativecommons.org/licenses/by/2.0/"><img
src="http://www.hebcal.com/i/somerights20.png" width="88" height="31"
alt="Creative Commons License" border="0" align="right"></a>
<a name="copyright"></a>Copyright &copy; $this_year
Michael J. Radwin. This work is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/2.0/">Creative Commons
License</a>.$br
<a target="$tgt" href="$prefix/privacy/">Privacy Policy</a> -
<a target="$tgt" href="$prefix/help/">Help</a> -
<a target="$tgt" href="$prefix/contact/">Contact</a> -
<a target="$tgt" href="$prefix/news/">News</a> -
<a target="$tgt" href="$prefix/donations/">Donate</a>};
}

sub html_copyright($$$)
{
    my($q,$break,$tgt) = @_;

    my($server_name) = $q->virtual_host();
    return html_copyright2("http://$server_name", $break, $tgt);
}

sub html_footer_lite {
    my($rcsrev,$mtime,$noclosebody) = @_;

    $rcsrev =~ s/\s*\$//g;

    my $hhmts = "Last modified:\n" . localtime($mtime);
    my $copyright = Hebcal::html_copyright2('',0,undef);
    my $str = <<EOHTML;
<hr noshade size="1">
<span class="tiny">$copyright
<br>
$hhmts
($rcsrev)
</span>
EOHTML
;

    $str .= $URCHIN;

    if ($noclosebody) {
	return $str;
    } else {
	return $str . "</body></html>\n";
    }
}

sub html_footer
{
    my($q,$rcsrev,$noclosebody) = @_;

    my($mtime) = (defined $ENV{'SCRIPT_FILENAME'}) ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    $rcsrev =~ s/\s*\$//g;

    my($hhmts) = "Software last updated:\n" . localtime($mtime);

    my $str = qq{
<hr noshade size="1"><span class="tiny">
} . html_copyright($q, 0, undef) . qq{
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.7 for UNIX</a>, Copyright &copy; 2006 Danny Sadinoff. All rights reserved.
<br>$hhmts ($rcsrev)
</span>
};

    $str .= $URCHIN;

    if ($noclosebody) {
	return $str;
    } else {
	return $str . "</body></html>\n";
    }
}

sub navbar2($$$$$)
{
    my($q,$title,$help,$parent_title,$parent_href) = @_;

    my($server_name) = $q->virtual_host();
    $server_name =~ s/^www\.//;

    my($help_html) = ($help) ? "href=\"/help/\">Help</a> - <a\n" : '';

    my($parent_html) = ($parent_title && $parent_href) ? 
	qq{<tt>-&gt;</tt>\n<a\nhref="$parent_href">$parent_title</a>\n} :
	'';

    return "\n<!--htdig_noindex-->\n" .
	"<table width=\"100%\" class=\"navbar\">" .
	"<tr><td>" .
	"<strong><a\nhref=\"/\">" . $server_name . "</a></strong>\n" .
	$parent_html .
	"<tt>-&gt;</tt>\n" .
	$title . "</td>" .
	"<td align=\"right\"><a\n" .
	$help_html .
	"href=\"/search/\">Search</a>\n" .
	"</td></tr></table>\n" .
	"<!--/htdig_noindex-->\n";
}

sub start_html($$$$$)
{
    my($q,$title,$head,$meta,$target) = @_;

    $q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		    "\t\"http://www.w3.org/TR/html4/loose.dtd");

    $meta = {} unless defined $meta;
    $head = [] unless defined $head;

    my $script_name = Hebcal::script_name($q);
    my $base = "http://" . $q->virtual_host() . $script_name;

    if ($ENV{'QUERY_STRING'} || $ENV{'REDIRECT_QUERY_STRING'})
    {
	my $qs = $ENV{'QUERY_STRING'} || $ENV{'REDIRECT_QUERY_STRING'};
	$qs =~ s/&/&amp;/g;

	$base .= "?" . $qs;
    }

    $target = '_top' unless defined $target;
    return $q->start_html
	(
	 -dir => 'ltr',
	 -lang => 'en',
	 -title => $title,
	 -target => $target,
	 -xbase => $base,
	 -head => [
		   $q->Link({-rel => 'stylesheet',
			     -href => '/style.css',
			     -type => 'text/css'}),
		   @{$head},
		   ],
	 -meta => $meta,
	 );
}

sub html_entify($)
{
    local($_) = @_;

    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/"/&quot;/g; #"#
    s/\s+/ /g;

    $_;
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

    strftime("%a, %d %b %Y %T GMT", gmtime($time));
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
	next if $_ eq 'c' || $_ eq 'H';
	$retval .= "&$_=" . $q->param($_)
	    if defined $q->param($_) && $q->param($_) ne '';
    }
    $retval .= '&nh=off'
	if !defined $q->param('nh') || $q->param('nh') eq 'off';
    $retval .= '&nx=off'
	if !defined $q->param('nx') || $q->param('nx') eq 'off';

    if (defined $q->param("lg") && $q->param("lg") ne '')
    {
	$retval .= "&lg=" . $q->param("lg");
    }

    $retval;
}

sub get_cookies($)
{
    my($q) = @_;

    my($raw) = $q->raw_cookie();
    my(%cookies) = ();
    if ($raw)
    {
	foreach (split(/[;,\s]/, $raw))
	{
	    my($key,$val) = split(/=/, $_, 2);
	    next unless $key;
	    $val = '' unless defined($val);
	    $cookies{$key} = $val;
	}
    }

    \%cookies;
}

sub process_cookie($$)
{
    my($q,$cookieval) = @_;

    $cookieval =~ s/^C=//;

    if ($cookieval eq 'opt_out') {
	return undef;
    }

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
	    $q->delete('tz');
	    $q->delete('dst');
	    if (defined $Hebcal::city_dst{$q->param('city')} &&
		$Hebcal::city_dst{$q->param('city')} eq 'israel')
	    {
		$q->param('i','on');
		$c->param('i','on');
	    }
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
    $q->param("lg",$c->param("lg"))
	if (! defined $q->param("lg") && defined $c->param("lg"));

    $c;
}

########################################################################
# EXPORT
########################################################################

sub self_url($$)
{
    my($q,$override) = @_;

    my $url = Hebcal::script_name($q);
    my $sep = "?";

    foreach my $key ($q->param())
    {
	# delete "tag" params unless explicitly specified
	next if $key eq "tag" && !exists $override->{"tag"};
	# ignore undef entries in the override hash
	next if exists $override->{$key} && !defined $override->{$key};
	my($val) = defined $override->{$key} ?
	    $override->{$key} : $q->param($key);
	$url .= "$sep$key=" . Hebcal::url_escape($val);
	$sep = ";";
    }

    foreach my $key (keys %{$override})
    {
	# ignore undef entries in the override hash
	next unless defined $override->{$key};
	unless (defined $q->param($key))
	{
	    $url .= "$sep$key=" . Hebcal::url_escape($override->{$key});
	    $sep = ";";
	}
    }

    $url;
}

sub download_href
{
    my($q,$filename,$ext) = @_;

    my $cgi;
    my $script_name = $q->script_name();
    if ($script_name =~ /(\w+\.cgi)$/)
    {
	$cgi = $1;
	$script_name =~ s,/\w+\.cgi$,/,;
    }

    my $href = $script_name;
    $href .= $cgi if $cgi;
    $href .= "/$filename.$ext?dl=1";
    foreach my $key ($q->param())
    {
	my($val) = $q->param($key);
	$href .= ";$key=" . Hebcal::url_escape($val);
    }

    $href;
}

sub download_html
{
    my($q, $filename, $events, $title) = @_;

    my($greg_year1,$greg_year2) = (0,0);
    my($numEntries) = scalar(@{$events});
    if ($numEntries > 0)
    {
	$greg_year1 = $events->[0]->[$Hebcal::EVT_IDX_YEAR];
	$greg_year2 = $events->[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];
    }

    $title = '' unless $title;

    my($s) = qq{<div class="goto" id="export"><a name="export"></a><hr>\n} .
    qq{<h2>Export $title calendar</h2>\n};

    $s .= qq{<p>By clicking the links below, you can download 
Jewish Calendar events into your desktop software.</p>};

    if ($title && defined $q->param('month') && $q->param('month') ne 'x')
    {
	my $end_day = Date::Calc::Days_in_Month($q->param('year'),
						$q->param('month'));
	my $hebdate = HebcalGPL::greg2hebrew($q->param('year'),
					  $q->param('month'),
					  $end_day);
	my $heb_year = $hebdate->{'yy'};

	$s .= "<p>Note: you may also download <a\n" .
	    "href=\"" . Hebcal::self_url($q, {'month' => 'x'})
	    . "#export\">all of " . $q->param('year') . "</a> or <a\n" .
	    "href=\"" .
	    Hebcal::self_url($q, {'yt' => 'H', 'month' => 'x', 'year' => $heb_year}) .
	    "#export\">Hebrew Year $heb_year</a> events.</p>\n";
    }

    my $ical1 = download_href($q, $filename, "ics");
    $ical1 =~ /\?(.+)$/;
    my $args = $1;
    my $ical_href = get_vcalendar_cache_fn($args) . "?" . $args;
    my $subical_href = $ical_href;
    $subical_href =~ s/\?dl=1/\?subscribe=1/g;

    $s .= "\n<h3>Outlook 2007, Outlook 2010</h3>\n<ol><li>" .
	"Internet Calendar Subscription:\n" .
	"<a class=\"download\" id=\"${filename}_ol.ics\" href=\"webcal://" .
	$q->virtual_host() . $subical_href .
	"\">Jewish Calendar $title.ics</a>\n";
    $s .= qq{<li><a href="/help/import-outlook.html#ical">How to import ICS file into Outlook</a></ol>};

    $s .= "\n<h3>Outlook 97, 98, 2000, 2002, 2003</h3>\n<ol><li>Export Outlook CSV file.\nSelect one of:\n" .
	"<ul><li>USA date format (month/day/year):\n" .
	"<a class=\"download\" id=\"${filename}_usa.csv\" href=\"" .
	download_href($q, "${filename}_usa", 'csv') .
	"\">${filename}_usa.csv</a>\n";

    $s .= "<li>European date format (day/month/year):\n" .
	"<a class=\"download\" id=\"${filename}_eur.csv\" href=\"" .
	download_href($q, "${filename}_eur", 'csv') .
	";euro=1\">${filename}_eur.csv</a></ul>\n";

    $s .= qq{<li><a href="/help/import-outlook.html#csv">How to import CSV file into Outlook</a></ol>};

    my $dst;
    if ($q->param("geo") && $q->param("geo") ne "off"
	&& $q->param("c") && $q->param("c") ne "off")
    {
	if (defined $q->param("dst") && $q->param("dst") ne "")
	{
	    $dst = $q->param("dst");
	}
	elsif ($q->param("geo") eq "city" && $q->param("city")
	       && defined $Hebcal::city_dst{$q->param("city")})
	{
	    $dst = $Hebcal::city_dst{$q->param("city")};
	}
    }

    $s .= "\n<h3>Apple iCal (and other iCalendar-enabled applications)</h3>\n<ol><li>" .
	"Subscribe to:\n" .
	"<a class=\"download\" id=\"${filename}_sub.ics\" href=\"webcal://" .
	$q->virtual_host() . $subical_href .
	"\">Jewish Calendar $title.ics</a>\n";
    $s .= qq{<li><a href="/help/import-ical.html">How to import ICS file into Apple iCal</a></ol>};
    $s .= "<p>Alternate option: <a class=\"download\" id=\"${filename}_dl.ics\"\n"
	. "href=\"$ical_href\">download</a> and then impport manually into Apple iCal.\n";

    my $gcal_subical_href = $subical_href;
    $gcal_subical_href =~ s/;/&/g;
    my $full_http_href = "http://" . $q->virtual_host() . $gcal_subical_href;
    my $gcal_href = Hebcal::url_escape($full_http_href);
    my $title_esc = Hebcal::url_escape("Hebcal $title");

    $s .= <<EOHTML;
<h3>Google Calendar</h3>
<blockquote>
<a title="Add to Google Calendar"
href="http://www.google.com/calendar/render?cid=${gcal_href}"><img
src="/i/gc_button6.gif" width="114" height="36" border="0" alt="Add to Google Calendar"></a>
</blockquote>
Alternate option:
<a class="download" id="${filename}_dl.ics"
href="${ical_href}">download</a> and then follow <a
href="http://www.google.com/support/calendar/bin/answer.py?hl=en&amp;answer=37118">Google&apos;s
import instructions</a>.
<h3>Windows Live Calendar</h3>
<blockquote>
<a title="Add to Windows Live Calendar"
href="http://calendar.live.com/calendar/calendar.aspx?rru=addsubscription&url=${gcal_href}&name=${title_esc}"><img
src="/i/wlive-150x20.png"
width="150" height="20" border="0"
alt="Add to Windows Live Calendar"></a>
</blockquote>
<h3>Yahoo! Calendar</h3>
<form id="GrabLinkForm">
<ol>
<li>Copy the entire iCal URL here:
<label for="iCalUrl"><small><input type="text" size="80" id="iCalUrl" name="iCalUrl"
onfocus="this.select();" onKeyPress="return false;"
value="${full_http_href}"></small></label>
<li>Go to your <a href="http://calendar.yahoo.com/">Yahoo! Calendar</a>,
and click the "<b>+</b>" button next to "Calendars" on the left side of the page
<li>Click <b>Subscribe to Calendar</b>
<li>Paste the web address into the "Email or iCal address" window
<li>Click <b>Next</b> at the top of the page
<li>Type a name for the calendar in the window after "Display as."
<li>Choose a color for the calendar in the "Color:" pull-down menu
<li>Click <b>Save</b> at the top of the page
</ol>
</form>
EOHTML
;

    # only offer DBA export when we know timegm() will work
    $s .= "\n<h3>Palm Desktop 4.1.4 for Windows</h3>\n";
    if ($greg_year1 > 1969 && $greg_year2 < 2038 &&
	(!defined($dst) || $dst eq "usa" || $dst eq "none"))
    {
	$s .= "<ol><li>" .
	    "Export Palm Date Book Archive:\n" .
	    "<a class=\"download\" id=\"${filename}.dba\" href=\"" .
	    download_href($q, $filename, 'dba') .
	    "\">$filename.dba</a>\n";
	$s .= qq{<li><a href="/help/import-palm.html">How to import DBA file into Palm Desktop 4.1.4</a>};
	$s .= qq{<li>Note: Palm Desktop 6.2 export is not yet supported.</ol>};
    }
    else
    {
	$s .= "<p>Sorry, the Palm Date Book Archive format is not\n"
	    . "compatible with "
	    . (($greg_year1 <= 1969 || $greg_year2 >= 2038)
	       ? "events in the Gregorian year $greg_year2"
	       : "the <b>" . $Hebcal::dst_names{$dst}
	       . "</b> Daylight Saving Time scheme")
	    . ".</p>\n";
    }

    $s .= "\n<h3>vCalendar (some older desktop applications)</h3>\n<ol><li>" .
	"Export vCalendar file:\n" .
	"<a class=\"download\" id=\"${filename}.vcs\" href=\"" .
	download_href($q, $filename, 'vcs') .
	    "\">$filename.vcs</a>\n";
    $s .= "<li>(this download option is less reliable than other choices)</ol>\n";

    $s .= "</div>\n";

    $s;
}

sub export_http_header($$)
{
    my($q,$mime) = @_;

    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;

    print $q->header(-type => "$mime; filename=\"$path_info\"",
                     -content_disposition =>
                     "attachment; filename=$path_info",
                     -last_modified => http_date($time));
}

sub get_browser_endl($)
{
    my($ua) = @_;
    my $endl;

    if ($ua && $ua =~ /^Mozilla\/[1-4]/)
    {
	if ($ua =~ /compatible/)
	{
	    $endl = "\015\012";
	}
	else
	{
	    $endl = "\012";	# netscape 4.x and below want unix LF only
	}
    }
    else
    {
	$endl = "\015\012";
    }

    $endl;
}

sub macintosh_datebook($$)
{
    my($q, $events) = @_;
    my($numEntries) = scalar(@{$events});

    export_http_header($q, 'text/tab-separated-values');

    for (my $i = 0; $i < $numEntries; $i++)
    {
	my $date = 
	    $Hebcal::MoY_long{$events->[$i]->[$Hebcal::EVT_IDX_MON] + 1} .
	    ' ' .  $events->[$i]->[$Hebcal::EVT_IDX_MDAY] . ', ' .
	    $events->[$i]->[$Hebcal::EVT_IDX_YEAR];

	my $start_time = '';
	my $end_time = '';
	my $end_date = $date;
	my $memo = '';

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	    my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];

	    $hour -= 12 if $hour > 12;
	    $start_time = sprintf("%d:%02d PM", $hour, $min);

	    $hour += 12 if $hour < 12;
	    $min += $events->[$i]->[$Hebcal::EVT_IDX_DUR];

	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $hour -= 12 if $hour > 12;
	    $end_time = sprintf("%d:%02d PM", $hour, $min);
	    $end_date = '';
	    $memo = '';
	}

	# this is BROKEN
	# general format is
	# Hanukkah<B8>December 14, 1998<B8>December 14, 1998<B8><B8><B8>Jewish Holiday<B8><9B>
	# Doc group mtg<B8>August 21, 2002<B8><B8>2:00 PM<B8>3:00 PM<B8><B8><9B>

	print STDOUT join("\t",
			  $events->[$i]->[$Hebcal::EVT_IDX_SUBJ],
			  $date, $end_date,
			  $start_time, $end_time,
			  $memo,
			  ), "\015";
    }

    1;
}

########################################################################
# export to vCalendar
########################################################################

my %VTIMEZONE =
(
"US/Eastern" =>
"BEGIN:VTIMEZONE
TZID:US/Eastern
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0500
TZOFFSETFROM:-0400
TZNAME:EST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0400
TZOFFSETFROM:-0500
TZNAME:EDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Central" =>
"BEGIN:VTIMEZONE
TZID:US/Central
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0600
TZOFFSETFROM:-0500
TZNAME:CST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0500
TZOFFSETFROM:-0600
TZNAME:CDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Mountain" =>
"BEGIN:VTIMEZONE
TZID:US/Mountain
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0700
TZOFFSETFROM:-0600
TZNAME:MST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0600
TZOFFSETFROM:-0700
TZNAME:MDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Pacific" =>
"BEGIN:VTIMEZONE
TZID:US/Pacific
X-MICROSOFT-CDO-TZID:13
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETFROM:-0700
TZOFFSETTO:-0800
TZNAME:PST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETFROM:-0800
TZOFFSETTO:-0700
TZNAME:PDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Alaska" =>
"BEGIN:VTIMEZONE
TZID:US/Alaska
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0900
TZOFFSETFROM:+0000
TZNAME:AKST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0800
TZOFFSETFROM:-0900
TZNAME:AKDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Hawaii" =>
"BEGIN:VTIMEZONE
TZID:US/Hawaii
LAST-MODIFIED:20060309T044821Z
BEGIN:DAYLIGHT
DTSTART:19330430T123000
TZOFFSETTO:-0930
TZOFFSETFROM:+0000
TZNAME:HDT
END:DAYLIGHT
BEGIN:STANDARD
DTSTART:19330521T020000
TZOFFSETTO:-1030
TZOFFSETFROM:-0930
TZNAME:HST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19420209T020000
TZOFFSETTO:-0930
TZOFFSETFROM:-1030
TZNAME:HWT
END:DAYLIGHT
BEGIN:DAYLIGHT
DTSTART:19450814T133000
TZOFFSETTO:-0930
TZOFFSETFROM:-0930
TZNAME:HPT
END:DAYLIGHT
BEGIN:STANDARD
DTSTART:19450930T020000
TZOFFSETTO:-1030
TZOFFSETFROM:-0930
TZNAME:HST
END:STANDARD
BEGIN:STANDARD
DTSTART:19470608T020000
TZOFFSETTO:-1000
TZOFFSETFROM:-1030
TZNAME:HST
END:STANDARD
END:VTIMEZONE
",
"US/Aleutian" =>
"BEGIN:VTIMEZONE
TZID:US/Aleutian
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-1000
TZOFFSETFROM:-0900
TZNAME:HAST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0900
TZOFFSETFROM:-1000
TZNAME:HADT
END:DAYLIGHT
END:VTIMEZONE
",
 );

sub get_munged_qs
{
    my($args) = @_;

    my $qs;
    if ($args) {
	$qs = $args;
    } elsif ($ENV{"REQUEST_URI"} && $ENV{"REQUEST_URI"} =~ /\?(.+)$/) {
	$qs = $1;
    } else {
	$qs = "bogus";
    }

    $qs =~ s/[&;]?(tag|set|vis|subscribe|dl)=[^&;]+//g;
    $qs =~ s/[&;]?\.(from|cgifields|s)=[^&;]+//g;
    $qs =~ s/[&;]/,/g;
    $qs =~ s/^,+//g;
    $qs =~ s/\./_/g;
    $qs =~ s/\//-/g;
    $qs =~ s/\%20/+/g;
    $qs =~ s/[\<\>\s\"\'\`\?\*\$\|\[\]\{\}\\\~]//g; # unsafe chars

    return $qs;
}

sub get_vcalendar_cache_fn
{
    my($args) = @_;

    my $qs = get_munged_qs($args);
    my $digest = Digest::MD5::md5_hex($qs);
    my $dir = substr($digest, 0, 2);
    my $fn = substr($digest, 2) . ".ics";

    return "/export/$dir/$fn";
}

sub vcalendar_write_contents
{
    my($q,$events,$tz,$state,$title,$cconfig) = @_;

    my $is_icalendar = ($q->path_info() =~ /\.ics$/) ? 1 : 0;

    if ($is_icalendar) {
	$cache = $ENV{"DOCUMENT_ROOT"} . get_vcalendar_cache_fn() . ".$$";
	my $dir = $cache;
	$dir =~ s,/[^/]+$,,;	# dirname
	unless (-d $dir) {
	    system("/bin/mkdir", "-p", $dir);
	}
	if (open(CACHE, ">$cache")) {
	    if ($^V && $^V ge v5.8.1) {
		binmode(CACHE, ":utf8");
	    }
	} else {
	    $cache = undef;
	}
	export_http_header($q, 'text/calendar; charset=UTF-8');
    } else {
	export_http_header($q, 'text/x-vCalendar');
    }

    my $endl = get_browser_endl($q->user_agent());

    my $tzid;
    $tz = 0 unless defined $tz;

    if ($is_icalendar) {
	if ($tz == -5) {
	    $tzid = 'US/Eastern';
	} elsif ($tz == -6) {
	    $tzid = 'US/Central';
	} elsif ($tz == -7) {
	    $tzid = 'US/Mountain';
	} elsif ($tz == -8) {
	    $tzid = 'US/Pacific';
	} elsif ($tz == -9) {
	    $tzid = 'US/Alaska';
	} elsif (defined $state && $state eq 'AK' && $tz == -10) {
	    $tzid = 'US/Aleutian';
	} elsif ($tz == -10) {
	    $tzid = 'US/Hawaii';
	}
    }

    my $dtstamp = strftime("%Y%m%dT%H%M%SZ", gmtime(time()));

    out_html(undef, qq{BEGIN:VCALENDAR$endl});

    if ($is_icalendar) {
	if (defined $cconfig && defined $cconfig->{"city"}) {
	    $title .= " " . $cconfig->{"city"};
	}
	out_html(undef, 
	qq{VERSION:2.0$endl},
	qq{PRODID:-//hebcal.com/NONSGML Hebcal Calendar v$VERSION//EN$endl},
	qq{CALSCALE:GREGORIAN$endl},
	qq{METHOD:PUBLISH$endl},
	qq{X-LOTUS-CHARSET:UTF-8$endl},
	qq{X-WR-CALNAME:Hebcal $title$endl});

	# include an iCal description
	if (defined $q->param("v"))
	{
	    my $desc_url = "http://" . $q->virtual_host() .
		(($q->param("v") eq "yahrzeit") ? "/yahrzeit/" : "/hebcal/");
	    my $sep = "?";
	    foreach my $key ($q->param())
	    {
		next if $key =~ /^(subscribe|download|tag)$/o;
		my $val = $q->param($key);
		$desc_url .= "$sep$key=" . Hebcal::url_escape($val);
		$sep = ";" if $sep eq "?";
	    }
	    out_html(undef, qq{X-WR-CALDESC:$desc_url$endl});
	}
    } else {
	out_html(undef, qq{VERSION:1.0$endl},
		 qq{METHOD:PUBLISH$endl});
    }

    if ($tzid) {
	out_html(undef, qq{X-WR-TIMEZONE;VALUE=TEXT:$tzid$endl});
	if (defined $VTIMEZONE{$tzid}) {
	    my $vt = $VTIMEZONE{$tzid};
	    $vt =~ s/\n/$endl/g;
	    out_html(undef, $vt);
	}
    }

    my($i);
    my($numEntries) = scalar(@{$events});
    for ($i = 0; $i < $numEntries; $i++)
    {
	my $evt = $events->[$i];

	out_html(undef, qq{BEGIN:VEVENT$endl});
	out_html(undef, qq{DTSTAMP:$dtstamp$endl});

	if ($is_icalendar) {
	    out_html(undef, qq{CATEGORIES:Holidays$endl});
#	    out_html(undef, qq{STATUS:CONFIRMED$endl});
	} else {
	    out_html(undef, qq{CATEGORIES:HOLIDAY$endl});
	}

	my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];

	my($href,$hebrew,$dummy_memo) = Hebcal::get_holiday_anchor($subj,0,$q);

	$subj =~ s/,/\\,/g;

	if ($is_icalendar) {
	    $subj = translate_subject($q,$subj,$hebrew);
	}

	out_html(undef, qq{CLASS:PUBLIC$endl}, qq{SUMMARY:$subj$endl});

	if ($is_icalendar && $href) {
	    if ($href =~ /\.html$/) {
		$href .= "?tag=ical";
	    }
	    out_html(undef, qq{URL;VALUE=URI:$href$endl});
	}

	if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0
	    && defined $cconfig
	    && defined $cconfig->{"city"})
	{
	    out_html(undef, qq{LOCATION:}, $cconfig->{"city"}, $endl);
	}
	elsif ($evt->[$Hebcal::EVT_IDX_MEMO])
 	{
	    out_html(undef, qq{DESCRIPTION:},
		     $evt->[$Hebcal::EVT_IDX_MEMO], $endl);
	}

	my($date) = sprintf("%04d%02d%02d",
			    $evt->[$Hebcal::EVT_IDX_YEAR],
			    $evt->[$Hebcal::EVT_IDX_MON] + 1,
			    $evt->[$Hebcal::EVT_IDX_MDAY],
			    );
	my($end_date) = $date;

	if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    my $hour = $evt->[$Hebcal::EVT_IDX_HOUR];
	    my $min = $evt->[$Hebcal::EVT_IDX_MIN];

	    $hour += 12 if $hour < 12;
	    $date .= sprintf("T%02d%02d00", $hour, $min);

	    $min += $evt->[$Hebcal::EVT_IDX_DUR];
	    if ($min >= 60)
	    {
		$hour++;
		$min -= 60;
	    }

	    $end_date .= sprintf("T%02d%02d00", $hour, $min);
	}
	else
	{
	    my($gy,$gm,$gd) = Date::Calc::Add_Delta_Days
		($evt->[$Hebcal::EVT_IDX_YEAR],
		 $evt->[$Hebcal::EVT_IDX_MON] + 1,
		 $evt->[$Hebcal::EVT_IDX_MDAY],
		 1);
	    $end_date = sprintf("%04d%02d%02d", $gy, $gm, $gd);

	    # for vCalendar Palm Desktop and Outlook 2000 seem to
	    # want midnight to midnight for all-day events.
	    # Midnight to 23:59:59 doesn't seem to work as expected.
	    if (!$is_icalendar)
	    {
		$date .= "T000000";
		$end_date .= "T000000";
	    }
	}

	out_html(undef, qq{DTSTART});
	if ($is_icalendar) {
	    if ($evt->[$Hebcal::EVT_IDX_UNTIMED]) {
		out_html(undef, ";VALUE=DATE");
	    } elsif ($tzid) {
		out_html(undef, ";TZID=$tzid");
	    }
	}
	out_html(undef, qq{:$date$endl});

	if ($is_icalendar && $evt->[$Hebcal::EVT_IDX_UNTIMED])
	{
	    # avoid using DTEND since Apple iCal and Lotus Notes
	    # seem to interpret all-day events differently
	    out_html(undef, qq{DURATION:P1D$endl});
	}
	else
	{
	    out_html(undef, qq{DTEND});
	    out_html(undef, ";TZID=$tzid") if $tzid;
	    out_html(undef, qq{:$end_date$endl});
        }
	
	if ($is_icalendar) {
	    if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0 ||
		$evt->[$Hebcal::EVT_IDX_YOMTOV] == 1) {
		out_html(undef, "TRANSP:OPAQUE$endl"); # show as busy
	    } else {
		out_html(undef, "TRANSP:TRANSPARENT$endl"); # show as free
	    }

	    my $date_copy = $date;
	    $date_copy =~ s/T\d+$//;

	    my $digest = Digest::MD5::md5_hex($evt->[$Hebcal::EVT_IDX_SUBJ]);
	    my $uid = "hebcal-$date_copy-$digest";

	    if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0
		&& defined $cconfig) {
		my $loc;
		if (defined $cconfig->{"zip"}) {
		    $loc = $cconfig->{"zip"};
		} elsif (defined $cconfig->{"city"}) {
		    $loc = lc($cconfig->{"city"});
		    $loc =~ s/[^\w]/-/g;
		    $loc =~ s/-+/-/g;
		    $loc =~ s/-$//g;
		} elsif (defined $cconfig->{"long_deg"}
			 && defined $cconfig->{"long_min"}
			 && defined $cconfig->{"lat_deg"}
			 && defined $cconfig->{"lat_min"}) {
		    $loc = join("-", "pos",
				$cconfig->{"long_deg"},
				$cconfig->{"long_min"},
				$cconfig->{"lat_deg"},
				$cconfig->{"lat_min"});
		}

		if ($loc) {
		    $uid .= "-" . $loc;
		}
	    }

	    out_html(undef, qq{UID:$uid$endl});
#	    out_html(undef, qq{ORGANIZER:mailto:nobody\@hebcal.com$endl});

	    my $alarm;
	    if ($evt->[$Hebcal::EVT_IDX_SUBJ] =~ /^(\d+)\w+ day of the Omer$/) {
		$alarm = "3H";	# 9pm Omer alarm evening before
	    }
	    elsif ($evt->[$Hebcal::EVT_IDX_SUBJ] =~ /^Yizkor \(.+\)$/ ||
		   $evt->[$Hebcal::EVT_IDX_SUBJ] =~
		   /\'s (Hebrew Anniversary|Hebrew Birthday|Yahrzeit)/) {
		$alarm = "12H";	# noon the day before
	    }
	    elsif ($evt->[$Hebcal::EVT_IDX_SUBJ] eq 'Candle lighting') {
		$alarm = "10M";	# ten minutes
	    }

	    if (defined $alarm) {
		out_html(undef, "BEGIN:VALARM${endl}",
			 "X-WR-ALARMUID:${uid}-alarm${endl}",
			 "ACTION:AUDIO${endl}",
			 "TRIGGER:-PT${alarm}${endl}",
			 "END:VALARM${endl}");
	    }
	}

	out_html(undef, qq{END:VEVENT$endl});
    }

    out_html(undef, qq{END:VCALENDAR$endl});

    cache_end();
    1;
}

sub translate_subject
{
    my($q,$subj,$hebrew) = @_;

    my $lang = $q->param("lg") || "s";
    if ($lang eq "s" || $lang eq "a" || !$hebrew) {
	return $subj;
    } elsif ($lang eq "h") {
	return $hebrew;
    } elsif ($lang eq "ah" || $lang eq "sh") {
	return "$subj / $hebrew";
    } else {
	die "unknown lang \"$lang\" for $subj";
    }
}

########################################################################
# export to Outlook CSV
########################################################################

sub csv_write_contents($$$)
{
    my($q,$events,$euro) = @_;
    my($numEntries) = scalar(@{$events});

    export_http_header($q, 'text/x-csv');
    my $endl = get_browser_endl($q->user_agent());

    print STDOUT
	qq{"Subject","Start Date","Start Time","End Date",},
	qq{"End Time","All day event","Description","Show time as",},
	qq{"Location"$endl};

    my($i);
    for ($i = 0; $i < $numEntries; $i++)
    {
	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($memo) = $events->[$i]->[$Hebcal::EVT_IDX_MEMO];

	my $date;
	if ($euro) {
	    $date = sprintf("\"%d/%d/%04d\"",
			    $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			    $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1,
			    $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);
	} else {
	    $date = sprintf("\"%d/%d/%04d\"",
			    $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1,
			    $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
			    $events->[$i]->[$Hebcal::EVT_IDX_YEAR]);
	}

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

	my $loc = 'Jewish Holidays';
	if ($memo =~ /^in (.+)\s*$/)
	{
	    $memo = '';
	    $loc = $1;
	}

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

	print STDOUT qq{,"$loc"$endl};
    }

    1;
}

########################################################################
# for managing email shabbat list
########################################################################

my $SENDMAIL_PASS;

sub sendmail_v2($$$)
{
    my($return_path,$headers,$body,$verbose) = @_;

    eval("use Email::Valid");
    eval("use Net::SMTP");
    
    if (! Email::Valid->address($return_path))
    {
	warn "Hebcal.pm: Return-Path $return_path is invalid"
	    if $verbose;
	return 0;
    }

    my($from) = $headers->{'From'};
    if (!$from || ! Email::Valid->address($from))
    {
	warn "Hebcal.pm: From $from is invalid"
	    if $verbose;
	return 0;
    }

    my(%recipients);
    foreach my $hdr ('To', 'Cc', 'Bcc')
    {
	if (defined $headers->{$hdr})
	{
	    foreach my $addr (split(/\s*,\s*/, $headers->{$hdr}))
	    {
		next unless $addr;
		next unless Email::Valid->address($addr);
		$recipients{Email::Valid->address($addr)} = 1;
	    }
	}
    }

    if (! keys %recipients)
    {
	warn "Hebcal.pm: no recipients!"
	    if $verbose;
	return 0;
    }

    my($smtp) = Net::SMTP->new('mail.hebcal.com', Timeout => 20);
    unless ($smtp) {
        return 0;
    }

    unless ($SENDMAIL_PASS) {
	if (open(PASSFILE, $EMAIL_PASSFILE)) {
	    $SENDMAIL_PASS = <PASSFILE>;
	    chop $SENDMAIL_PASS;
	    close(PASSFILE);
	}
    }

    $smtp->auth("hebcal", $SENDMAIL_PASS);

    my $message = '';
    while (my($key,$val) = each %{$headers})
    {
	next if lc($key) eq 'bcc';
	while (chomp($val)) {}
	$message .= "$key: $val\n";
    }

    if (!$HOSTNAME) {
	$HOSTNAME = `/bin/hostname -f`;
	chomp($HOSTNAME);
    }

    if (! defined $headers->{'X-Sender'})
    {
	my($login) = getlogin() || getpwuid($<) || "UNKNOWN";
	$message .= "X-Sender: $login\@$HOSTNAME\n";
    }

    if (! defined $headers->{'X-Mailer'})
    {
	$message .= "X-Mailer: hebcal mail v$VERSION\n";
    }

    if (! defined $headers->{'Message-ID'})
    {
	$message .= "Message-ID: <HEBCAL.$VERSION." . time() .
	    ".$$\@$HOSTNAME>\n";
    }

    $message .= "\n" . $body;

    my @recip = keys %recipients;

    $smtp->hello($HOSTNAME);
    unless ($smtp->mail($return_path)) {
        warn "smtp mail() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    foreach (@recip) {
	next unless $_;
        unless($smtp->to($_)) {
            warn "smtp to() failure for $_\n"
		if $verbose;
            return 0;
        }
    }
    unless($smtp->data()) {
        warn "smtp data() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    unless($smtp->datasend($message)) {
        warn "smtp datasend() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    unless($smtp->dataend()) {
        warn "smtp dataend() failure for @recip\n"
	    if $verbose;
        return 0;
    }
    unless($smtp->quit) {
        warn "smtp quit failure for @recip\n"
	    if $verbose;
        return 0;
    }

    1;
}

# avoid warnings
if ($^W && 0)
{
    $_ = $Hebcal::tz_names{'foo'};
    $_ = $Hebcal::city_tz{'foo'};
    $_ = $Hebcal::city_dst{'foo'};
    $_ = $Hebcal::MoY_long{'foo'};
    $_ = $Hebcal::ashk2seph{'foo'};
}

1;
