<?php
/***********************************************************************
 * Hebcal homepage
 *
 * Copyright (c) 2013  Michael J. Radwin.
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

if (isset($_COOKIE["C"])) {
    header("Cache-Control: private");
    parse_str($_COOKIE["C"], $param);
}

require("./pear/Hebcal/common.inc");

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
$purim_month_num = is_leap_year($hy) ? 7 : 6;
if ($hmnum == 13 && $hd >= 1) {
    $shana_tova = true;		// month 13 == Elul
    $erev_rh = format_greg_date_for_erev(13, 29, $hy);
} elseif ($hmnum == 1 && $hd <= 10) {
    // month 1 == Tishrei. Gmar Tov!
    $erev_yk = format_greg_date_for_erev(1, 9, $hy);
} elseif ($hmnum == $purim_month_num && $hd >= 2 && $hd <= 13) {
    // for two weeks before Purim, show greeting
    $erev_purim = format_greg_date_for_erev($purim_month_num, 13, $hy);
} elseif (($hmnum == $purim_month_num && $hd >= 24) || ($hmnum == 8 && $hd <= 14)) {
    // for three weeks before Pesach, show greeting
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
ul.inline li:after{content:"\\00a0\\00b7"}
ul.inline li:last-child:after{content:""}
</style>
EOD;
echo html_header_bootstrap("Jewish Calendar, Hebrew Date Converter, Holidays - hebcal.com",
		     $xtra_head,
		     false);
?>
<div class="span12">
<div class="clearfix">
<h1 class="hidden-phone">Hebcal Jewish Calendar</h1>
<ul class="inline">
<?php
echo "<li><time datetime=\"", date("Y-m-d"), "\">", date("D, j F Y"), "</time>\n";
$hm = $hnum_to_str[$hmnum];
echo "<li>", format_hebrew_date($hd, $hm, $hy), "\n";

// holidays today
if (isset($events)) {
    foreach ($events as $h) {
	if (strncmp($h, "Parashat ", 9) != 0) {
	    $anchor = hebcal_make_anchor($h);
	    echo "<li><a href=\"", $anchor, "\">", $h, "</a>\n";
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
	    echo "<li><a href=\"", $anchor, "\">", $h, "</a>\n";
	}
    }
}

function holiday_greeting($blurb, $long_text) { ?>
<div class="row-fluid">
<div class="span8">
<div class="alert alert-success">
 <strong><?php echo $blurb ?>!</strong>
 <?php echo $long_text ?>.
</div><!-- .alert -->
</div><!-- .span8 -->
</div><!-- .row-fluid -->
<?php
}

?></ul>
<p class="lead">Free Jewish holiday calendars, Hebrew date converters and Shabbat times.</p>
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
?>
</div><!-- .clearfix -->

<div class="row-fluid">
<div class="span6">
<h2><img style="vertical-align:middle" src="/i/glyphicons_pro_1.7/glyphicons/png/glyphicons_045_calendar.png" width="23" height="24" alt="">
Holiday Calendar</h2>
<p>Holidays, candle lighting times, and Torah readings for any year 0001-9999.
Download to Outlook, iPhone, Google Calendar, and more.</p>
<?php
  if (($hmnum == 12 && $hd >= 15) || ($hmnum == 13)) {
      // it's past the 15th of Av (12th month) or Elul (13th month)
      $hebyear = $hy + 1;
  } else {
      $hebyear = $hy;
  }
  $greg_yr1 = $hebyear - 3761;
  $greg_yr2 = $greg_yr1 + 1;
  $greg_range = $greg_yr1 . "-" . $greg_yr2;
?>
<p><a class="btn" href="/holidays/<?php echo $greg_range ?>"><i class="icon-calendar"></i> <?php echo $greg_range ?> Holidays &raquo;</a></p>
<p><a class="btn" title="Hebcal Custom Calendar" href="/hebcal/"><i class="icon-pencil"></i> Customize your calendar &raquo;</a></p>
</div><!-- .span6 -->

<div class="span6">
<h2><img style="vertical-align:middle" src="/i/glyphicons_pro_1.7/glyphicons/png/glyphicons_081_refresh.png" width="25" height="26" alt="">
Convert Dates</h2>
<p>Convert between Hebrew and Gregorian dates and see today&apos;s date in a Hebrew font.</p>
<p><a class="btn" href="/converter/"><i class="icon-refresh"></i> Date Converter &raquo;</a></p>
<p>Generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries.</p>
<p><a class="btn" href="/yahrzeit/"><i class="icon-user"></i> Yahrzeit + Anniversary Calendar &raquo;</a></p>
</div><!-- .span6 -->
</div><!-- .row-fluid -->

<div class="row-fluid">
<div class="span6">
<h2><img style="vertical-align:middle" src="/i/glyphicons_pro_1.7/glyphicons/png/glyphicons_334_candle.png" width="20" height="25" alt="">
Shabbat Times</h2>
<p>Candle-lighting and Havdalah times. Weekly Torah portion.</p>
<form action="/shabbat/" method="get" class="form form-inline">
<input type="hidden" name="geo" value="zip">
<label>ZIP code:
<input type="text" name="zip" size="5" maxlength="5" class="input-mini"
<?php if (isset($param["zip"])) { echo "value=\"$param[zip]\" "; } ?>
pattern="\d*" id="zip"></label>
<input type="hidden" name="m" value="<?php
  if (isset($param["m"])) { echo $param["m"]; } else { echo "50"; } ?>">
<button type="submit" class="btn"><i class="icon-time"></i> Shabbat Times &raquo;</button>
</form>
<?php if (isset($param["zip"]) || isset($param["city"])) { ?>
<p><a class="btn" href="/shabbat/fridge.cgi?<?php
  echo isset($param["zip"]) ? "zip=$param[zip]" : "city=$param[city]" ?>&amp;year=<?php
  echo $hebyear ?>"><i class="icon-print"></i> Print times for <?php echo $hebyear ?> &raquo;</a></p>
<?php } else { ?>
<p><a class="btn" href="/home/shabbat/fridge"><i class="icon-print"></i> Print times for <?php echo $hebyear ?> &raquo;</a></p>
<?php } ?>
</div><!-- .span6 -->

<div class="span6">
<h2><img style="vertical-align:middle" src="/i/glyphicons_pro_1.7/glyphicons/png/glyphicons_351_book_open.png" width="24" height="22" alt="">
Torah Readings</h2>
<p>An aliyah-by-aliyah breakdown. Full kriyah and triennial system.</p>
<p><a class="btn" href="/sedrot/"><i class="icon-book"></i> Torah Readings &raquo;</a></p>
</div><!-- .span6 -->
</div><!-- .row-fluid -->

</div><!-- .span12 -->

<?php
echo html_footer_bootstrap();
?>

