<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<!-- $Id$ -->
<html lang="en">
<head>
<title>hebcal.com: Interactive Jewish Calendar Tools</title>
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
<span style="font-family: Verdana,Arial,Helvetica,Geneva,sans-serif">
<span style="font-weight: bold; font-style: italic; color: #cc9966">Chag
Sukkot Sameach!</span> &nbsp; - &nbsp;
<!--#config timefmt="%a, %d %B %Y" --><!--#echo var="DATE_LOCAL" -->
&nbsp; - &nbsp; <!--#include file="today.inc" --></span>
<table border="0" cellpadding="12" cellspacing="0">
<tr><td valign="top">
<h4><a href="/hebcal/">Hebcal Interactive Jewish Calendar</a></h4>
<span class="sm-grey">&gt;</span>
generate a calendar of Jewish holidays for any year 0001-9999
<br><span class="sm-grey">&gt;</span>
customize candle lighting times to your zip code, city, or latitude/longitude
<h4><a href="/shabbat/">1-Click Shabbat Candle Lighting Times</a></h4>
<span class="sm-grey">&gt;</span>
Shabbat candle lighting times and Torah Readings, updated weekly
<br><span class="sm-grey">&gt;</span>
<a href="/email/">Subscribe by
Email</a>
<h4><a href="/converter/">Hebrew Date Converter</a></h4>
<span class="sm-grey">&gt;</span>
convert between Hebrew and Gregorian dates
<br><span class="sm-grey">&gt;</span>
find out Torah reading for any date in the future
<h4><a href="/yahrzeit/">Yahrzeit, Birthday, and Anniversary
Calendar</a></h4>
<span class="sm-grey">&gt;</span>
generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries
<h4><a href="/sedrot/">Torah Readings</a></h4>
<span class="sm-grey">&gt;</span>
aliyah-by-aliyah breakdown for weekly parshiyot
<h4>Miscellaneous</h4>
<a href="/help/">Help</a>
<br><a href="/news/">What's New?</a>
<br><a href="/privacy/">Privacy Policy</a>
<br><a href="/search/">Search</a>
<br><a href="/donations/">Donate</a>
<br><a href="/contact/">Contact Information</a>
</td>
<td valign="top" bgcolor="#ffddaa">
<h4>Quick Links</h4>
<hr noshade size="1">
<span class="sm-grey">&gt;</span>&nbsp;<b><a
href="/hebcal/?v=1;year=now;month=now;nx=on;nh=on;s=on;vis=on">Current&nbsp;Calendar</a></b><br><!--#config timefmt="%B %Y" --><!--#echo var="DATE_LOCAL" --><!--#include file="holiday.inc" --><!--#include file="current.inc" --><br><br>
<form action="/shabbat/"><span
class="sm-grey">&gt;</span>&nbsp;<b>Candle lighting</b>
<br><label for="zip">Zip code:</label>
<input type="text" name="zip" size="5" maxlength="5" id="zip">
<input type="hidden" name="geo" value="zip">
<small><br><a href="/shabbat/#change">select by major city</a></small>
</form>
<hr>
<!-- Begin PayPal Logo -->
<form action="https://www.paypal.com/cgi-bin/webscr" method="post">
<input type="hidden" name="cmd" value="_xclick">
<input type="hidden" name="business" value="webmaster&#64;hebcal.com">
<input type="hidden" name="item_name" value="Donation to hebcal.com">
<input type="hidden" name="no_note" value="1">
<input type="hidden" name="no_shipping" value="1">
<input type="image" name="submit"
src="http://www.paypal.com/images/x-click-but04.gif"
alt="Make payments with PayPal - it's fast, free and secure!">
</form>
<!-- End PayPal Logo -->
</td></tr></table>
<p>
<hr noshade size="1">
<span class="tiny">Copyright
&copy; 2003 Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a>
<br>This website uses <a
href="http://sourceforge.net/projects/hebcal/">hebcal 3.3 for UNIX</a>,
Copyright &copy; 2002 Danny Sadinoff. All rights reserved.
</span>
</body></html>
