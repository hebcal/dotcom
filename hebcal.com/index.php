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
<!-- holiday greeting -->
<span style="font-weight: bold; font-style: italic; color: #cc9966">Shana
Tovah!</span> &nbsp; - &nbsp;
<!-- end holiday greeting -->
<!--#config timefmt="%a, %d %B %Y" --><!--#echo var="DATE_LOCAL" -->
&nbsp; - &nbsp; <!--#include file="today.inc" -->
</span>
<!--#if expr="\"$HTTP_REFERER\" = /http://www\.google\.com/" -->
<!--#set var="search" value="1" -->
<!--#elif expr="\"$HTTP_REFERER\" = /http://search\.yahoo\.com/" -->
<!--#set var="search" value="1" -->
<!--#elif expr="\"$HTTP_REFERER\" = /http://search\.msn\.com/" -->
<!--#set var="search" value="1" -->
<!--#elif expr="\"$HTTP_REFERER\" = /http://aolsearch\.aol\.com/" -->
<!--#set var="search" value="1" -->
<!--#endif -->
<!--#if expr="$search = 1" -->
<blockquote class="welcome">
<a title="Jewish Year 5765 Wall Calendar from Amazon.com"
href="http://www.amazon.com/exec/obidos/ASIN/0789311224/hebcal-20"><img
src="/i/0789311224.01.TZZZZZZZ.jpg" border="0"
width="90" height="90" hspace="8" vspace="8" align="right"
alt="Jewish Year 5765 Wall Calendar from Amazon.com"></a>

Hebcal.com offers a <a href="/hebcal/">personalized Jewish calendar</a>
for any year 0000-9999. You can get a list of Jewish holidays, candle
lighting times, and Torah readings. We also offer export to Palm,
Outlook, and iCal -- all for free.

<p>If you're looking for a full-color printed 2004-2005 calendar,
consider the <a
href="http://www.amazon.com/exec/obidos/ASIN/0789311224/hebcal-20">Jewish
Year 5765 Wall Calendar</a> from Amazon.com.
</blockquote>
<!--#endif -->
<table border="0" cellpadding="1" cellspacing="0" width="100%">
<!--#if expr="$search != 1" -->
<tr><td class="tiny">&nbsp;</td></tr>
<!--#endif -->
<tr><td valign="top">
<h4><a href="/hebcal/">Hebcal Interactive Jewish Calendar</a></h4>
<span class="sm-grey">&gt;</span>
generate a calendar of Jewish holidays for any year 0001-9999
<br><span class="sm-grey">&gt;</span>
customize candle lighting times to your zip code, city, or latitude/longitude
<br><span class="sm-grey">&gt;</span>
export to Palm, Outlook, and iCal
<h4><a href="/shabbat/cities.html">1-Click Shabbat Candle Lighting Times</a></h4>
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
<h4><a href="/holidays/">Jewish Holidays</a></h4>
<span class="sm-grey">&gt;</span>
Dates for the next few years and special Torah readings
<h4><a href="/yahrzeit/">Yahrzeit, Birthday, and Anniversary
Calendar</a></h4>
<span class="sm-grey">&gt;</span>
generate a list of Yahrzeit (memorial) and Yizkor dates, or
Hebrew Birthdays and Anniversaries
<h4><a href="/sedrot/">Torah Readings</a></h4>
<span class="sm-grey">&gt;</span>
aliyah-by-aliyah breakdown for weekly parshiyot
<h4>About Us</h4>
<a href="/help/">Help</a>
<br><a href="/news/">What's New?</a>
<br><a href="/privacy/">Privacy Policy</a>
<br><a href="/search/">Search</a>
<br><a href="/donations/">Donate</a>
<br><a href="/contact/">Contact Information</a>
</td>
<td>&nbsp;&nbsp;</td>
<td valign="top" bgcolor="#ffddaa"
style="padding-left: 10px; padding-right: 5px">
<h4>Quick Links</h4>
<hr noshade size="1">
<!-- Begin temp holiday -->
<span class="sm-grey">&gt;</span>&nbsp;<b><a
href="/holidays/rosh-hashana.html">Rosh&nbsp;Hashana&nbsp;5765</a></b><br>15
September 2004<br>at sundown
<br><br>   
<!-- End temp holiday -->
<span class="sm-grey">&gt;</span>&nbsp;<b><a
href="/hebcal/?v=1;year=now;month=now;nx=on;nh=on;s=on;vis=on">Current&nbsp;Calendar</a></b><br><!--#config timefmt="%B %Y" --><!--#echo var="DATE_LOCAL" --><!--#include file="holiday.inc" --><!--#include file="current.inc" --><br>
<br><span class="sm-grey">&gt;</span>&nbsp;<b>Major&nbsp;Holidays</b><br>for
<a href="/hebcal/?v=1;year=2004;month=x;nh=on">2004</a> |
<a href="/hebcal/?v=1;year=5765;yt=H;month=x;nh=on">5765</a><br>
<br><hr noshade size="1">
<form action="/shabbat/"><span
class="sm-grey">&gt;</span>&nbsp;<b>Candle lighting</b>
<small>
<br><label for="zip">Zip code:</label>
<input type="text" name="zip" size="5" maxlength="5"
id="zip">&nbsp;<input type="submit" value="Go">
<input type="hidden" name="geo" value="zip">
<br>or <a href="/shabbat/#change">select by major city</a></small>
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
&copy; 2004 Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a> -
<a href="/news/">News</a> -
<a href="/donations/">Donate</a>
<br>This website uses <a
href="http://sourceforge.net/projects/hebcal/">hebcal 3.3 for UNIX</a>,
Copyright &copy; 2002 Danny Sadinoff. All rights reserved.
</span>
</body></html>
