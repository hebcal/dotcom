<?php
if (isset($_COOKIE["C"])) {
    header("Cache-Control: private");
    parse_str($_COOKIE["C"], $param);
}
# Is today Rosh Chodesh?
$lines = @file("./holiday.inc");
if (is_array($lines)) {
    foreach ($lines as $line) {
	if (strstr($line, "Rosh&nbsp;Chodesh") !== false) {
	    $rosh_chodesh = true;
	    break;
	}
	if (strstr($line, "Chanukah:") !== false) {
	    $chanukah = true;
	    break;
	}
    }
}
unset($lines);
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<!-- $Id$ -->
<html lang="en">
<head>
<title>Jewish Calendar, Hebrew Date Converter, Shabbat Times - Hebcal.com</title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.classify.org/safesurf/" l r (SS~~000 1))'>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true for "http://www.hebcal.com" r (n 0 s 0 v 0 l 0))'>
<meta name="keywords" content="hebcal,Jewish calendar,Hebrew calendar,candle lighting,Shabbat,Havdalah,sedrot,Sadinoff,Yahrzeit,calender">
<meta name="author" content="Michael J. Radwin">
<link rel="stylesheet" href="/style.css" type="text/css">
<base href="http://www.hebcal.com/" target="_top">
</head>
<body>
<form action="/cgi-bin/htsearch" method="get">
<table width="100%" class="navbar">
<tr><td><small><b>hebcal.com:</b>
Jewish Calendar Tools</small></td>
<td align="right"><input type="text" name="words" size="30">
<input type="hidden" name="config" value="hebcal">
<input type="submit" value="Search"></td></tr></table>
</form>
<h1>hebcal.com: Jewish Calendar Tools</h1>
<span class="fpsubhead">
<!-- holiday greeting -->
<span class="fpgreeting">Chag Kasher v'Sameach!</span> &nbsp; - &nbsp;
<!-- end holiday greeting -->
<?php echo date("D, j F Y") ?> &nbsp; - &nbsp; <?php include("./today.inc") ?>
<?php if ($rosh_chodesh) { ?>
&nbsp; - &nbsp; <span class="fpgreeting">Chodesh Tov!</span>
<?php } elseif ($chanukah) { ?>
&nbsp; - &nbsp; <span class="fpgreeting">Chag Urim Sameach!</span>
<?php } ?>
</span>
<?php
$ref = getenv("HTTP_REFERER");
$pattern = '/^http:\/\/(www\.google|(\w+\.)*search\.yahoo|search\.msn|aolsearch\.aol|www\.aolsearch|a9)\.(com|ca|co\.uk)\/.*calend[ae]r/i';
if (!isset($_COOKIE["C"]) && $ref && preg_match($pattern, $ref, $matches)) {
    echo "<blockquote class=\"welcome\">\n";

    $show_amazon = true;
    if ($show_amazon) {
    $cal[] = array("The Jewish Calendar 5766", "0789312395", 80, 110);
    $cal[] = array("The Jewish Calendar 2006", "0883634074", 110, 80);
    $cal[] = array("Jewish Year 5766", "0789312735", 110, 110);
    shuffle($cal);
    list($title,$asin,$width,$height) = $cal[0];

    $amazon_dom = (isset($matches) && isset($matches[3])) ?
	$matches[3] : "com";

	echo <<<MESSAGE_END
<a title="$title from Amazon.$amazon_dom"
href="http://www.amazon.$amazon_dom/exec/obidos/ASIN/$asin/hebcal-20"><img
src="/i/$asin.01.TZZZZZZZ.jpg" border="0"
width="$width" height="$height" hspace="8" align="right"
alt="$title from Amazon.$amazon_dom"></a>
MESSAGE_END;
    }

    echo <<<MESSAGE_END
Hebcal.com offers a free personalized Jewish calendar for any year
0001-9999. You can get a list of Jewish holidays, candle lighting times,
and Torah readings. We also offer export to Palm, Microsoft Outlook, and
Apple iCal. <a href="/hebcal/">Customize your calendar</a>.
MESSAGE_END;

    if ($show_amazon) {
	echo <<<MESSAGE_END
<p>If you are looking for a full-color printed 2006 calendar
with Jewish holidays, consider <a
href="http://www.amazon.$amazon_dom/exec/obidos/ASIN/$asin/hebcal-20">$title</a>
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
generate a calendar of Jewish holidays for any year 0001-9999
<li>
customize candle lighting times to your zip code, city, or latitude/longitude
<li>
export to <a href="/help/import.html#dba">Palm</a>,
<a href="/help/import.html#csv">Outlook</a>, and
<a href="/help/import.html#ical">iCal</a>
</ul>
<h4><a href="/converter/">Hebrew Date Converter</a></h4>
<ul class="gtl">
<li>
convert between Hebrew and Gregorian dates
<li>
find out Torah reading for any date in the future
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
&nbsp;
<b class="hl">NEW!</b>
</ul>
<h4><a href="/holidays/">Jewish Holidays</a></h4>
<ul class="gtl">
<li>
Dates for the next few years and special Torah readings
</ul>
<h4><a href="/yahrzeit/">Yahrzeit, Birthday, and Anniversary
Calendar</a></h4>
<ul class="gtl">
<li>
generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries
</ul>
<h4><a href="/sedrot/">Torah Readings</a></h4>
<ul class="gtl">
<li>
aliyah-by-aliyah breakdown for weekly parshiyot
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
<h4>Quick Links</h4>
<hr noshade size="1">
<ul class="gtl">
<!-- Begin temp holiday -->
<li><b><a
href="/holidays/pesach.html?tag=fp.tmp">Pesach (Passover)</a></b>
<br>12 April 2006<br>(at sunset)<br><br>
<!-- End temp holiday -->
<li><b><a
href="/hebcal/?v=1;year=now;month=now;nx=on;nh=on;vis=on;tag=fp.ql">Current&nbsp;Calendar</a></b><br><?php 
  echo date("F Y");
  include("./holiday.inc");
  include("./current.inc"); ?><br>
<!-- Begin temp holiday2 -->
<!-- End temp holiday2 -->
<br><li><b>Major&nbsp;Holidays</b><br>for
<a href="/hebcal/?v=1;year=2006;month=x;nh=on;tag=fp.ql">2006</a> |
<a href="/hebcal/?v=1;year=5766;yt=H;month=x;nh=on;tag=fp.ql">5766</a><br>
</ul>
<br><hr noshade size="1">
<form action="/shabbat/">
<input type="hidden" name="geo" value="zip">
<b>Candle lighting</b>
<small>
<br><label for="zip">Zip code:</label>
<input type="text" name="zip" size="5" maxlength="5"
<?php if ($param["zip"]) { echo "value=\"$param[zip]\" "; } ?>
id="zip">&nbsp;<input type="submit" value="Go">
<input type="hidden" name="m" value="<?php
  if (isset($param["m"])) { echo $param["m"]; } else { echo "72"; } ?>">
<input type="hidden" name="tag" value="fp.ql">
<br>or <a href="/shabbat/cities.html">select world city</a></small>
</form>
<hr noshade size="1">
<center>
<!-- Begin PayPal Logo -->
<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
<input type="hidden" name="cmd" value="_xclick">
<input type="hidden" name="business" value="webmaster&#64;hebcal.com">
<input type="hidden" name="item_name" value="Donation to hebcal.com">
<input type="hidden" name="no_note" value="1">
<input type="hidden" name="no_shipping" value="1">
<input type="image" name="submit"
src="/i/x-click-but04.gif"
alt="Make payments with PayPal - it's fast, free and secure!">
</form>
<!-- End PayPal Logo -->
<small>This is a free service.<br>
Your contributions keep<br>
this site going!</small>
</center>
</td></tr></table>
<p>
<hr noshade size="1">
<span class="tiny">Copyright
&copy; <?php echo date("Y") ?> Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a> -
<a href="/news/">News</a> -
<a href="/donations/">Donate</a>
<br>This website uses <a
href="http://sourceforge.net/projects/hebcal/">hebcal 3.5 for UNIX</a>,
Copyright &copy; 2006 Danny Sadinoff. All rights reserved.
</span>
</body></html>
