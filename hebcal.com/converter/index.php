<?php

/***********************************************************************
 * Convert between hebrew and gregorian calendar dates.
 *
 * Copyright (c) 2012  Michael J. Radwin.
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
 *  * Neither the name of Hebcal.com nor the names of its
 *    contributors may be used to endorse or promote products
 *    derived from this software without specific prior written
 *    permission.
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

require("./HTML/Form.php");
require("../pear/Hebcal/hebnum.inc");
require("../pear/Hebcal/common.inc");

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)/', $VER, $matches)) {
    $VER = $matches[1];
}

$calinf = cal_info(CAL_GREGORIAN);
$MoY_long = $calinf["months"];

if ($_GET["h2g"] && $_GET["hm"] && $_GET["hd"] && $_GET["hy"])
{
    $type = "h2g";
    $hd = $_GET["hd"];
    $hy = $_GET["hy"];
    $hm = $_GET["hm"];

    if (!is_numeric($hd)) {
	form(true, "Hebrew day must be numeric", "");
    } elseif (!is_numeric($hy)) {
	form(true, "Hebrew year must be numeric", "");
    } elseif (!in_array($hm, $hebrew_months)) {
	form(true, "Unrecognized hebrew month", "");
    } elseif ($hy <= 3760) {
	form(true, "Hebrew year must be in the common era (3761 and above)", "");
    } elseif ($hd > 30 || $hd < 1) {
	form(true, "Hebrew day out of valid range 1-30", "");
    }

    if ($hm == "Adar2" && !is_leap_year($hy)) {
	$hm = "Adar1";
    }
}
else
{
    $type = "g2h";
    if ($_GET["gm"] && $_GET["gd"] && $_GET["gy"])
    {
	$gm = $_GET["gm"];
	$gd = $_GET["gd"];
	$gy = $_GET["gy"];

	if (!is_numeric($gd)) {
	    form(true, "Gregorian day must be numeric", "");
	} elseif (!is_numeric($gm)) {
	    form(true, "Gregorian month must be numeric", "");
	} elseif (!is_numeric($gy)) {
	    form(true, "Gregorian year must be numeric", "");
	} elseif ($gd > 31 || $gd < 1) {
	    form(true, "Gregorian day out of valid range 1-31", "");
	} elseif ($gm > 12 || $gm < 1) {
	    form(true, "Gregorian month out of valid range 1-12", "");
	} elseif ($gy > 9999 || $gy < 1) {
	    form(true, "Gregorian year out of valid range 0001-9999", "");
	}

	# after sunset?
	if ($_GET["gs"])
	{
	    $jd = gregoriantojd($gm, $gd, $gy);
	    $greg = jdtogregorian($jd + 1);
	    list($gm, $gd, $gy) = explode("/", $greg, 3);
	}
    }
    else
    {
	$now = ($_GET["t"] && is_numeric($_GET["t"])) ? $_GET["t"] : time();

	list($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($now);

	$gm = $mon + 1;
	$gd = $mday;
	$gy = $year + 1900;
    }
}

if ($type == "g2h")
{
    $jd = gregoriantojd($gm, $gd, $gy);
    $hebdate = jdtojewish($jd); 
    list($hmnum, $hd, $hy) = explode("/", $hebdate, 3);
    $hm = $hnum_to_str[$hmnum];
#    $hmstr = jdmonthname($jd,4);
}
else
{
    $hmnum = $hmstr_to_num[$hm];
    $jd = jewishtojd($hmnum, $hd, $hy);
    $greg = jdtogregorian($jd);
    list($gm, $gd, $gy) = explode("/", $greg, 3);
}

if ($gy > 1969 && $gy < 2038)
{
    $t = mktime(12, 12, 12, $gm, $gd, $gy);
    $dow = date("D", $t) . ", ";
}
else
{
    $dow = "";
}

if ($hm == "Adar1" && !is_leap_year($hy)) {
    $month_name = "Adar";
} else {
    $month_name = $hmstr_to_hebcal[$hm];
}
$hebrew = build_hebrew_date($month_name, $hd, $hy);

if ($type == "g2h")
{
    $first = "$dow$gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
    $second = format_hebrew_date($hd, $hm, $hy);
    $header_hebdate = $second;
}
else
{
    $first = format_hebrew_date($hd, $hm, $hy);
    $second = "$dow$gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
    $header_hebdate = $first;
}

if (isset($_GET["cfg"]) && $_GET["cfg"] == "json") {
    header("Content-Type: text/json; charset=UTF-8");
    echo "{\"gy\":$gy,\"gm\":$gm,\"gd\":$gd,\n\"hy\":$hy,\"hm\":\"$month_name\",\"hd\":$hd,\n\"hebrew\":\"$hebrew\"\n}\n";
    exit();
} elseif (isset($_GET["cfg"]) && $_GET["cfg"] == "xml") {
    header("Content-Type: text/xml; charset=UTF-8");
    echo "<?xml version=\"1.0\" ?>\n"; ?>
<hebcal>
<gregorian year="<?php echo $gy ?>" month="<?php echo $gm ?>" day="<?php echo $gd ?>" />
<hebrew year="<?php echo $hy ?>" month="<?php echo $month_name ?>" day="<?php echo $hd ?>" str="<?php echo $hebrew ?>" />
</hebcal>
<?php
    exit();
} else {
    my_header($header_hebdate, "$first = $second");
}

if ($gy < 1752) {
?>
<div class="alert alert-block">
  <button type="button" class="close" data-dismiss="alert">&times;</button>
<strong>Warning!</strong>
Results for year 1752 C.E. and earlier may be inaccurate.
<p>Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation.<sup><a
href="http://en.wikipedia.org/wiki/Gregorian_calendar#Adoption_in_Europe">[1]</a></sup></p>
</div><!-- .alert -->
<?php
}
?>
<div id="converter-results">
<ul class="unstyled">
<li class="big-list"><?php echo "$first = <strong>$second</strong>"; ?></li>
<li dir="rtl" lang="he" class="hebrew big-list jumbo"><?php echo $hebrew ?></li>
<?php
if ($gy >= 1900 && $gy <= 2099) {
    $century = substr($gy, 0, 2);
    $f = $_SERVER["DOCUMENT_ROOT"] . "/converter/sedra/$century/$gy.inc";
    @include($f);
    $iso = sprintf("%04d%02d%02d", $gy, $gm, $gd);
    if (isset($sedra) && isset($sedra[$iso])) {
	if (is_array($sedra[$iso])) {
	    foreach ($sedra[$iso] as $sed) {
		display_hebrew_event($sed);
	    }
	} else {
	    display_hebrew_event($sedra[$iso]);
	}
    }
}
echo "</ul>\n</div><!-- #converter-results -->\n";

form(false, "", "");
/*NOTREACHED*/

function display_hebrew_event($h) {
    $anchor = hebcal_make_anchor($h);
    echo "<li><a href=\"$anchor\">", $h, "</a>\n";
    if (strncmp($h, "Parashat", 8) == 0) {
	echo "(in Diaspora)\n";
    }
}


function my_header($hebdate, $result = false) {
    header("Content-Type: text/html; charset=UTF-8");
    $description = $result ? " $result" : "";
$xtra_head = <<<EOD
<link rel="alternate" type="application/rss+xml" title="RSS" href="/etc/hdate-en.xml">
<meta name="description" content="Convert between Gregorian/civil and Hebrew/Jewish calendar dates.$description">
<style type="text/css">
#converter-results { text-align: center; }
#converter-results .big-list {
  margin-bottom: 6px;
  font-size: 27px;
  font-weight: 200;
  line-height: normal;
}
#converter-results .jumbo {
  font-size: 36px;
}
</style>
EOD;

    echo html_header_bootstrap("Hebrew Date Converter - $hebdate", $xtra_head);
?>
<div class="span9">
<div class="page-header">
<h1>Date Converter <small>Hebrew &harr; Gregorian</small></h1>
</div>
<?php
}

function form($head, $message, $help = "") {
    global $gm, $gd, $gy, $hm, $hd, $hy, $hmstr_to_hebcal;

    if ($head) {
	my_header($message);
    }

    if ($message) {
?>
<div class="alert alert-error">
  <button type="button" class="close" data-dismiss="alert">&times;</button>
  <?php echo $message; echo $help; ?>
</div><!-- .alert -->
<?php
    }

    $action = $_SERVER["SCRIPT_URL"];
?>
<div id="converter-form" class="well well-small">
<form class="form-inline" name="f1" id="f1" action="<?php echo $action ?>">
<fieldset>
<div class="span5">
<div class="controls controls-row">
<input style="width:auto" type="text" name="gd" value="<?php echo $gd ?>" size="2" maxlength="2" id="gd">
<?php
global $MoY_long;
echo HTML_Form::returnSelect("gm", $MoY_long, $gm, 1, "", false, 'class="input-medium"');
?>
<input style="width:auto" type="text" name="gy" value="<?php echo $gy ?>" size="4" maxlength="4" id="gy">
</div><!-- .controls-row -->
<div class="controls controls-row">
<label class="checkbox" for="gs"><input type="checkbox" name="gs" value="on" id="gs">
After sunset</label>
</div><!-- .controls-row -->
</div><!-- .span5 -->
<div class="span4">
<button name="g2h" type="submit" value="1" class="btn btn-primary"><i class="icon-refresh icon-white"></i> Gregorian to Hebrew</button>
</div>
</fieldset>
</form>

<form class="form-inline" name="f2" id="f2" action="<?php echo $action ?>">
<fieldset>
<div class="span5">
<div class="controls controls-row">
<input style="width:auto" type="text" name="hd" value="<?php echo $hd ?>" size="2" maxlength="2" id="hd">
<?php
echo HTML_Form::returnSelect("hm", $hmstr_to_hebcal, $hm, 1, "", false, 'class="input-medium"');
?>
<input style="width:auto" type="text" name="hy" value="<?php echo $hy ?>" size="4" maxlength="4" id="hy">
</div><!-- .controls-row -->
</div><!-- .span5 -->
<div class="span4">
<button name="h2g" type="submit" value="1" class="btn btn-primary"><i class="icon-refresh icon-white"></i> Hebrew to Gregorian</button>
</div>
</fieldset></form></div><!-- #converter-form -->
<?php

    my_footer();
    exit(); 
}

function my_footer() {
?>
<div class="row-fluid">
<div class="span6">
<h4>Yahrzeit + Anniversary Calendar</h4>
<p>Calculate anniversaries on the Hebrew calendar ten years into the
future. Download/export to Outlook, iPhone, Google Calendar and more.</p>
<p><a class="btn" href="/yahrzeit/"><i class="icon-user"></i> Yahrzeit + Anniversary Calendar &raquo;</a></p>
</div><!-- .span6 -->
<div class="span6">
<h4>Hebrew Date Feeds</h4>
<p>Today's Hebrew date for your RSS reader.</p>
<p><a class="btn" href="/etc/hdate-en.xml"
title="Today's Hebrew Date in English Transliteration RSS"><img
src="/i/feed-icon-14x14.png" style="border:none" width="14" height="14"
alt="Today's Hebrew Date in English Transliteration RSS">
English transliteration feed &raquo;</a></p>
<p><a class="btn" href="/etc/hdate-he.xml"
title="Today's Hebrew Date in Hebrew RSS"><img
src="/i/feed-icon-14x14.png" style="border:none" width="14" height="14"
alt="Today's Hebrew Date in Hebrew RSS">
Hebrew feed &raquo;</a></p>
</div><!-- .span6 -->
</div><!-- .row-fluid -->
</div><!-- .span9 -->
<div class="span3" role="complementary">
<h5>Advertisement</h5>
<script type="text/javascript"><!--
google_ad_client = "ca-pub-7687563417622459";
/* 200x200 text only */
google_ad_slot = "5114852649";
google_ad_width = 200;
google_ad_height = 200;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>
</div><!-- .span3 -->
<?php

    echo html_footer_bootstrap();
    exit();
}

?>
