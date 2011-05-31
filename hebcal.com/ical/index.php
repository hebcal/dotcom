<?php
require "../pear/Hebcal/common.inc";
header("Content-Type: text/html; charset=UTF-8");
$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)/', $VER, $matches)) {
    $VER = $matches[1];
}
$page_title = "Jewish Holiday downloads for desktop, mobile and web-based calendars";
$xtra_head = <<<EOD
<style type="text/css">
#hebcal-ical tr td {
  padding: 8px;
  vertical-align: middle;
}
</style>
EOD;
echo html_header_new($page_title, $xtra_head);
?>
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title"><?php echo $page_title ?></h1>
<div class="entry-content">

<p>Jewish holidays for the next 10 years are available for Microsoft
Outlook, Apple iCal, iPhone, iPad, Android (via Google Calendar),
or to any desktop program that supports
iCalendar (.ics) files. These holidays are for Jews living in the
Diaspora (anywhere outside of modern Israel). Click the icons below to
subscribe in your device or web/desktop application.</p>

<p>For advanced options such as candle-lighting times and Torah
readings, visit our <a href="/hebcal/">custom Jewish calendar</a>
page. See also <a href="/home/category/import">help importing into
apps</a> for step-by-step instructions.</p>

<?php
function cal_row($path,$title,$subtitle) {
    $url_noproto = $_SERVER["HTTP_HOST"] . "/ical/" . $path . ".ics";
    $webcal = "webcal://" . $url_noproto;
    $webcal_esc = urlencode($webcal);
    $http_esc = urlencode("http://" . $url_noproto);
?>
<tr>
<td><b><big><?php echo $title ?></big></b>
<br><?php echo $subtitle ?></td>
<td><a class="download" id="quick-ical-<?php echo $path ?>"
title="Subscribe to <?php echo $title ?> in iCal, iPhone, iPad"
href="<?php echo $webcal ?>"><img
src="/i/ical-64x64.png" width="64" height="64"
alt="Subscribe to <?php echo $title ?> in iCal, iPhone, iPad"
border="0"></a></td>
<td><a class="download" id="quick-csv-<?php echo $path ?>"
title="Download <?php echo $title ?> to Microsoft Outlook"
href="<?php echo $path ?>.csv"><img
src="/i/outlook-149x53.png" width="149" height="53"
alt="Download <?php echo $title ?> to Microsoft Outlook"
border="0"></a></td>
<td><a class="download" id="quick-gcal-<?php echo $path ?>"
title="Add <?php echo $title ?> to Google Calendar"
href="http://www.google.com/calendar/render?cid=<?php echo $http_esc ?>"><img
src="http://www.google.com/calendar/images/ext/gc_button6.gif"
width="114" height="36" border="0"
alt="Add <?php echo $title ?> to Google Calendar"></a>
<br>
<a class="download" id="quick-wlive-<?php echo $path ?>"
title="Add <?php echo $title ?> to Windows Live Calendar"
href="http://calendar.live.com/calendar/calendar.aspx?rru=addsubscription&url=<?php echo $webcal_esc ?>&name=<?php echo urlencode($title) ?>"><img
src="/i/wlive-150x20.png"
width="150" height="20" border="0"
alt="Add <?php echo $title ?> to Windows Live Calendar"></a>
</td>
</tr>
<?php
}
?>
<table id="hebcal-ical" cellpadding="5">
<?php
cal_row("jewish-holidays", "Jewish Holidays",
	"Major holidays such as Rosh Hashana, Yom Kippur, Passover, Hanukkah");
cal_row("jewish-holidays-all", "Jewish Holidays (all)",
	"Also includes Rosh Chodesh, minor fasts, and special Shabbatot");
cal_row("hdate-en", "Hebrew calendar dates (English transliteration)",
	"Displays the Hebrew date (such as <b>18th of Tevet, 5770</b>) every day of the week");
cal_row("hdate-he", "Hebrew calendar dates (Hebrew)",
	"Displays the Hebrew date (such as <b>י״ח בטבת תש״ע</b>) every day of the week");
cal_row("omer", "Days of the Omer",
	"7 weeks from the second night of Pesach to the day before Shavuot");
?>
</table>

<p>To get a customized feed with candle lighting times for Shabbat
and holidays, Torah readings, etc, follow these instructions:</p>

<ol>
<li>Go to <a
    href="http://www.hebcal.com/hebcal/">http://www.hebcal.com/hebcal/</a>
<li>Fill out the form with your preferences and click the "Preview
    Calendar" button
<li>Under the "Export to desktop, mobile or web-based calendar" section,
  follow the instructions for your favorite application or mobile device
</ol>

</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
<?php echo html_footer_new(); ?>
