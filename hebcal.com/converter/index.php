<?php

/***********************************************************************
 * Convert between hebrew and gregorian calendar dates.
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

require("../pear/Hebcal/hebnum.inc");
require("../pear/Hebcal/common.inc");

$calinf = cal_info(CAL_GREGORIAN);
$MoY_long = $calinf["months"];

if (isset($_GET["h2g"]) && $_GET["h2g"] &&
    isset($_GET["hm"]) && isset($_GET["hd"]) && isset($_GET["hy"]))
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
    if (isset($_GET["gm"]) && isset($_GET["gd"]) && isset($_GET["gy"]))
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

	// after sunset?
	if (isset($_GET["gs"]) && $_GET["gs"])
	{
	    $jd = gregoriantojd($gm, $gd, $gy);
	    $greg = jdtogregorian($jd + 1);
	    list($gm, $gd, $gy) = explode("/", $greg, 3);
	}
    }
    else
    {
	$now = (isset($_GET["t"]) && is_numeric($_GET["t"])) ? $_GET["t"] : time();

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
//    $hmstr = jdmonthname($jd,4);
}
else
{
    $hmnum = $hmstr_to_num[$hm];
    $jd = jewishtojd($hmnum, $hd, $hy);
    $greg = jdtogregorian($jd);
    list($gm, $gd, $gy) = explode("/", $greg, 3);
}

$dow = jddayofweek($jd, 2);

if ($hm == "Adar1" && !is_leap_year($hy)) {
    $month_name = "Adar";
} else {
    $month_name = $hmstr_to_hebcal[$hm];
}
$hebrew = build_hebrew_date($month_name, $hd, $hy);

if ($type == "g2h")
{
    $first = "$dow, $gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
    $second = format_hebrew_date($hd, $hm, $hy);
    $header_hebdate = $second;
}
else
{
    $first = format_hebrew_date($hd, $hm, $hy);
    $second = "$dow, $gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
    $header_hebdate = $first;
}

$events = array();
if ($gy >= 1900 && $gy <= 2099) {
    $century = substr($gy, 0, 2);
    $f = $_SERVER["DOCUMENT_ROOT"] . "/converter/sedra/$century/$gy.inc";
    @include($f);
    $iso = sprintf("%04d%02d%02d", $gy, $gm, $gd);
    if (isset($sedra) && isset($sedra[$iso])) {
	if (is_array($sedra[$iso])) {
	    foreach ($sedra[$iso] as $evt) {
		$events[] = $evt;
	    }
	} else {
	    $events[] = $sedra[$iso];
	}
    }
}

if (isset($_GET["cfg"]) && $_GET["cfg"] == "json") {
    header("Content-Type: application/json; charset=UTF-8");
    $callback = false;
    if (isset($_GET["callback"]) && preg_match('/^[\w\.]+$/', $_GET["callback"])) {
	echo $_GET["callback"], "(";
	$callback = true;
    }
    $arr = array("gy"=>$gy,
		 "gm"=>$gm,
		 "gd"=>$gd,
		 "hy"=>$hy,
		 "hm"=>$month_name,
		 "hd"=>$hd,
		 "hebrew"=>$hebrew);
    if (!empty($events)) {
	$arr["events"] = $events;
    }
    echo json_encode($arr, JSON_NUMERIC_CHECK);
    if ($callback) {
	echo ")\n";
    }
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
foreach ($events as $evt) {
    display_hebrew_event($evt);
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
#converter-results {
 margin-top: 12px;
 margin-bottom: 12px;
 text-align: center;
}
#converter-results .big-list {
  margin-bottom: 6px;
  font-size: 29px;
  font-weight: 200;
  line-height: normal;
}
#converter-results .jumbo {
  font-size: 37px;
}
.pseudo-legend {
  font-size: 17px;
  font-weight: bold;
  line-height: 30px;
}
</style>
EOD;

echo html_header_bootstrap("Hebrew Date Converter - $hebdate", $xtra_head, true, true);
?>
<div class="span9">
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

    $action = $_SERVER["PHP_SELF"];
    $pos = strpos($action, "index.php");
    if ($pos !== false) {
	$action = substr($action, 0, $pos);
    }
?>
<div id="converter-form" class="well well-small">
<form class="form-inline" action="<?php echo $action ?>">
<div class="pseudo-legend">Hebrew Date Converter</div>
<fieldset>
<div class="controls controls-row">
<input style="width:auto" type="text" name="gd" value="<?php echo $gd ?>" size="2" maxlength="2" id="gd" pattern="\d*">
<?php
global $MoY_long;
echo html_form_select("gm", $MoY_long, $gm, 1, "", false, 'class="input-medium"');
?>
<input style="width:auto" type="text" name="gy" value="<?php echo $gy ?>" size="4" maxlength="4" id="gy" pattern="\d*">
</div><!-- .controls-row -->
<div class="controls">
<label class="checkbox" for="gs"><input type="checkbox" name="gs" value="on" id="gs">
After sunset</label>
</div><!-- .controls -->
<div class="controls">
<button name="g2h" type="submit" value="1" class="btn btn-primary"><i class="icon-refresh icon-white"></i> Gregorian to Hebrew</button>
</div><!-- .controls -->
</fieldset>
</form>

<form class="form-inline" action="<?php echo $action ?>">
<fieldset>
<div class="controls controls-row">
<input style="width:auto" type="text" name="hd" value="<?php echo $hd ?>" size="2" maxlength="2" id="hd" pattern="\d*">
<?php
echo html_form_select("hm", $hmstr_to_hebcal, $hm, 1, "", false, 'class="input-medium"');
?>
<input style="width:auto" type="text" name="hy" value="<?php echo $hy ?>" size="4" maxlength="4" id="hy" pattern="\d*">
</div><!-- .controls-row -->
<div class="controls">
<button name="h2g" type="submit" value="1" class="btn btn-primary"><i class="icon-refresh icon-white"></i> Hebrew to Gregorian</button>
</div><!-- .controls -->
</fieldset></form></div><!-- #converter-form -->
<?php

    my_footer();
    exit(); 
}

function my_footer() {
?>
<div class="row-fluid">
<div class="span6">
<h5>Yahrzeit + Anniversary Calendar</h5>
<p>Calculate anniversaries on the Hebrew calendar ten years into the
future. Download/export to Outlook, iPhone, Google Calendar and more.</p>
<p><a class="btn" href="/yahrzeit/"><i class="icon-user"></i> Yahrzeit + Anniversary Calendar &raquo;</a></p>
</div><!-- .span6 -->
<div class="span6">
<h5>Hebrew Date Feeds</h5>
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
<script async src="http://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- 200x200 text only -->
<ins class="adsbygoogle"
     style="display:inline-block;width:200px;height:200px"
     data-ad-client="ca-pub-7687563417622459"
     data-ad-slot="5114852649"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .span3 -->
<?php

    echo html_footer_bootstrap();
    exit();
}

?>
