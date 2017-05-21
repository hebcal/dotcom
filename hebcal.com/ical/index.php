<?php
/***********************************************************************
 * Jewish Holiday downloads for desktop, mobile and web calendars
 *
 * Copyright (c) 2017  Michael J. Radwin.
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
echo html_header_bootstrap3($page_title, $xtra_head);
?>
<div class="row">
<div class="col-sm-12">
<h1>Jewish Holiday downloads <small>for desktop, mobile and web calendars</small></h1>

<p class="lead">Free Jewish holidays for Microsoft
Outlook, iPhone, iPad, macOS Desktop Calendar, Android (via Google Calendar),
or to any desktop program that supports
iCalendar (.ics) files.</p>

<p>Click the buttons below to download/subscribe in your device or web/desktop
application. Subscribers to these feeds receive perpetual updates.</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<?php
function cal_item($path,$title,$subtitle,$feed_length,$suppress_outlook=false) {
    $url_noproto = "download.hebcal.com/ical/" . $path . ".ics";
    $webcal = "webcal://" . $url_noproto;
    $http_esc = urlencode("http://" . $url_noproto);
    $csv_url = "http://download.hebcal.com/ical/" . $path . ".csv";
    $subtitle = preg_replace('/\.\s*$/', '', $subtitle);
?>
<div class="col-sm-6">
<h3><?php echo $title ?></h3>
<p><?php echo $subtitle ?>. <small><?php echo $feed_length ?>-year perpetual feed.</small></p>
<div class="btn-toolbar">
<a class="btn btn-default btn-sm download" id="quick-ical-<?php echo $path ?>"
title="Subscribe to <?php echo $title ?> for iPhone, iPad, macOS Desktop"
href="<?php echo $webcal ?>"><i class="glyphicon glyphicon-download-alt"></i> iPhone, iPad, macOS</a>
<a class="btn btn-default btn-sm download" id="quick-gcal-<?php echo $path ?>"
title="Add <?php echo $title ?> to Google Calendar"
href="http://www.google.com/calendar/render?cid=<?php echo $http_esc ?>"><i class="glyphicon glyphicon-download-alt"></i> Google Calendar</a>
<?php if (!$suppress_outlook) { ?>
<a class="btn btn-default btn-sm download" id="quick-csv-<?php echo $path ?>"
title="Download <?php echo $title ?> to Microsoft Outlook"
href="<?php echo $csv_url ?>" download="<?php echo $path ?>.csv"><i class="glyphicon glyphicon-download-alt"></i> Outlook CSV</a>
<?php
    } // suppress_outlook
?>
</div><!-- .btn-toolbar -->
</div><!-- .col-sm-6 -->
<?php
} // function cal_row()
function cal_divider() {
?></div><!-- .row -->
<hr>
<div class="row">
<?php
} // cal_divider
?>
<div class="row">
<?php
cal_item("jewish-holidays", "Jewish Holidays",
  "Major holidays such as Rosh Hashana, Yom Kippur, Passover, Hanukkah. Diaspora schedule (for Jews living anywhere outside of modern Israel).",
  10);
cal_item("jewish-holidays-all", "Jewish Holidays (all)",
  "Also includes Rosh Chodesh, minor fasts, and special Shabbatot. Diaspora schedule.",
  10);
cal_divider();
cal_item("torah-readings-diaspora", "Torah Readings (Diaspora)",
  "Parashat ha-Shavua - Weekly Torah Portion such as Bereshit, Noach, Lech-Lecha. Diaspora schedule.",
  3);
cal_item("torah-readings-israel-he", "פרשת השבוע - ישראל",
  "Parashat ha-Shavua - Weekly Torah Portion such as בראשית, נח, לך־לך. Israel schedule.",
  3);
cal_divider();
cal_item("omer", "Days of the Omer",
  "7 weeks from the second night of Pesach to the day before Shavuot.",
  2);
cal_item("daf-yomi", "Daf Yomi",
  "Daily regimen of learning the Talmud",
  2);
cal_divider();
cal_item("hdate-en", "Hebrew calendar dates (English)",
  "Displays the Hebrew date (such as <strong>18th of Tevet, 5770</strong>) every day of the week. Sephardic transliteration.",
  2);
cal_item("hdate-he", "Hebrew calendar dates (Hebrew)",
  "Displays the Hebrew date (such as <strong>י״ח בטבת תש״ע</strong>) every day of the week.",
  2);
cal_divider();
?>
<div class="col-sm-6">
<h3>Advanced Settings</h3>
Candle lighting times for Shabbat and holidays, Ashkenazi transliterations, Israeli holiday schedule, etc.
<div class="btn-toolbar">
  <a class="btn btn-success" title="Hebcal Custom Calendar" href="/hebcal/"><i class="glyphicon glyphicon-pencil glyphicon glyphicon-white"></i> Customize your calendar &raquo;</a>
</div>
</div><!-- .col-sm-6 -->
<?php
cal_divider();
?>
<div class="col-sm-12">
<p class="lead">See our <a href="/home/category/import">help importing into
apps</a> for step-by-step instructions.</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->

<?php echo html_footer_bootstrap3(); ?>
