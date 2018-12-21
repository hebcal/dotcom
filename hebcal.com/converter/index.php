<?php

/***********************************************************************
 * Convert between hebrew and gregorian calendar dates.
 *
 * Copyright (c) 2018  Michael J. Radwin.
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

$in_israel = false;
if (isset($_SERVER['MM_COUNTRY_CODE']) && $_SERVER['MM_COUNTRY_CODE'] == 'IL') {
    date_default_timezone_set('Asia/Jerusalem');
    $in_israel = true;
}

$calinf = cal_info(CAL_GREGORIAN);
$MoY_long = $calinf["months"];

if (isset($_GET["h2g"]) && $_GET["h2g"] &&
    isset($_GET["hm"]) && isset($_GET["hd"]) && isset($_GET["hy"]))
{
    $type = "h2g";
    $hd = $_GET["hd"];
    $hy = $_GET["hy"];
    $hm = $_GET["hm"];

    # if they specify "Sh'vat" or "Adar II", convert to "Shvat" or "Adar2"
    $hmstr_reverse = array_flip($hmstr_to_hebcal);
    if (isset($hmstr_reverse[$hm])) {
        $hm = $hmstr_reverse[$hm];
    }

    $always29 = array(
            "Iyyar" => true,
            "Tamuz" => true,
            "Elul"  => true,
            "Tevet" => true,
        );

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
    } elseif ($hd == 30 && isset($always29[$hm])) {
        form(true, "Hebrew day out of valid range 1-29 for $hm", "");
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

        // remove leading zeros, if any
        if (strlen($gm) > 1 && $gm[0] == "0") {
            $gm = $gm[1];
        }
        if (strlen($gd) > 1 && $gd[0] == "0") {
            $gd = $gd[1];
        }

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

        $max_gd = cal_days_in_month(CAL_GREGORIAN, $gm, $gy);
        if ($gd > $max_gd) {
            form(true, "Gregorian day $gd out of valid range 1-$max_gd for $MoY_long[$gm] $gy", "");
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
    $debug = $hebdate;
    list($hmnum, $hd, $hy) = explode("/", $hebdate, 3);
    $hm = $hnum_to_str[$hmnum];
//    $hmstr = jdmonthname($jd,4);
}
else
{
    $hmnum = $hmstr_to_num[$hm];
    if ($hmnum == 6 && !is_leap_year($hy)) {
        $hmnum = 7;
        $hm = "Adar";
    }
    $max_hd = cal_days_in_month(CAL_JEWISH, $hmnum, $hy);
    if ($hd > $max_hd) {
        form(true, "Hebrew day $hd out of valid range 1-$max_hd for $hm in year $hy", "");
    }
    $jd = jewishtojd($hmnum, $hd, $hy);
    $greg = jdtogregorian($jd);
    $debug = $greg;
    list($gm, $gd, $gy) = explode("/", $greg, 3);
}

// remove leading zeros, if any
if ($gm[0] == "0") {
    $gm = $gm[1];
}
if ($gd[0] == "0") {
    $gd = $gd[1];
}

$dow = jddayofweek($jd, 2);

if (strncmp("Adar", $hm, 4) == 0 && !is_leap_year($hy)) {
    $hm = "Adar";
} elseif ($hm == "Adar" && is_leap_year($hy)) {
    $hm = "Adar1";
}

$month_name = $hmstr_to_hebcal[$hm];
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
    header("Access-Control-Allow-Origin: *");
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
    header("Access-Control-Allow-Origin: *");
    header("Content-Type: text/xml; charset=UTF-8");
    echo "<?xml version=\"1.0\" ?>\n"; ?>
<hebcal>
<gregorian year="<?php echo $gy ?>" month="<?php echo $gm ?>" day="<?php echo $gd ?>" />
<hebrew year="<?php echo $hy ?>" month="<?php echo $month_name ?>" day="<?php echo $hd ?>" str="<?php echo $hebrew ?>" />
<?php
    if (!empty($events)) {
        echo "<events>\n";
        foreach ($events as $h) {
            $anchor = hebcal_make_anchor($h);
            echo "<event name=\"$h\" href=\"http://www.hebcal.com$anchor\" />\n";
        }
        echo "</events>\n";
    }
?>
</hebcal>
<?php
    exit();
} else {
    my_header($header_hebdate, "$first = $second");
}

if ($gy < 1752) {
?>
<div class="alert alert-warning alert-dismissible" role="alert">
  <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
<strong>Warning!</strong>
Results for year 1752 C.E. and earlier may be inaccurate.
<p>Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation.<sup><a
href="https://en.wikipedia.org/wiki/Adoption_of_the_Gregorian_calendar">[1]</a></sup></p>
</div><!-- .alert -->
<?php
}
?>
<div id="converter-results">
<!-- <?php echo $debug ?> -->
<ul class="list-unstyled">
<li class="big-list"><span class="nobr"><?php echo $first ?></span> = <strong class="nobr"><?php echo $second ?></strong></li>
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
<style>
#converter-results {
 margin-top: 32px;
 margin-bottom: 32px;
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
.nobr { white-space: nowrap }
</style>
EOD;

echo html_header_bootstrap3("Hebrew Date Converter - $hebdate", $xtra_head, true, true);
?>
<div class="row">
<div class="col-sm-12">
<?php
}

function form($head, $message, $help = "") {
    global $gm, $gd, $gy, $hm, $hd, $hy, $hmstr_to_hebcal;

    if ($message && isset($_GET["cfg"])) {
        header("HTTP/1.1 400 Bad Request");
        if ($_GET["cfg"] == "json") {
            header("Content-Type: application/json; charset=UTF-8");
            $arr = array("error" => $message);
            echo json_encode($arr, 0);
            exit();
        } elseif ($_GET["cfg"] == "xml") {
            header("Content-Type: text/xml; charset=UTF-8");
            echo "<?xml version=\"1.0\" ?>\n<error message=\"$message\" />\n";
            exit();
        }
    }

    if ($head) {
	my_header($message);
    }

    if ($message) {
?>
<div class="alert alert-danger alert-dismissible" role="alert">
  <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
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
<div id="converter-form" class="d-print-none">
<div class="row">
<div class="col-sm-6">
<h5>Convert from Gregorian to Hebrew date</h5>
<form method="get" action="<?php echo $action ?>">
<div class="form-row">
<div class="form-group mr-1">
<input type="text" class="form-control" style="width:48px" name="gd" placeholder="day" value="<?php echo $gd ?>" size="2" maxlength="2" id="gd" pattern="\d*">
</div><!-- .form-group -->
<div class="form-group mr-1">
<?php
global $MoY_long;
echo html_form_select("gm", $MoY_long, $gm, 0, "", false, 'class="form-control" style="width:120px"');
?>
</div><!-- .form-group -->
<div class="form-group mr-1">
<input type="text" class="form-control" style="width:66px" name="gy" placeholder="year" value="<?php echo $gy ?>" size="4" maxlength="4" id="gy" pattern="\d*">
</div><!-- .form-group -->
<div class="form-group">
<div class="form-check">
    <input type="checkbox" name="gs" value="on" id="gs">
    <label class="checkbox" for="gs">After sunset</label>
</div><!-- .form-check -->
</div><!-- .form-group -->
</div><!-- .form-row -->
<div class="form-group">
<button type="button" name="g2h" value="1" class="btn btn-primary"><i class="glyphicons glyphicons-refresh"></i> Convert to Hebrew</button>
</div><!-- .form-group -->
</form>
</div><!-- .col-sm-6 -->

<div class="col-sm-6">
<h5>Convert from Hebrew to Gregorian date</h5>
<form method="get" action="<?php echo $action ?>">
<div class="form-row">
<div class="form-group mr-1">
<input type="text" class="form-control" style="width:48px" name="hd" placeholder="day" value="<?php echo $hd ?>" size="2" maxlength="2" id="hd" pattern="\d*">
</div><!-- .form-group -->
<div class="form-group mr-1">
<?php
echo html_form_select("hm", $hmstr_to_hebcal, $hm, 0, "", false, 'class="form-control" style="width:120px"');
?>
</div><!-- .form-group -->
<div class="form-group mr-1">
<input type="text" class="form-control" style="width:66px" name="hy" placeholder="year" value="<?php echo $hy ?>" size="4" maxlength="4" id="hy" pattern="\d*">
</div><!-- .form-group -->
<div class="form-group">
<button type="button" name="h2g" value="1" class="btn btn-primary"><i class="glyphicons glyphicons-refresh"></i> Convert to Gregorian</button>
</div><!-- .form-group -->
</div><!-- .form-row -->
</form>
</div><!-- .col-sm-6 -->
</div><!-- .row -->
</div><!-- #converter-form -->
<?php

    my_footer();
    exit();
}

function my_footer() {
?>
<hr class="d-print-none">
<div class="row d-print-none">
<div class="col-sm-6 col-sm-offset-3">
<h4 style="font-size:14px;margin-bottom:4px">Advertisement</h4>
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- banner-320x100 -->
<ins class="adsbygoogle"
 style="display:inline-block;width:320px;height:100px"
 data-ad-client="ca-pub-7687563417622459"
 data-ad-slot="1867606375"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .col-sm-6 -->
</div><!-- .row -->
<hr class="d-print-none">
<div class="row d-print-none">
<div class="col-sm-6">
<h5>Yahrzeit + Anniversary Calendar</h5>
<p>Calculate anniversaries on the Hebrew calendar ten years into the
future. Download/export to Outlook, iPhone, Google Calendar and more.</p>
<p><a class="btn btn-secondary" href="/yahrzeit/" role="button"><i class="glyphicons glyphicons-parents"></i> Yahrzeit + Anniversary Calendar &raquo;</a></p>
</div><!-- .col-sm-6 -->
<div class="col-sm-6">
<h5>Hebrew Date Feeds</h5>
<p>Today's Hebrew date for your RSS reader.</p>
<p><a class="btn btn-secondary" href="/etc/hdate-en.xml"
title="Today's Hebrew Date in English Transliteration RSS"><img
src="/i/feed-icon-14x14.png" style="border:none" width="14" height="14"
alt="Today's Hebrew Date in English Transliteration RSS">
English transliteration feed &raquo;</a></p>
<p><a class="btn btn-secondary" href="/etc/hdate-he.xml"
title="Today's Hebrew Date in Hebrew RSS"><img
src="/i/feed-icon-14x14.png" style="border:none" width="14" height="14"
alt="Today's Hebrew Date in Hebrew RSS">
Hebrew feed &raquo;</a></p>
</div><!-- .col-sm-6 -->
</div><!-- .row -->
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<?php

    echo html_footer_bootstrap3(false);
    exit();
}

?>
