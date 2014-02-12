<?php
/***********************************************************************
 * Jewish Holiday downloads for desktop, mobile and web calendars
 *
 * Copyright (c) 2014  Michael J. Radwin.
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

<p class="lead">Free Jewish holidays for Microsoft
Outlook, iPhone, iPad, Mac OS X Desktop Calendar, Android (via Google Calendar),
or to any desktop program that supports
iCalendar (.ics) files.</p>

<p>Click the buttons below to download/subscribe in your device or web/desktop
application. Subscribers to these feeds receive perpetual updates.</p>
</div><!-- .span12 -->

<?php
function cal_span6($path,$title,$subtitle,$suppress_outlook=false) {
    $url_noproto = $_SERVER["HTTP_HOST"] . "/ical/" . $path . ".ics";
    $webcal = "webcal://" . $url_noproto;
    $http_esc = urlencode("http://" . $url_noproto);
?>
<div class="span6">
<h3><?php echo $title ?></h3>
<p><?php echo $subtitle ?></p>
<div class="btn-toolbar">
<a class="btn btn-small download" id="quick-ical-<?php echo $path ?>"
title="Subscribe to <?php echo $title ?> for iPhone, iPad, Mac OS X Desktop"
href="<?php echo $webcal ?>"><i class="icon-download-alt"></i> iPhone, iPad, Mac OS X</a>
<a class="btn btn-small download" id="quick-gcal-<?php echo $path ?>"
title="Add <?php echo $title ?> to Google Calendar"
href="http://www.google.com/calendar/render?cid=<?php echo $http_esc ?>"><i class="icon-download-alt"></i> Google Calendar</a>
<?php if (!$suppress_outlook) { ?>
<a class="btn btn-small download" id="quick-csv-<?php echo $path ?>"
title="Download <?php echo $title ?> to Microsoft Outlook"
href="<?php echo $path ?>.csv" download="<?php echo $path ?>.csv"><i class="icon-download-alt"></i> Outlook CSV</a>
<?php
    } // suppress_outlook
?>
</div><!-- .btn-toolbar -->
</div><!-- .span6 -->
<?php
} // function cal_row()
function cal_divider() {
?></div><!-- .row-fluid -->
<hr>
<div class="row-fluid">
<?php
} // cal_divider
?>
<div class="clearfix">
<div class="row-fluid">
<?php
cal_span6("jewish-holidays", "Jewish Holidays",
	"Major holidays such as Rosh Hashana, Yom Kippur, Passover, Hanukkah. Diaspora schedule (for Jews living anywhere outside of modern Israel).");
?>
<div class="span6">
<h3>Advanced Settings</h3>
Candle lighting times for Shabbat and holidays, Ashkenazi transliterations, Israeli holiday schedule, etc.
<div class="btn-toolbar">
  <a class="btn btn-success" title="Hebcal Custom Calendar" href="/hebcal/"><i class="icon-pencil icon-white"></i> Customize your calendar &raquo;</a>
</div>
</div><!-- .span6 -->
<?php
cal_divider();
cal_span6("jewish-holidays-all", "Jewish Holidays (all)",
	"Also includes Rosh Chodesh, minor fasts, and special Shabbatot. Diaspora schedule.");
cal_span6("torah-readings-diaspora", "Torah Readings",
  "Parashat ha-Shavua - Weekly Torah Portion such as Bereshit, Noach, Lech-Lecha. Diaspora schedule.");
cal_divider();
cal_span6("hdate-en", "Hebrew calendar dates (English)",
  "Displays the Hebrew date (such as <strong>18th of Tevet, 5770</strong>) every day of the week. Sephardic transliteration.");
cal_span6("hdate-he", "Hebrew calendar dates (Hebrew)",
	"Displays the Hebrew date (such as <strong>י״ח בטבת תש״ע</strong>) every day of the week.",
	true);
cal_divider();
cal_span6("omer", "Days of the Omer",
	"7 weeks from the second night of Pesach to the day before Shavuot.");
cal_span6("daf-yomi", "Daf Yomi",
	"Daily regimen of learning the Talmud.");
cal_divider();
?>
<p class="lead">See our <a href="/home/category/import">help importing into
apps</a> for step-by-step instructions.</p>
</div><!-- .row-fluid -->
</div><!-- .clearfix -->

<?php echo html_footer_bootstrap(); ?>
