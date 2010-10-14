<?php

########################################################################
# Convert between hebrew and gregorian calendar dates.
#
# Copyright (c) 2010  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

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

$hmstr_to_num = array(
    "Nisan" => 8,
    "Iyyar" => 9,
    "Sivan" => 10,
    "Tamuz" => 11,
    "Av" => 12,
    "Elul" => 13,
    "Tishrei" => 1,
    "Cheshvan" => 2,
    "Kislev" => 3,
    "Tevet" => 4,
    "Shvat" => 5,
    "Adar1" => 6,
    "Adar2" => 7,
    );

$hnum_to_str = array_flip($hmstr_to_num);

$hmstr_to_hebcal = array(
    "Nisan" => "Nisan",
    "Iyyar" => "Iyyar",
    "Sivan" => "Sivan",
    "Tamuz" => "Tamuz",
    "Av" => "Av",
    "Elul" => "Elul",
    "Tishrei" => "Tishrei",
    "Cheshvan" => "Cheshvan",
    "Kislev" => "Kislev",
    "Tevet" => "Tevet",
    "Shvat" => "Sh'vat",
    "Adar1" => "Adar I",
    "Adar2" => "Adar II",
    );

$hebrew_months = array_keys($hmstr_to_hebcal);

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

if ($type == "g2h")
{
    $first = "$dow$gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
    $second = format_hebrew_date($hd, $hm, $hy);
    my_header($second);
}
else
{
    $first = format_hebrew_date($hd, $hm, $hy);
    $second = "$dow$gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
    my_header($first);
}

if ($gy < 1752) {
?>
<p><span style="color:red;font-size:large">WARNING:
Results for year 1752 C.E. and before may not be accurate.</span>
Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation. For more information, read about the <a
href="http://en.wikipedia.org/wiki/Gregorian_calendar#Adoption_in_Europe">adoption
of the Gregorian Calendar</a>.</p>
<?php
}
?>
<div id="converter-results">
<p style="font-size: large">
<a href="/etc/hdate-en.xml"
title="Today's Hebrew Date in English Transliteration RSS"><img
src="/i/xml.gif" border="0" align="right" width="36" height="14"
alt="Today's Hebrew Date in English Transliteration RSS"></a>
<?php echo "$first = <b>$second</b>"; ?></p>
<p dir="rtl" lang="he" class="hebrew-big">
<a href="/etc/hdate-he.xml"
title="Today's Hebrew Date in Hebrew RSS"><img
src="/i/xml.gif" border="0" align="right" width="36" height="14"
alt="Today's Hebrew Date in Hebrew RSS"></a>
<?php
if ($hm == "Adar1" && !is_leap_year($hy)) {
    $month_name = "Adar";
} else {
    $month_name = $hmstr_to_hebcal[$hm];
}
$hebrew = build_hebrew_date($month_name, $hd, $hy);
echo $hebrew, "\n";
?>
</p>
<?php
if ($gy >= 1900 && $gy <= 2099) {
    $century = substr($gy, 0, 2);
    $f = $_SERVER["DOCUMENT_ROOT"] . "/converter/sedra/$century/$gy.inc";
    @include($f);
    $iso = sprintf("%04d%02d%02d", $gy, $gm, $gd);
    if (isset($sedra) && isset($sedra[$iso])) {
	echo "<div id=\"converter-events\"><ul>\n";
	if (is_array($sedra[$iso])) {
	    foreach ($sedra[$iso] as $sed) {
		display_hebrew_event($sed);
	    }
	} else {
	    display_hebrew_event($sedra[$iso]);
	}
	echo "</ul></div><!-- #converter-events -->\n";
    }
}
echo "</div><!-- #converter-results -->\n";

form(false, "", "");
/*NOTREACHED*/

function numsuffix($n) {
    if ($n >= 10 && $n <= 19) {
	return $n . "th";
    }

    $d = $n % 10;
    if ($d == 1) {
	return $n . "st";
    } elseif ($d == 2) {
	return $n . "nd";
    } elseif ($d == 3) {
	return $n . "rd";
    } else {
	return $n . "th";
    }
}

function is_leap_year($hyear) {
    return (1 + ($hyear * 7)) % 19 < 7 ? true : false;
}

function format_hebrew_date($hd, $hm, $hy) {
    global $hmstr_to_hebcal;
    if ($hm == "Adar1" && !is_leap_year($hy)) {
	$month_name = "Adar";
    } else {
	$month_name = $hmstr_to_hebcal[$hm];
    }

    return numsuffix($hd) . " of " . $month_name . ", $hy";
}

function display_hebrew_event($h) {
    $anchor = hebcal_make_anchor($h);
    echo "<li><a href=\"$anchor\">", $h, "</a>\n";
    if (strncmp($h, "Parashat", 8) == 0) {
	echo "(in Diaspora)\n";
    }
}


function my_header($hebdate) {
    header("Content-Type: text/html; charset=UTF-8");
    echo html_header_new("Hebrew Date Converter - $hebdate",
			 "http://www.hebcal.com/converter/");
?>
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">Date Converter</h1>
<div class="entry-content">
<?php
}

function form($head, $message, $help = "") {
    global $gm, $gd, $gy, $hm, $hd, $hy, $hmstr_to_hebcal;

    if ($head) {
	my_header($message);
    }

    if ($message) {
	echo "<hr noshade size=\"1\"><p\nstyle=\"color: red\">",
	    $message, "</p>", $help, "<hr noshade size=\"1\">";
    }

    $action = $_SERVER["PHP_SELF"];
?>
<div id="converter-form">
<form name="f1" id="f1" action="<?php echo $action ?>">
<input type="text" name="gd" value="<?php echo $gd ?>" size="2" maxlength="2" id="gd">
<?php
global $MoY_long;
echo HTML_Form::returnSelect("gm", $MoY_long, $gm);
?>
<input type="text" name="gy" value="<?php echo $gy ?>" size="4" maxlength="4" id="gy">
<label for="gs"><input type="checkbox" name="gs" value="on" id="gs">
After sunset</label>
<input name="g2h" type="submit" value="Convert Gregorian to Hebrew date">
</form>
<form name="f2" id="f2" action="<?php echo $action ?>">
<input type="text" name="hd" value="<?php echo $hd ?>" size="2" maxlength="2" id="hd">
<?php
echo HTML_Form::returnSelect("hm", $hmstr_to_hebcal, $hm);
?>
<input type="text" name="hy" value="<?php echo $hy ?>" size="4" maxlength="4" id="hy">
<input name="h2g" type="submit" value="Convert Hebrew to Gregorian date">
</form>
</div><!-- #converter-form -->
<?php

    my_footer();
    exit(); 
}

function my_footer() {
    $html = <<<EOD
<p>See also the Hebcal <a href="/yahrzeit/">Yahrzeit, Birthday and
Anniversary Calendar</a> which will calculate dates ten years into the
future and optionally export to Palm, Outlook, or iCal.</p>
EOD
	;

if (!isset($_COOKIE["C"])) {
    $html .= <<<EOD
<div class="converter-ad">
<script type="text/javascript"><!--
google_ad_client = "pub-7687563417622459";
google_alternate_color = "ffffff";
google_ad_width = 728;
google_ad_height = 90;
google_ad_format = "728x90_as";
google_ad_type = "text";
//2006-10-05: converter
google_ad_channel ="0073211120";
//--></script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script>
</div><!-- #converter-ad -->
EOD
	;
}

    $html .= <<<EOD
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOD;

    $html .= html_footer_new();
    echo $html;
    exit();
}

?>
