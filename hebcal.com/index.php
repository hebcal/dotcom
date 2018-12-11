<?php
/***********************************************************************
 * Hebcal homepage
 *
 * Copyright (c) 2018  Michael J. Radwin.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 *  * Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **********************************************************************/

require("./pear/Hebcal/common.inc");

if (isset($_COOKIE["C"])) {
    header("Cache-Control: private");
//    parse_str($_COOKIE["C"], $param);
}

$in_israel = false;
if (isset($_SERVER['MM_COUNTRY_CODE']) && $_SERVER['MM_COUNTRY_CODE'] == 'IL') {
    date_default_timezone_set('Asia/Jerusalem');
    $in_israel = true;
}

// Determine today's holidays (if any)
if (isset($_GET["gm"]) && isset($_GET["gd"]) && isset($_GET["gy"])) {
    $gm = $_GET["gm"];
    $gd = $_GET["gd"];
    $gy = $_GET["gy"];
} else {
    list($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
    $gm = $mon + 1;
    $gd = $mday;
    $gy = $year + 1900;
}
$century = substr($gy, 0, 2);
$fn = $_SERVER["DOCUMENT_ROOT"] . "/converter/sedra/$century/$gy.inc";
@include($fn);
$iso = sprintf("%04d%02d%02d", $gy, $gm, $gd);
if (isset($sedra) && isset($sedra[$iso])) {
    $other_holidays = array(
	"Tu BiShvat" => true,
	"Purim" => true,
	"Shushan Purim" => true,
	"Yom HaAtzma'ut" => true,
	"Lag B'Omer" => true,
        "Lag BaOmer" => true,
	"Shmini Atzeret" => true,
	"Simchat Torah" => true,
	);

    if (is_array($sedra[$iso])) {
	$events = $sedra[$iso];
    } else {
	$events = array($sedra[$iso]);
    }

    foreach ($events as $subj) {
	if (strncmp($subj, "Erev ", 5) == 0) {
	    $subj = substr($subj, 5);
	}

	if (strncmp($subj, "Rosh Chodesh ", 13) == 0) {
	    $rosh_chodesh = substr($subj, 13);
	}
	if (strncmp($subj, "Chanukah:", 9) == 0) {
	    $chanukah = true;
	}
	if (strpos($subj, "(CH''M)") !== false) {
	    $pos = strpos($subj, " ");
	    if ($pos === false) { $pos = strlen($subj); }
	    $shalosh_regalim = substr($subj, 0, $pos);
	} elseif ($subj == "Pesach Sheni") {
	    // Pesach Sheni is not a Chag Sameach
	} elseif (strncmp($subj, "Sukkot", 6) == 0
	    || strncmp($subj, "Pesach", 6) == 0
	    || strncmp($subj, "Shavuot", 7) == 0) {
	    $pos = strpos($subj, " ");
	    if ($pos === false) { $pos = strlen($subj); }
	    $chag_sameach = substr($subj, 0, $pos);
	}
	if (strncmp($subj, "Rosh Hashana", 12) == 0) {
	    $shana_tova = true;
	}
	if (strncmp($subj, "Tzom", 4) == 0
	    || strncmp($subj, "Asara", 5) == 0
	    || strncmp($subj, "Ta'anit", 7) == 0
	    || $subj == "Tish'a B'Av") {
	    $fast_day = true;
	}
	if (isset($other_holidays[$subj])) {
	    $chag_sameach = $subj;
	}
    }
}

function format_greg_date_for_erev($hmonth, $hday, $hyear) {
    $jd = jewishtojd($hmonth, $hday, $hyear);
    $greg_cal = cal_from_jd($jd, CAL_GREGORIAN);
    return sprintf("%s, %s %s %s",
		   $greg_cal["abbrevdayname"],
		   $greg_cal["day"],
		   $greg_cal["monthname"],
		   $greg_cal["year"]);
}

// Yamim Nora'im
$jd = gregoriantojd($gm, $gd, $gy);
$hebdate = jdtojewish($jd);
list($hmnum, $hd, $hy) = explode("/", $hebdate, 3);
// With PHP 5.5, the functionality changed regarding Adar in a non-leap year.
// Prior to 5.5, the month was returned as 6.
// In 5.5 and 5.6, the month is returned as 7.
$purim_month_num = 7;
if ($hmnum == 13 && $hd >= 1) {
    $shana_tova = true;		// month 13 == Elul
    $erev_rh = format_greg_date_for_erev(13, 29, $hy);
} elseif ($hmnum == 1 && $hd <= 10) {
    // month 1 == Tishrei. Gmar Tov!
    $erev_yk = format_greg_date_for_erev(1, 9, $hy);
} elseif ($hmnum == $purim_month_num && $hd >= 2 && $hd <= 13) {
    // for two weeks before Purim, show greeting
    $erev_purim = format_greg_date_for_erev($purim_month_num, 13, $hy);
} elseif (($hmnum == $purim_month_num && $hd >= 17) || ($hmnum == 8 && $hd <= 14)) {
    // for four weeks before Pesach, show greeting
    $erev_pesach = format_greg_date_for_erev(8, 14, $hy);
} elseif ($hmnum == 3 && $hd >= 3 && $hd <= 24) {
    // for three weeks before Chanukah, show greeting
    $chanukah_jd = jewishtojd(3, 24, $hy); // month 3 == Kislev
    $chanukah_cal = cal_from_jd($chanukah_jd, CAL_GREGORIAN);
    $chanukah_when = "at sundown";
    $chanukah_dayname = $chanukah_cal["abbrevdayname"];
    if ($chanukah_dayname == "Fri") {
	$chanukah_when = "before sundown";
    } elseif ($chanukah_dayname == "Sat") {
	$chanukah_when = "at nightfall";
    }
    $chanukah_upcoming = sprintf("%s on %s, %s %s %s",
		$chanukah_when,
		$chanukah_dayname,
		$chanukah_cal["day"],
		$chanukah_cal["monthname"],
		$chanukah_cal["year"]);
}
$xtra_head = <<<EOD
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,sedrot,Sadinoff,Yahrzeit,calender">
<meta name="author" content="Michael J. Radwin">
<style type="text/css">
ul.list-inline li:after{content:"\\00a0\\00b7"}
ul.list-inline li:last-child:after{content:""}
.h1, .h2, .h3, h1, h2, h3 {
  font-family: 'Merriweather', serif;
  font-weight: 400;
}
.icon-block {
  display: block;
  width: 90px;
  height: 90px;
  margin-right: auto;
  margin-top: 12px;
  margin-bottom: 6px;
  margin-left: auto;
  padding: 20px;
  border: 3px solid #e4ebeb;
  border-radius: 200px;
}
a.icon-block {
  color: #666;
  text-decoration: none;
}
.masthead {
  text-align: center;
}
.first-row {
  padding-top: 40px;
}
.pad-bot {
  padding-bottom: 32px;
}
.icon-lg {
  font-size:44px;
}
</style>
<link rel="dns-prefetch" href="https://pagead2.googlesyndication.com">
<link href='https://fonts.googleapis.com/css?family=Merriweather' rel='stylesheet' type='text/css'>
EOD;
$header = html_header_bootstrap3("Jewish Calendar, Hebrew Date Converter, Holidays - hebcal.com",
		     $xtra_head,
		     false);
$header = preg_replace('/<!-- \.navbar -->.+/s', '<!-- .navbar -->', $header);
echo $header;
?>
<div class="masthead" tabindex="-1">
<div class="container">
<ul class="list-inline">
<?php
echo "<li class=\"list-inline-item\"><time datetime=\"", date("Y-m-d"), "\">", date("D, j F Y"), "</time>\n";
$hm = $hnum_to_str[$hmnum];
echo "<li class=\"list-inline-item\">", format_hebrew_date($hd, $hm, $hy), "\n";

// holidays today
if (isset($events)) {
    foreach ($events as $h) {
	if (strncmp($h, "Parashat ", 9) != 0) {
	    $anchor = hebcal_make_anchor($h);
	    echo "<li class=\"list-inline-item\"><a href=\"", $anchor, "\">", $h, "</a>\n";
	}
    }
}

// parashah hashavuah
list($saturday_gy,$saturday_gm,$saturday_gd) = get_saturday($gy, $gm, $gd);
$saturday_iso = sprintf("%04d%02d%02d", $saturday_gy, $saturday_gm, $saturday_gd);
if (isset($sedra) && isset($sedra[$saturday_iso])) {
    if (is_array($sedra[$saturday_iso])) {
	$sat_events = $sedra[$saturday_iso];
    } else {
	$sat_events = array($sedra[$saturday_iso]);
    }
    foreach ($sat_events as $h) {
	if (strncmp($h, "Parashat ", 9) == 0) {
	    $anchor = hebcal_make_anchor($h);
	    echo "<li class=\"list-inline-item\"><a href=\"", $anchor, "\">", $h, "</a>\n";
	}
    }
}

function holiday_greeting($blurb, $long_text) { ?>
<div class="row">
<div class="col-sm-8 offset-sm-2">
<div class="alert alert-success">
 <strong><?php echo $blurb ?>!</strong>
 <?php echo $long_text ?>.
</div><!-- .alert -->
</div><!-- .col-sm-8 -->
</div><!-- .row -->
<?php
}

?></ul>
<h1>Jewish holiday calendars &amp; Hebrew date converter</h1>
<?php
if (isset($rosh_chodesh)) {
    $anchor = hebcal_make_anchor("Rosh Chodesh $rosh_chodesh");
    holiday_greeting("Chodesh Tov", "We wish you a good new month of <a href=\"$anchor\">$rosh_chodesh</a>");
} elseif (isset($chanukah)) {
    holiday_greeting("Chag Urim Sameach",
		     "We wish you a happy <a href=\"/holidays/chanukah\">Chanukah</a>");
} elseif (isset($chanukah_upcoming)) {
    holiday_greeting("Happy Chanukah",
		     "Light the <a title=\"Chanukah, the Festival of Lights\" href=\"/holidays/chanukah\">first candle</a> $chanukah_upcoming");
} elseif (isset($shalosh_regalim)) {
    $anchor = hebcal_make_anchor($shalosh_regalim);
    holiday_greeting("Moadim L&#39;Simcha", "We wish you a happy <a href=\"$anchor\">$shalosh_regalim</a>");
} elseif (isset($shana_tova)) {
    $rh_greeting = "We wish you a happy and healthy New Year";
    if (isset($erev_rh)) {
	$next_hy = $hy + 1;
	$rh_greeting .= ".<br><a href=\"/holidays/rosh-hashana\">Rosh Hashana $next_hy</a> begins at sundown on $erev_rh";
    }
    holiday_greeting("Shanah Tovah", $rh_greeting);
} elseif (isset($erev_yk)) {
    holiday_greeting("G&#39;mar Chatimah Tovah",
		     "We wish you a good inscription in the Book of Life.<br><a href=\"/holidays/yom-kippur\">Yom Kippur</a> begins at sundown on $erev_yk");
} elseif (isset($erev_pesach)) {
     holiday_greeting("Chag Kasher v&#39;Sameach",
		      "We wish you a happy <a href=\"/holidays/pesach\">Passover</a>.<br>Pesach begins at sundown on $erev_pesach");
} elseif (isset($erev_purim)) {
     holiday_greeting("Chag Sameach",
		      "We wish you a happy <a href=\"/holidays/purim\">Purim</a> (begins at sundown on $erev_purim)");
} elseif (isset($chag_sameach)) {
    $anchor = hebcal_make_anchor($chag_sameach);
    holiday_greeting("Chag Sameach", "We wish you a happy <a href=\"$anchor\">$chag_sameach</a>");
} elseif (isset($fast_day)) {
     holiday_greeting("Tzom Kal", "We wish you an easy fast");
}

if (($hmnum == 12 && $hd >= 10) || ($hmnum == 13)) {
    // it's past the Tish'a B'Av (12th month) or anytime in Elul (13th month)
    $hebyear = $hy + 1;
} else {
    $hebyear = $hy;
}
$greg_yr1 = $hebyear - 3761;
$greg_yr2 = $greg_yr1 + 1;
$greg_range = $greg_yr1 . "-" . $greg_yr2;
$year_get_args = "&amp;yt=H&amp;year=$hebyear&amp;month=x";

// for the first 7 months of the year, just show the current Gregorian year
if ($gm < 8) {
    $year_get_args = "&amp;yt=G&amp;year=$gy&amp;month=x";
    $greg_range = $gy;
}
?>
</div><!-- .container -->
</div><!-- .masthead -->
<div class="container">
<div id="content" class="first-row">
<div class="row">
<div class="col-sm-8">
<p class="lead">Holidays, candle lighting times, and Torah readings for
<a href="/holidays/<?php echo $greg_range ?>"><?php echo $greg_range ?></a>
and any year, past or present.
Download to Outlook, iPhone, Google Calendar, and more.</p>
</div>
<div class="col-sm-4 text-center pad-bot">
<p><a class="btn btn-primary btn-lg" title="Hebcal Custom Calendar" href="/hebcal/?v=1&amp;maj=on&amp;min=on&amp;i=<?php echo $in_israel ? "on" : "off"; ?>&amp;lg=s&amp;c=off&amp;set=off<?php echo $year_get_args ?>"><i class="glyphicons glyphicons-calendar"></i> Get calendar</a>
<br><small><a href="/hebcal/">Customize calendar settings</a></small></p>
</div>
</div><!-- .row -->
<div class="row">
<div class="col-sm-8">
<p class="lead">Convert between Hebrew and Gregorian dates and see today&apos;s date in a Hebrew font.</p>
</div>
<div class="col-sm-4 text-center pad-bot">
<p><a class="btn btn-secondary btn-lg" href="/converter/"><i class="glyphicons glyphicons-refresh"></i> Date Converter</a></p>
</div>
</div><!-- .row -->

<div class="row">
<div class="col-sm-4">
<a class="icon-block" href="/shabbat/">
 <span class="glyphicons glyphicons-candle icon-lg"></span>
</a>
<h3 class="text-center">Candle lighting</h3>
<p>Shabbat and holiday candle-lighting and Havdalah times for over 50,000 world cities.
<br><a href="/shabbat/?geonameid=281184">Jerusalem</a> &middot;
<a href="/shabbat/?geonameid=5128581">New York</a> &middot;
<a href="/shabbat/?geonameid=2643743">London</a> &middot;
<a href="/shabbat/browse/">more...</a></p>
</div><!-- .col-sm-4 -->

<div class="col-sm-4">
<a class="icon-block" href="/yahrzeit/">
 <span class="glyphicons glyphicons-parents icon-lg"></span>
</a>
<h3 class="text-center">Yahrzeits and Birthdays</h3>
<p>Generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries for the next 20 years.
<br><a href="/yahrzeit/">Get started &raquo;</a></p>
</div><!-- .col-sm-4 -->

<div class="col-sm-4">
<a class="icon-block" href="/sedrot/">
 <span class="glyphicons glyphicons-book_open icon-lg"></span>
</a>
<h3 class="text-center">Torah readings</h3>
<p>An aliyah-by-aliyah breakdown. Full kriyah and triennial system.
<br><a href="/sedrot/">See more &raquo;</a></p>
</div><!-- .col-sm-4 -->
</div><!-- .row -->

<div class="row">
<div class="col-sm-4">
<a class="icon-block" href="/holidays/">
 <span class="glyphicons glyphicons-calendar icon-lg"></span>
</a>
<h3 class="text-center">Holidays</h3>
<p>Major, minor &amp; modern holidays, Rosh Chodesh, minor fasts, special Shabbatot.
<br><a href="/holidays/">Get started &raquo;</a></p>
</div><!-- .col-sm-4 -->

<div class="col-sm-4">
<a class="icon-block" href="/ical/">
 <span class="glyphicons glyphicons-download-alt icon-lg"></span>
</a>
<h3 class="text-center">Download</h3>
<p>Download Jewish holidays and Hebrew dates for Microsoft Outlook, iPhone, iPad, Mac OS X Desktop Calendar, Android (via Google Calendar), or to any desktop program that supports iCalendar (.ics) files
<br><a href="/ical/">Get started &raquo;</a></p>
</div><!-- .col-sm-4 -->

<div class="col-sm-4">
<a class="icon-block" href="https://www.hebcal.com/email/">
 <span class="glyphicons glyphicons-envelope icon-lg"></span>
</a>
<h3 class="text-center">Email</h3>
<p>Subscribe to weekly Shabbat candle lighting times and Torah portion by email.
<br><a href="https://www.hebcal.com/email/">Sign up &raquo;</a></p>
</div><!-- .col-sm-4 -->
</div><!-- .row -->


<div class="row" style="margin-top:40px">
<div class="col-sm-2">
<a class="icon-block" href="/home/developer-apis">
 <span class="glyphicons glyphicons-embed-close icon-lg"></span>
</a>
</div><!-- .col-sm-2 -->
<div class="col-sm-10">
<h3>Developer APIs</h3>
<p>We're part of the Open Source Judaism movement. Embed Hebcal.com content directly onto your synagogue website with our JavaScript, JSON and RSS APIs, available under a Creative Commons Attribution 3.0 License. <a href="/home/developer-apis">Learn more &raquo;</a></p>
</div><!-- .col-sm-10 -->

</div><!-- .row -->

<?php
$js_typeahead_url = hebcal_js_typeahead_bundle_url();
$xtra_html = <<<EOD
<script src="$js_typeahead_url"></script>
EOD;
    echo html_footer_bootstrap3(false, $xtra_html);
    exit();
?>

