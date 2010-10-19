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
    $rh_jd = jewishtojd(1, 9, $hy);
    $rh_cal = cal_from_jd($rh_jd, CAL_GREGORIAN);
    $erev_yk = sprintf("%s, %s %s %s",
		       $rh_cal["abbrevdayname"],
		       $rh_cal["day"],
		       $rh_cal["monthname"],
		       $rh_cal["year"]);
} elseif ($hmnum == 8 && $hd >= 2 && $hd <= 15) {
    # for two weeks before Pesach, show greeting
    $chag_kasher = true;	# month 8 == Nisan
} elseif ($hmnum == 3 && $hd >= 10 && $hd <= 24) {
    # for two weeks before Chanukah, show greeting
    $chanukah_jd = jewishtojd(3, 24, $hy); # month 3 == Kislev
    $chanukah_cal = cal_from_jd($chanukah_jd, CAL_GREGORIAN);
    $chanukah_upcoming = sprintf("%s sundown on %s, %s %s %s",
	       $chanukah_cal["abbrevdayname"] == "Fri" ? "before" : "at",
		       $chanukah_cal["abbrevdayname"],
		       $chanukah_cal["day"],
		       $chanukah_cal["monthname"],
		       $chanukah_cal["year"]);
}
$xtra_head = <<<EOD
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.classify.org/safesurf/" l r (SS~~000 1))'>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,sedrot,Sadinoff,Yahrzeit,calender">
<meta name="author" content="Michael J. Radwin">
EOD;
echo html_header_new("Jewish Calendar, Hebrew Date Converter, Holidays - hebcal.com",
		     "http://www.hebcal.com/",
		     $xtra_head,
		     false);
?>
<div id="container">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">Home</h1>
<div class="entry-content">
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
<?php } elseif (isset($chanukah_upcoming)) { ?>
<br><span class="fpgreeting">Light the first <a
title="Chanukah, the Festival of Lights"
href="/holidays/chanukah.html?tag=fp">Hanukkah</a> candle
<?php echo $chanukah_upcoming ?>.</span>
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
<br><span class="fpgreeting"><a href="/holidays/rosh-hashana.html?tag=fp">Rosh
Hashana <?php echo $hy + 1 ?></a> begins at sundown
on <?php echo $erev_rh ?>.</span>
<?php     } ?>
<?php } elseif ($gmar_tov) { ?>
<br><span class="fpgreeting">G&#39;mar Chatimah Tovah! Hebcal.com wishes
you a good inscription in the Book of Life.</span>
<?php     if (isset($erev_yk)) { ?>
<br><span class="fpgreeting"><a href="/holidays/yom-kippur.html?tag=fp">Yom
Kippur</a> begins at sundown
on <?php echo $erev_yk ?>.</span>
<?php     } ?>
<?php } elseif ($chag_kasher) { ?>
<br><span class="fpgreeting">Chag Kasher v&#39;Sameach! Hebcal.com
wishes you a happy <a href="/holidays/pesach.html?tag=fp">Passover</a>.</span>
<?php } elseif (isset($chag_sameach)) { ?>
<br><span class="fpgreeting">Chag Sameach! Hebcal.com wishes you
a happy <?php echo $chag_sameach ?>.</span>
<?php } ?>
</span>
<?php
$ref = getenv("HTTP_REFERER");
$pattern = '/^http:\/\/(www\.google|(\w+\.)*search\.yahoo|search\.msn|search\.live|aolsearch\.aol|www\.aolsearch|a9|www\.bing)\.(com|ca|co\.uk)\/.*calend[ae]r/i';
if (!isset($_COOKIE["C"]) && $ref && preg_match($pattern, $ref, $matches)) {
    echo "<blockquote class=\"welcome\">\n";

    $show_amazon = true;
    if ($show_amazon) {

    $cal[] = array("Jewish Museum 2011 Wall Calendar", "076495315X", 102, 110);

    shuffle($cal);
    list($title,$asin,$width,$height) = $cal[0];

    $amazon_dom = (isset($matches) && isset($matches[3])) ?
	$matches[3] : "com";

	echo <<<MESSAGE_END
<a title="$title from Amazon.$amazon_dom"
class="amzn" id="bk-$asin-searchref-1"
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
<p>If you are looking for a full-color printed calendar
with Jewish holidays, consider <a
class="amzn" id="bk-$asin-searchref-2"
href="http://www.amazon.$amazon_dom/o/ASIN/$asin/hebcal-20">$title</a>
from Amazon.$amazon_dom.

MESSAGE_END;
    }

    echo "</blockquote>\n";
}
?>
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
<a href="/help/import-outlook.html">Outlook</a>,
<a href="/help/import-ical.html">Apple iCal</a>,
<a href="/help/import-gcal.html">Google Calendar</a>,
Windows Live Calendar, and
<a href="/help/import-palm.html">Palm</a>
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
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
<div id="primary" class="widget-area" role="complementary">
<ul class="xoxo">
<li id="search-3" class="widget-container widget_search"><form role="search" method="get" id="searchform" action="http://www.hebcal.com/home/" >
	<div><label class="screen-reader-text" for="s">Search for:</label>
	<input type="text" value="" name="s" id="s" />
	<input type="submit" id="searchsubmit" value="Search" />
	</div>
	</form></li>
<li id="categories-3" class="widget-container widget_categories"><h3 class="widget-title">Quick links</h3>
<ul>
<!-- Begin temp holiday -->
<!-- End temp holiday -->
<li><b><a
href="/hebcal/?v=1;year=<?php echo $gy ?>;month=<?php echo $gm ?>;nx=on;nh=on;mf=on;ss=on;vis=on;set=off;tag=fp.ql">Current&nbsp;Calendar</a></b><br><?php 
  echo date("F Y");
?>
<br><br><li><b>Major&nbsp;Holidays</b>
<?php
$hebyear = ($hmnum == 13) ? $hy + 1 : $hy;
$gregyear = ($gm > 9) ? $gy + 1 : $gy;
?>
<br>for
<a href="/hebcal/?v=1;year=<?php
  echo $gregyear ?>;month=x;nh=on;set=off;tag=fp.ql"><?php echo $gregyear ?></a> |
<a href="/hebcal/?v=1;year=<?php
  echo $hebyear ?>;yt=H;month=x;nh=on;set=off;tag=fp.ql"><?php echo $hebyear ?></a>
<br><img src="/i/globaliconical12x12.gif" alt="" width="12"
height="12">&nbsp;<a href="/ical/">Downloads for iCal</a>
<?php
  include("./holiday.inc");
  include("./current.inc"); ?><br>
<!-- Begin temp holiday2 -->
<!-- End temp holiday2 -->
</ul>
</li>
<li id="candles-3" class="widget-container widget_categories"><h3 class="widget-title">Candle lighting</h3>
<form action="/shabbat/" method="get">
<input type="hidden" name="geo" value="zip">
<label for="zip">Zip code:</label>
<input type="text" name="zip" size="5" maxlength="5"
<?php if ($param["zip"]) { echo "value=\"$param[zip]\" "; } ?>
id="zip">&nbsp;<input type="submit" value="Go">
<input type="hidden" name="m" value="<?php
  if (isset($param["m"])) { echo $param["m"]; } else { echo "72"; } ?>">
<input type="hidden" name="tag" value="fp.ql">
<br><small>or <a href="/shabbat/cities.html">select world city</a></small>
</form>
</li>
</ul>
</div><!-- #primary .widget-area -->
<?php
echo html_footer_new(false);
?>

