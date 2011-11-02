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

// Yamim Nora'im
$jd = gregoriantojd($gm, $gd, $gy);
$hebdate = jdtojewish($jd); 
list($hmnum, $hd, $hy) = explode("/", $hebdate, 3);
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
} elseif ($hmnum == 8 && $hd >= 2 && $hd <= 15) {
    // for two weeks before Pesach, show greeting
    $chag_kasher = true;	// month 8 == Nisan
} elseif ($hmnum == 3 && $hd >= 10 && $hd <= 24) {
    // for two weeks before Chanukah, show greeting
    $chanukah_jd = jewishtojd(3, 24, $hy); // month 3 == Kislev
    $chanukah_cal = cal_from_jd($chanukah_jd, CAL_GREGORIAN);
    $chanukah_upcoming = sprintf("%s sundown on %s, %s %s %s",
	       $chanukah_cal["abbrevdayname"] == "Fri" ? "before" : "at",
		       $chanukah_cal["abbrevdayname"],
		       $chanukah_cal["day"],
		       $chanukah_cal["monthname"],
		       $chanukah_cal["year"]);
}
$xtra_head = <<<EOD
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,sedrot,Sadinoff,Yahrzeit,calender">
<meta name="author" content="Michael J. Radwin">
EOD;
echo html_header_new("Jewish Calendar, Hebrew Date Converter, Holidays - hebcal.com",
		     $xtra_head,
		     false);
?>
<div id="container">
<div id="content" role="main">
<div class="page type-page hentry">
<div class="entry-content">
<p class="fpsubhead">
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
<br><span class="fpgreeting">Chodesh Tov! We wish you
a good new month.</span>
<?php } elseif ($chanukah) { ?>
<br><span class="fpgreeting">Chag Urim Sameach! We wish you
a happy Chanukah.</span>
<?php } elseif (isset($chanukah_upcoming)) { ?>
<br><span class="fpgreeting">Light the first <a
title="Chanukah, the Festival of Lights"
href="/holidays/chanukah?tag=fp">Hanukkah</a> candle
<?php echo $chanukah_upcoming ?>.</span>
<?php } elseif (isset($shalosh_regalim)) { ?>
<br><span class="fpgreeting">Moadim L&#39;Simcha! We wish you
a happy <?php echo $shalosh_regalim ?>.</span>
<?php } elseif ($shana_tova) { ?>
<br><span class="fpgreeting">Shanah Tovah! We wish you a happy
and healthy New Year.</span>
<?php     if (isset($erev_rh)) { ?>
<br><span class="fpgreeting"><a href="/holidays/rosh-hashana?tag=fp">Rosh
Hashana <?php echo $hy + 1 ?></a> begins at sundown
on <?php echo $erev_rh ?>.</span>
<?php     } ?>
<?php } elseif ($gmar_tov) { ?>
<br><span class="fpgreeting">G&#39;mar Chatimah Tovah! We wish
you a good inscription in the Book of Life.</span>
<?php     if (isset($erev_yk)) { ?>
<br><span class="fpgreeting"><a href="/holidays/yom-kippur?tag=fp">Yom
Kippur</a> begins at sundown
on <?php echo $erev_yk ?>.</span>
<?php     } ?>
<?php } elseif ($chag_kasher) { ?>
<br><span class="fpgreeting">Chag Kasher v&#39;Sameach! We wish
you a happy <a href="/holidays/pesach?tag=fp">Passover</a>.</span>
<?php } elseif (isset($chag_sameach)) { ?>
<br><span class="fpgreeting">Chag Sameach! We wish you
a happy <?php echo $chag_sameach ?>.</span>
<?php } elseif ($minor_fast) { ?>
<br><span class="fpgreeting">Tzom Kal. We wish you an easy
fast.</span>
<?php } ?>
</p><!-- .fpsubhead -->

<p>Make a free <a title="Hebcal Custom Calendar"
href="/hebcal/">custom Jewish calendar</a> for any year 0001-9999 at
Hebcal.com. Included are <a title="Jewish Holidays"
href="/holidays/">Jewish holidays</a> (major and minor), candle
lighting times, and Torah readings.</p>

<p><a href="/ical/">Download</a>
your holiday calendar to Microsoft Outlook, Apple iCal, iPhone, iPad,
BlackBerry, Palm, or Android (via Google Calendar).</p>

<p>Use our <a href="/converter/">Date Converter</a> to convert between
Hebrew and Gregorian dates and see today's date in a Hebrew font. Our
<a href="/yahrzeit/">Yahrzeit, Birthday, and Anniversary Calendar</a>
lets you generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries.</p>

<p>Join our <a href="/email/">Shabbat candle lighting times email
list</a> to receive a weekly reminder of the Parashat ha-Shavua and
when to light candles for your city.</p>

<p>This is a free service. Please <a title="Send money to Hebcal.com"
href="/home/about/donate">donate</a> to show your appreciation.</p>

<p>Developers: we offer <a
title="Including hebcal.com content on other sites, advanced linking"
href="http://www.hebcal.com/home/category/developers">APIs, RSS Feeds,
Source Code and widgets</a> for inclusion on your synagogue or other
website.</p>

<iframe src="http://www.facebook.com/plugins/like.php?app_id=205907769446397&amp;href=http%3A%2F%2Fwww.facebook.com%2Fhebcal&amp;send=false&amp;layout=standard&amp;width=450&amp;show_faces=false&amp;action=like&amp;colorscheme=light&amp;font&amp;height=35" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:450px; height:35px;" allowTransparency="true"></iframe>

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
<li><a
href="/hebcal/?v=1;year=<?php echo $gy ?>;month=<?php echo $gm ?>;nx=on;nh=on;mf=on;ss=on;vis=on;set=off;tag=fp.ql"><?php
  echo date("F Y");
?> Calendar</a>
<?php
  $hebyear = ($hmnum == 13) ? $hy + 1 : $hy;
  $greg_yr1 = $hebyear - 3761;
  $greg_yr2 = $greg_yr1 + 1;
  $greg_range = $greg_yr1 . "-" . $greg_yr2;
?>
<li><a href="/holidays/<?php echo $greg_range ?>"><?php echo $greg_range ?> Holidays</a>
<?php
  include("./holiday.inc");
  include("./current.inc"); ?>
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
</form>
<?php
  if ($param["zip"]) {
     echo "<ul><li><a title=\"Shabbat times for $hebyear\"\n", 
        "href=\"/shabbat/fridge.cgi?zip=$param[zip];year=$hebyear\">Printable\n",
        "page for $hebyear</a><br>year at a glance</li></ul>";
  }
?>
</li>
<li id="advman-3" class="widget-container Advman_Widget"><h3 class="widget-title">Advertisement</h3><script type="text/javascript"><!--
google_ad_client = "ca-pub-7687563417622459";
/* 200x200 text hompeage */
google_ad_slot = "2418261047";
google_ad_width = 200;
google_ad_height = 200;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script></li>
</ul>
</div><!-- #primary .widget-area -->
<?php
echo html_footer_new();
?>

