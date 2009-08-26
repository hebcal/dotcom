<?php
if (isset($_COOKIE["C"])) {
    header("Cache-Control: private");
    parse_str($_COOKIE["C"], $param);
}

require("./pear/Hebcal/common.inc");

# Determine today's holidays (if any)
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

	if (strncmp($subj, "Rosh Chodesh", 12) == 0) {
	    $rosh_chodesh = true;
	}
	if (strncmp($subj, "Chanukah:", 9) == 0) {
	    $chanukah = true;
	}
	if (strpos($subj, "(CH''M)") !== false) {
	    $pos = strpos($subj, " ");
	    if ($pos === false) { $pos = strlen($subj); }
	    $shalosh_regalim = substr($subj, 0, $pos);
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

# Yamim Nora'im
$jd = gregoriantojd($gm, $gd, $gy);
$hebdate = jdtojewish($jd); 
list($hmnum, $hd, $hy) = explode("/", $hebdate, 3);
if ($hmnum == 13 && $hd >= 1) {
    $shana_tova = true;		# month 13 == Elul
    $rh_jd = jewishtojd(13, 29, $hy);
    $rh_cal = cal_from_jd($rh_jd, CAL_GREGORIAN);
    $erev_rh = sprintf("%s, %s %s %s",
		       $rh_cal["abbrevdayname"],
		       $rh_cal["day"],
		       $rh_cal["monthname"],
		       $rh_cal["year"]);
} elseif ($hmnum == 1 && $hd <= 10) {
    $gmar_tov = true;		# month 1 == Tishrei
} elseif ($hmnum == 8 && $hd >= 7 && $hd <= 15) {
    # for a week before Pesach, show greeting
    $chag_kasher = true;	# month 8 == Nisan
}
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<!-- $Id$ -->
<html lang="en">
<head>
<title>Jewish Calendar, Hebrew Date Converter, Holidays - hebcal.com</title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.classify.org/safesurf/" l r (SS~~000 1))'>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,sedrot,Sadinoff,Yahrzeit,calender">
<meta name="author" content="Michael J. Radwin">
<link rel="stylesheet" href="/style.css" type="text/css">
<base href="http://www.hebcal.com/" target="_top">
</head>
<body>
<form action="/cgi-bin/htsearch" method="get">
<table width="100%" class="navbar"><tr><td><strong>hebcal.com:</strong>
Jewish Calendar Tools</td><td
align="right"><input type="text" name="words" size="30">
<input type="hidden" name="config" value="hebcal">
<input type="submit" value="Search"></td></tr></table>
</form>
<h1>hebcal.com: Jewish Calendar Tools</h1>
<span class="fpsubhead">
<?php echo date("D, j F Y") ?> &nbsp; - &nbsp; <?php
include("./today.inc");
if (isset($events)) {
    foreach ($events as $h) {
	if (strncmp($h, "Parashat ", 9) != 0) {
	    $anchor = hebcal_make_anchor($h);
	    echo "&nbsp; - &nbsp; <a href=\"", $anchor, "\">", $h, "</a>\n";
	}
    }
}
if ($rosh_chodesh) { ?>
<br><span class="fpgreeting">Chodesh Tov! Hebcal.com wishes you
a good new month.</span>
<?php } elseif ($chanukah) { ?>
<br><span class="fpgreeting">Chag Urim Sameach! Hebcal.com wishes you
a happy Chanukah.</span>
<?php } elseif (isset($shalosh_regalim)) { ?>
<br><span class="fpgreeting">Moadim L&#39;Simcha! Hebcal.com wishes you
a happy <?php echo $shalosh_regalim ?>.</span>
<?php } elseif ($minor_fast) { ?>
<br><span class="fpgreeting">Tzom Kal. Hebcal.com wishes you an easy
fast.</span>
<?php } elseif ($shana_tova) { ?>
<br><span class="fpgreeting">Shanah Tovah! Hebcal.com wishes you a happy
and healthy New Year.</span>
<?php     if (isset($erev_rh)) { ?>
<br><span class="fpgreeting"><a href="/holidays/rosh-hashana.html">Rosh Hashana <?php echo $hy + 1 ?></a>
begins at sundown on <?php echo $erev_rh ?>.</span>
<?php     } ?>
<?php } elseif ($gmar_tov) { ?>
<br><span class="fpgreeting">G&#39;mar Chatimah Tovah! Hebcal.com wishes
you a good inscription in the Book of Life.</span>
<?php } elseif ($chag_kasher) { ?>
<br><span class="fpgreeting">Chag Kasher v&#39;Sameach! Hebcal.com
wishes you a happy Passover.</span>
<?php } elseif (isset($chag_sameach)) { ?>
<br><span class="fpgreeting">Chag Sameach! Hebcal.com wishes you
a happy <?php echo $chag_sameach ?>.</span>
<?php } ?>
</span>
<?php
$ref = getenv("HTTP_REFERER");
$pattern = '/^http:\/\/(www\.google|(\w+\.)*search\.yahoo|search\.msn|search\.live|aolsearch\.aol|www\.aolsearch|a9)\.(com|ca|co\.uk)\/.*calend[ae]r/i';
if (!isset($_COOKIE["C"]) && $ref && preg_match($pattern, $ref, $matches)) {
    echo "<blockquote class=\"welcome\">\n";

    $show_amazon = true;
    if ($show_amazon) {

    $cal[] = array("The Jewish Calendar 2010 Wall: From the Collection of the Jewish Historical Museum Amsterdam", "0789319411", 110, 110);
    $cal[] = array("The Jewish Museum 2010 Calendar", "0764947753", 110, 102);
    $cal[] = array("Illuminations 2010 Calendar", "0764947702", 110, 102);
    $cal[] = array("Jewish Celebrations 2010 Calendar", "0764947613", 110, 102);
    $cal[] = array("Hebrew Illuminations 2010 Wall Calendar: A 16 Month Calendar - 5769/5770", "1602372659", 110, 110);

    shuffle($cal);
    list($title,$asin,$width,$height) = $cal[0];

    $amazon_dom = (isset($matches) && isset($matches[3])) ?
	$matches[3] : "com";

	echo <<<MESSAGE_END
<a title="$title from Amazon.$amazon_dom"
href="http://www.amazon.$amazon_dom/o/ASIN/$asin/hebcal-20"><img
src="/i/$asin.01.TZZZZZZZ.jpg" border="0"
width="$width" height="$height" hspace="8" align="right"
alt="$title from Amazon.$amazon_dom"></a>

MESSAGE_END;
    }

    echo <<<MESSAGE_END
Hebcal.com offers a free personalized Jewish calendar for any year
0001-9999. You can get a list of Jewish holidays, candle lighting times,
and Torah readings. We also offer export to Microsoft Outlook, Apple iCal,
Google, and Palm.

<p>Get started <a href="/hebcal/">customizing your calendar</a>.

MESSAGE_END;

    if ($show_amazon) {
	echo <<<MESSAGE_END
<p>If you are looking for a full-color printed 2009 calendar
with Jewish holidays, consider <a
href="http://www.amazon.$amazon_dom/o/ASIN/$asin/hebcal-20">$title</a>
from Amazon.$amazon_dom.

MESSAGE_END;
    }

    echo "</blockquote>\n";
}
?>
<table border="0" cellpadding="1" cellspacing="0" width="100%">
<?php if (!isset($asin)) { ?>
<tr><td class="tiny">&nbsp;</td></tr>
<?php } ?>
<tr><td valign="top">
<h4><a href="/hebcal/">Hebcal Interactive Jewish Calendar</a></h4>
<ul class="gtl">
<li>
Generate a calendar of Jewish holidays and events for any year 0001-9999
<li>
Customize Shabbat and holiday candle lighting times to your zip code, city, or latitude/longitude
<li>
Torah readings for Israel and Diaspora
<li>
Export to
<a href="/help/import.html#csv">Outlook</a>,
<a href="/help/import.html#ical">Apple iCal</a>,
<a href="/help/import.html#gcal">Google Calendar</a>, and
<a href="/help/import.html#dba">Palm</a>
</ul>
<h4><a href="/converter/">Hebrew Date Converter</a></h4>
<ul class="gtl">
<li>
Convert between Hebrew and Gregorian dates
<li>
See date in Hebrew font
</ul>
<h4><a href="/holidays/">Jewish Holidays</a></h4>
<ul class="gtl">
<li>
Dates for the next few years and special Torah readings
</ul>
<h4><a href="/shabbat/">1-Click Shabbat Candle Lighting Times</a></h4>
<ul class="gtl">
<li>
Shabbat candle lighting times and Torah Readings, updated weekly
<li>
<a href="/email/?tag=fp">Subscribe by Email</a> |
<a href="/link/?type=shabbat&amp;tag=fp">Add Shabbat times to your synagogue
website</a>
<li>
<a href="http://www.apple.com/downloads/dashboard/reference/hebcal.html">Mac
OS X Dashboard Widget</a> by Mark Saper
</ul>
<h4><a href="/yahrzeit/">Yahrzeit, Birthday, and Anniversary
Calendar</a></h4>
<ul class="gtl">
<li>
Generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries
</ul>
<h4><a href="/sedrot/">Torah Readings</a></h4>
<ul class="gtl">
<li>
Aliyah-by-aliyah breakdown for weekly parshiyot
</ul>
<h4>About Us</h4>
<ul class="gtl">
<li><a href="/news/">News</a>
<li><a href="/privacy/">Privacy Policy</a>
<li><a href="/contact/">Contact Information</a>
<li><a href="/donations/">Donate</a>
<li><a href="/search/">Site Search</a>
<li><a href="/help/">Help and Frequently Asked Questions</a>
</ul>
</td>
<td>&nbsp;&nbsp;</td>
<td valign="top" bgcolor="#ffddaa"
style="padding-left: 10px; padding-right: 5px">
<h3>Quick Links</h3>
<hr noshade size="1">
<ul class="gtl">
<!-- Begin temp holiday -->
<!-- End temp holiday -->
<li><b><a
href="/hebcal/?v=1;year=<?php echo $gy ?>;month=<?php echo $gm ?>;nx=on;nh=on;vis=on;tag=fp.ql">Current&nbsp;Calendar</a></b><br><?php 
  echo date("F Y");
?>
<br><br><li><b>Major&nbsp;Holidays</b>
<?php
$hebyear = ($hmnum == 13) ? $hy + 1 : $hy;
$gregyear = ($gm > 9) ? $gy + 1 : $gy;
?>
<br>for
<a href="/hebcal/?v=1;year=<?php
  echo $gregyear ?>;month=x;nh=on;tag=fp.ql"><?php echo $gregyear ?></a> |
<a href="/hebcal/?v=1;year=<?php
  echo $hebyear ?>;yt=H;month=x;nh=on;tag=fp.ql"><?php echo $hebyear ?></a>
<br><img src="/i/globaliconical12x12.gif" alt="" width="12"
height="12">&nbsp;<a href="/ical/">Downloads for iCal</a>
<?php
  include("./holiday.inc");
  include("./current.inc"); ?><br>
<!-- Begin temp holiday2 -->
<!-- End temp holiday2 -->
</ul>
<form action="/shabbat/" method="get">
<input type="hidden" name="geo" value="zip">
<h4>Candle lighting</h4>
<hr noshade size="1">
<label for="zip">Zip code:</label>
<input type="text" name="zip" size="5" maxlength="5"
<?php if ($param["zip"]) { echo "value=\"$param[zip]\" "; } ?>
id="zip">&nbsp;<input type="submit" value="Go">
<input type="hidden" name="m" value="<?php
  if (isset($param["m"])) { echo $param["m"]; } else { echo "72"; } ?>">
<input type="hidden" name="tag" value="fp.ql">
<br><small>or <a href="/shabbat/cities.html">select world city</a></small>
</form>
</td></tr></table>
<p>
<?php
echo html_footer_lite(false);
?>

