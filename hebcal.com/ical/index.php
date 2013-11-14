<?php
/***********************************************************************
 * Jewish Holiday downloads for desktop, mobile and web calendars
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

require "../pear/Hebcal/common.inc";
header("Content-Type: text/html; charset=UTF-8");

$page_title = "Jewish Holiday downloads for desktop, mobile and web calendars";
$xtra_head = <<<EOD
<style type="text/css">
#hebcal-ical tr td {
  padding: 8px;
  vertical-align: middle;
}
</style>
EOD;
echo html_header_bootstrap($page_title, $xtra_head);
?>
<div class="span12">
<div class="page-header">
<h1>Jewish Holiday downloads <small>for desktop, mobile and web calendars</small></h1>
</div>

<p class="lead">Jewish holiday files for Microsoft
Outlook, Apple iCal, iPhone, iPad, Android (via Google Calendar),
or to any desktop program that supports
iCalendar (.ics) files.</p>

<p>These holidays are for Jews living in the
Diaspora (anywhere outside of modern Israel). Click the icons below to
subscribe in your device or web/desktop application.</p>

<p>For advanced options such as candle-lighting times and Torah
readings, visit our <a href="/hebcal/">custom Jewish calendar</a>
page. See also <a href="/home/category/import">help importing into
apps</a> for step-by-step instructions.</p>
</div><!-- .span12 -->

<?php
function cal_row($path,$title,$subtitle,$suppress_outlook=false) {
    $url_noproto = $_SERVER["HTTP_HOST"] . "/ical/" . $path . ".ics";
    $webcal = "webcal://" . $url_noproto;
    $http_esc = urlencode("http://" . $url_noproto);
?>
<div class="row-fluid">
<div class="span7">
<h4><?php echo $title ?></h4>
<?php echo $subtitle ?></div>
<div class="span1"><a class="download" id="quick-ical-<?php echo $path ?>"
title="Subscribe to <?php echo $title ?> in iCal, iPhone, iPad"
href="<?php echo $webcal ?>"><img
src="/i/ical-64x64.png" width="64" height="64"
alt="Subscribe to <?php echo $title ?> in iCal, iPhone, iPad"
border="0"></a></div>
<div class="span2"><a class="download" id="quick-gcal-<?php echo $path ?>"
title="Add <?php echo $title ?> to Google Calendar"
href="http://www.google.com/calendar/render?cid=<?php echo $http_esc ?>"><img
src="http://www.google.com/calendar/images/ext/gc_button6.gif"
width="114" height="36" border="0"
alt="Add <?php echo $title ?> to Google Calendar"></a>
</div>
<div class="span2">
<?php if ($suppress_outlook) { ?>
<em>(Outlook download not available)</em>
<?php } else { ?>
<a class="download" id="quick-csv-<?php echo $path ?>"
title="Download <?php echo $title ?> to Microsoft Outlook"
href="<?php echo $path ?>.csv" download="$path.csv"><img
src="/i/outlook-149x53.png" width="149" height="53"
alt="Download <?php echo $title ?> to Microsoft Outlook"
border="0"></a>
<?php
    } // suppress_outlook
?>
</div>
</div><!-- .row-fluid -->
<hr>
<?php
} // function cal_row()
?>
<div class="clearfix">
<?php
cal_row("jewish-holidays", "Jewish Holidays",
	"Major holidays such as Rosh Hashana, Yom Kippur, Passover, Hanukkah");
cal_row("jewish-holidays-all", "Jewish Holidays (all)",
	"Also includes Rosh Chodesh, minor fasts, and special Shabbatot");
cal_row("hdate-en", "Hebrew calendar dates (English transliteration)",
	"Displays the Hebrew date (such as <strong>18th of Tevet, 5770</strong>) every day of the week");
cal_row("hdate-he", "Hebrew calendar dates (Hebrew)",
	"Displays the Hebrew date (such as <strong>י״ח בטבת תש״ע</strong>) every day of the week",
	true);
cal_row("torah-readings-diaspora", "Torah Readings",
	"Parashat ha-Shavua - Weekly Torah Portion such as Bereshit, Noach, Lech-Lecha");
cal_row("omer", "Days of the Omer",
	"7 weeks from the second night of Pesach to the day before Shavuot");
?>
</div><!-- .clearfix -->

<div class="clearfix">
<p class="lead">To get a customized feed with candle lighting times for Shabbat
and holidays, Torah readings, etc, follow these instructions:</p>

<ol>
<li>Go to <a
    href="http://www.hebcal.com/hebcal/">http://www.hebcal.com/hebcal/</a>
<li>Fill out the form with your preferences and click the <strong>Create
    Calendar</strong> button
<li>Click the <strong>Download...</strong> button
<li>Follow the instructions for your favorite application or mobile device
</ol>
</div><!-- .clearfix -->

<?php echo html_footer_bootstrap(); ?>
