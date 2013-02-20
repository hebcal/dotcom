<?php
$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)/', $VER, $matches)) {
    $VER = $matches[1];
}

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
	"Tu B'Shvat" => true, "Purim" => true, "Shushan Purim" => true,
	"Yom HaAtzma'ut" => true, "Lag B'Omer" => true,
	"Shmini Atzeret" => true, "Simchat Torah" => true,
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
	    || strncmp($subj, "Ta'anit", 7) == 0) {
	    $minor_fast = true;
	}
	if (isset($other_holidays[$subj])) {
	    $chag_sameach = $subj;
	}
    }
}

// Yamim Nora'im
$jd = gregoriantojd($gm, $gd, $gy);
$hebdate = jdtojewish($jd);
list($hmnum, $hd, $hy) = explode("/", $hebdate, 3);
$purim_month_num = is_leap_year($hy) ? 7 : 6;
if ($hmnum == 13 && $hd >= 1) {
    $shana_tova = true;		// month 13 == Elul
    $rh_jd = jewishtojd(13, 29, $hy);
    $rh_cal = cal_from_jd($rh_jd, CAL_GREGORIAN);
    $erev_rh = sprintf("%s, %s %s %s",
		       $rh_cal["abbrevdayname"],
		       $rh_cal["day"],
		       $rh_cal["monthname"],
		       $rh_cal["year"]);
} elseif ($hmnum == 1 && $hd <= 10) {
    $gmar_tov = true;		// month 1 == Tishrei
    $rh_jd = jewishtojd(1, 9, $hy);
    $rh_cal = cal_from_jd($rh_jd, CAL_GREGORIAN);
    $erev_yk = sprintf("%s, %s %s %s",
		       $rh_cal["abbrevdayname"],
		       $rh_cal["day"],
		       $rh_cal["monthname"],
		       $rh_cal["year"]);
} elseif ($hmnum == $purim_month_num && $hd >= 2 && $hd <= 13) {
    // for two weeks before Purim, show greeting
    $purim_upcoming = true;
    $purim_jd = jewishtojd($purim_month_num, 13, $hy);
    $purim_cal = cal_from_jd($purim_jd, CAL_GREGORIAN);
    $erev_purim = sprintf("%s, %s %s %s",
		       $purim_cal["abbrevdayname"],
		       $purim_cal["day"],
		       $purim_cal["monthname"],
		       $purim_cal["year"]);
} elseif ($hmnum == 8 && $hd >= 2 && $hd <= 15) {
    // for two weeks before Pesach, show greeting
    $chag_kasher = true;	// month 8 == Nisan
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
<h1>Hebcal Jewish Calendar</h1>
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
?></ul>
<p class="lead">Free Jewish holiday calendars, Hebrew date converters and Shabbat times.</p>
<?php
if (isset($rosh_chodesh)) { ?>
<p><span class="label label-success">Chodesh Tov</span>
<span class="text-success">We wish you a good new month of <?php echo $rosh_chodesh ?>.</span></p>
<?php } elseif ($chanukah) { ?>
<p><span class="label label-success">Chag Urim Sameach</span>
<span class="text-success">We wish you a happy Chanukah.</span></p>
<?php } elseif (isset($chanukah_upcoming)) { ?>
<p><span class="label label-success">Happy Chanukah</span>
<span class="text-success">Light the <a
title="Chanukah, the Festival of Lights"
href="/holidays/chanukah">first candle</a>
<?php echo $chanukah_upcoming ?>.</span></p>
<?php } elseif (isset($shalosh_regalim)) { ?>
<p><span class="fpgreeting">Moadim L&#39;Simcha! We wish you
a happy <?php echo $shalosh_regalim ?>.</span></p>
<?php } elseif ($shana_tova) { ?>
<p><span class="label label-success">Shanah Tovah</span>
<span class="text-success">We wish you a happy and healthy New Year.</span>
<?php     if (isset($erev_rh)) { ?>
<br><span class="text-success"><a href="/holidays/rosh-hashana">Rosh
Hashana <?php echo $hy + 1 ?></a> begins at sundown
on <?php echo $erev_rh ?>.</span>
<?php     } ?>
</p>
<?php } elseif ($gmar_tov) { ?>
<p><span class="label label-success">G&#39;mar Chatimah Tovah</span>
<span class="text-success">We wish you a good inscription in the Book of Life.</span>
<?php     if (isset($erev_yk)) { ?>
<br><span class="text-success"><a href="/holidays/yom-kippur">Yom
Kippur</a> begins at sundown
on <?php echo $erev_yk ?>.</span>
<?php     } ?>
</p>
<?php } elseif ($chag_kasher) { ?>
<p><span class="label label-success">Chag Kasher v&#39;Sameach</span>
<span class="text-success">We wish you a happy <a
href="/holidays/pesach">Passover</a>.</span></p>
<?php } elseif (isset($purim_upcoming)) { ?>
<p><span class="label label-success">Chag Sameach</span>
<span class="text-success">We wish you a happy <a href="/holidays/purim">Purim</a>
(begins at sundown on <?php echo $erev_purim ?>).</span></p>
<?php } elseif (isset($chag_sameach)) { ?>
<p><span class="label label-success">Chag Sameach</span>
<span class="text-success">We wish you a happy <?php echo $chag_sameach ?>.</span></p>
<?php } elseif ($minor_fast) { ?>
<p><span class="label label-success">Tzom Kal</span>
<span class="text-success">We wish you an easy fast.</span></p>
<?php } ?>
</div><!-- .clearfix -->

<div class="row-fluid">
<div class="span4">
<h3>Jewish Holidays</h3>
<p>Holidays, candle lighting times, and Torah readings for any year 0001-9999.
Download to Outlook, iPhone, Google Calendar, and more.</p>
<?php
  $hebyear = ($hmnum == 13) ? $hy + 1 : $hy;
  $greg_yr1 = $hebyear - 3761;
  $greg_yr2 = $greg_yr1 + 1;
  $greg_range = $greg_yr1 . "-" . $greg_yr2;
?>
<p><a class="btn" href="/holidays/<?php echo $greg_range ?>"><i class="icon-calendar"></i> <?php echo $greg_range ?> Holidays &raquo;</a></p>
<p><a class="btn" title="Hebcal Custom Calendar" href="/hebcal/"><i class="icon-pencil"></i> Customize your calendar &raquo;</a></p>
</div><!-- .span4 -->

<div class="span4">
<h3>Convert Dates</h3>
<p>Convert between Hebrew and Gregorian dates and see today's date in a Hebrew font.</p>
<p><a class="btn" href="/converter/"><i class="icon-refresh"></i> Date Converter &raquo;</a></p>

<p>Generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries.</p>
<p><a class="btn" href="/yahrzeit/"><i class="icon-user"></i> Yahrzeit + Anniversary Calendar &raquo;</a></p>
</div><!-- .span4 -->

<div class="span4">
<h3>Shabbat Times</h3>
<p>Candle-lighting and Havdalah times. Weekly Torah portion.</p>
<form action="/shabbat/" method="get" class="form">
<input type="hidden" name="geo" value="zip">
<label>ZIP code:
<input type="text" name="zip" size="5" maxlength="5" class="input-mini"
<?php if ($param["zip"]) { echo "value=\"$param[zip]\" "; } ?>
id="zip"></label>
<input type="hidden" name="m" value="<?php
  if (isset($param["m"])) { echo $param["m"]; } else { echo "72"; } ?>">
<button type="submit" class="btn"><i class="icon-time"></i> Shabbat Times &raquo;</button>
</form>
<?php if ($param["zip"]) { ?>
<p><a class="btn" href="/shabbat/fridge.cgi?zip=<?php echo $param["zip"] ?>;year=<?php
  echo $hebyear ?>"><i class="icon-print"></i> Print times for <?php echo $hebyear ?> &raquo;</a></p>
<?php } else { ?>
<p><a class="btn" href="/home/shabbat/fridge"><i class="icon-print"></i> Print times for <?php echo $hebyear ?> &raquo;</a></p>
<?php } ?>
</div><!-- .span4 -->
</div><!-- .row-fluid -->

<div class="row-fluid">
<div class="span4">
<h3>Torah Readings</h3>
<p>An aliyah-by-aliyah breakdown. Full kriyah and triennial system.</p>
<p><a class="btn" href="/sedrot/"><i class="icon-book"></i> Torah Readings &raquo;</a></p>
</div><!-- .span4 -->

<div class="span4">
<h3>About Us</h3>
<p>Our mission: to increase awareness of Jewish holidays and to help
Jews to be observant of the mitzvot.</p>
<p><a class="btn" href="/home/about/donate"><i class="icon-gift"></i> Donate &raquo;</a></p>
<p><small><a href="/home/category/news">What's new</a>
| <a href="/home/about/privacy-policy">Privacy</a>
| <a href="/home/about/contact">Contact</a></small></p>
</div><!-- .span4 -->

<div class="span4">
<h3>Developers</h3>
<p>APIs, RSS Feeds, JavaScript, Source Code and widgets for
your synagogue or other website.</p>
<p><a class="btn" href="/home/category/developers"><i class="icon-wrench"></i> Developer Docs &raquo;</a></p>
</div><!-- .span4 -->

</div><!-- .row-fluid -->

</div><!-- .span12 -->

<?php
echo html_footer_bootstrap();
?>

