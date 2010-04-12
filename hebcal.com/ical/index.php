<?php
header("Content-Type: text/html; charset=UTF-8");
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<!-- $Id$ -->
<html lang="en">
<head>
<title>Jewish Calendar downloads for Apple iCal - hebcal.com</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="http://www.hebcal.com/ical/" target="_top">
<link rel="stylesheet" href="/style.css" type="text/css">
</head><body>

<table width="100%" class="navbar">
<tr><td>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
Jewish Calendar downloads for Apple iCal
</td>
<td align="right">
<a href="/help/">Help</a> -
<a href="/search/">Search</a>
</td></tr></table>

<h1>Jewish Calendar downloads for Apple iCal</h1>

<h2>Quick Start</h2>

<p>Jewish holidays for 2007-2016 are available to <a
href="http://www.apple.com/support/ical/">Apple iCal</a> or to
any desktop program that supports iCalendar files. These holidays are
for Jews living in the Diaspora (anywhere outside of modern Israel).</p>

<?php
function cal_row($path,$title,$subtitle) {
    $webcal = "webcal://www.hebcal.com" . $path;
    $webcal_esc = urlencode($webcal);
    $http_esc = urlencode("http://www.hebcal.com" . $path);
?>
<tr>
<td><a title="Subscribe to <?php echo $title ?> in iCal"
href="<?php echo $webcal ?>"><img
src="/i/ical-64x64.png" width="64" height="64"
alt="Subscribe to <?php echo $title ?> in iCal"
border="0"></a></td>
<td align="center"><a
title="Add <?php echo $title ?> to Windows Live Calendar"
href="http://calendar.live.com/calendar/calendar.aspx?rru=addsubscription&url=<?php echo $webcal_esc ?>&name=<?php echo urlencode($title) ?>"><img
src="/i/wlive-150x20.png"
width="150" height="20" border="0"
alt="Add <?php echo $title ?> to Windows Live Caledar"></a>
</td>
<td align="center"><a
title="Add <?php echo $title ?> to Google Calendar"
href="http://www.google.com/calendar/render?cid=<?php echo $http_esc ?>"><img
src="http://www.google.com/calendar/images/ext/gc_button6.gif"
width="114" height="36" border="0"
alt="Add <?php echo $title ?> to Google Calendar"></a>
</td>
<td><b><?php echo $title ?></b>
<br><?php echo $subtitle ?></td>
</tr>
<?php
}
?>
<table cellpadding="5">
<?php
cal_row("/ical/jewish-holidays.ics", "Jewish Holidays",
	"Major holidays such as Rosh Hashana, Yom Kippur, Passover, Hanukkah");
cal_row("/ical/jewish-holidays-all.ics", "Jewish Holidays (all)",
	"Also includes Rosh Chodesh, minor fasts, and special Shabbatot");
cal_row("/ical/hdate-en.ics", "Hebrew calendar dates (English transliteration)",
	"Displays the Hebrew date (such as <b>18th of Tevet, 5770</b>) every day of the week");
cal_row("/ical/hdate-he.ics", "Hebrew calendar dates (Hebrew)",
	"Displays the Hebrew date (such as <b>י״ח בטבת תש״ע</b>) every day of the week");
?>
</table>

<h2>Customizing your iCal feed</h2>

<p>To get a customized iCal feed with candle lighting times for Shabbat
and holidays, Torah readings, etc, follow these instructions:</p>

<ol>
<li>Go to <a
    href="http://www.hebcal.com/hebcal/">http://www.hebcal.com/hebcal/</a>
<li>Fill out the form with your preferences and click the "Get
    Calendar" button
<li>Click on the "Export calendar to Outlook, Apple iCal, Google, Palm,
    etc." link
<li>Click on the "subscribe" link in the "Apple iCal (and other
    iCalendar-enabled applications)" section
<li><a href="http://www.apple.com/support/ical/">Apple iCal</a>
    will start up
<li>Click <b>Subscribe</b> in the "Subscribe to:" dialog box
<li>Click <b>OK</b> in the next dialog box
</ol>

<p>
<hr noshade size="1">
<span class="tiny">Copyright
&copy; 2009 Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/news/">News</a> -
<a href="/donations/">Donate</a>
<br>
<!-- hhmts start -->
Last modified: Fri Feb 26 14:56:03 PST 2010
<!-- hhmts end -->
($Revision$)
</span>
<script src="http://www.google-analytics.com/urchin.js"
type="text/javascript">
</script>
<script type="text/javascript">
_uacct="UA-967247-1";
urchinTracker();
</script>
</body></html>
