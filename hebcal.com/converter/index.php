<?php

########################################################################
# Convert between hebrew and gregorian calendar dates.
#
# Copyright (c) 2005  Michael J. Radwin.
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

require_once('HTML/Form.php');

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)\.(\d+)/', $VER, $matches)) {
    $VER = $matches[1] . "." . $matches[2];
}

$hebrew_months = array(
    "Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
    "Cheshvan", "Kislev", "Tevet", "Shvat", "Adar1", "Adar2");

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

my_header();

if ($gy < 1752) {
?>
<p><span style="color: red">WARNING:
Results for year 1752 C.E. and before may not be accurate.</span>
Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation. For more information, see <a
href="http://www.xoc.net/maya/help/gregorian.asp">Gregorian and
Julian Calendars</a>.</p>
<?php
}

$t = mktime(12, 12, 12, $gm, $gd, $gy);
$dow = date("D", $t);
if ($type == "g2h")
{
    $first = "$dow, $gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
    $second = numsuffix($hd) . " of " . $hmstr_to_hebcal[$hm] . ", $hy";
}
else
{
    $first = numsuffix($hd) . " of " . $hmstr_to_hebcal[$hm] . ", $hy";
    $second = "$dow, $gd ". $MoY_long[$gm] .  " " . sprintf("%04d", $gy);
}

?>
<p align="center"><span style="font-size: large">
<?php echo "$first = <b>$second</b>"; ?>
</span></p>
<?php

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

function my_header() {
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Hebrew Date Converter</title>
<base target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
</head><body><table width="100%"
class="navbar"><tr><td><small><strong><a
href="/">hebcal.com</a></strong>
<tt>-&gt;</tt>
Hebrew Date Converter</small></td><td align="right"><small><a
href="/help/">Help</a> -
<a href="/search/">Search</a></small>
</td></tr></table><h1>Hebrew Date Converter</h1>
<?php
}

function form($head, $message, $help = "") {
    global $gm, $gd, $gy, $hm, $hd, $hy, $hmstr_to_hebcal;

    if ($head) {
	my_header();
    }

    if ($message) {
	echo "<hr noshade size=\"1\"><p\nstyle=\"color: red\">",
	    $message, "</p>", $help, "<hr noshade size=\"1\">";
    }
?>
<form name="f1" id="f1" action="/converter/foo.php">
<center><table cellpadding="4">
<tr align="center"><td class="box"><table>
<tr><td colspan="3">Gregorian to Hebrew</td></tr>
<tr><td>Day</td><td>Month</td><td>Year</td></tr>
<tr><td><input type="text" name="gd" value="<?php echo $gd ?>" size="2" maxlength="2" id="gd"></td>
<td><?php
global $MoY_long;
echo HTML_Form::returnSelect("gm", $MoY_long, $gm);
?></td>
<td><input type="text" name="gy" value="<?php echo $gy ?>" size="4" maxlength="4" id="gy"></td></tr>
<tr><td colspan="3">
<label for="gs"><input type="checkbox" name="gs" value="on" id="gs">
After sunset</label>
<br><input name="g2h"
type="submit" value="Compute Hebrew Date"></td></tr>
</table></td>
<td>&nbsp;&nbsp;&nbsp</td>
<td class="box"><table>
<tr><td colspan="3">Hebrew to Gregorian</td></tr>
<tr><td>Day</td><td>Month</td><td>Year</td></tr>
<tr><td><input type="text" name="hd" value="<?php echo $hd ?>" size="2" maxlength="2" id="hd"></td>
<td><?php
echo HTML_Form::returnSelect("hm", $hmstr_to_hebcal, $hm);
?></td>
<td><input type="text" name="hy" value="<?php echo $hy ?>" size="4" maxlength="4" id="hy"></td></tr>
<tr><td colspan="3"><input name="h2g"
type="submit" value="Compute Gregorian Date"></td>
</tr></table>
</td></tr>
</table>
<label for="heb">
<input type="checkbox" name="heb" value="on"
<?php if ($_GET["heb"]) { echo " checked "; } ?>
id="heb">
Show date in Hebrew font</label>
<br><small>(requires minimum of IE 4 or Netscape 6)</small>
</center>
</form>
<?php

    my_footer();
    exit(); 
}

function my_footer() {
    global $HTTP_SERVER_VARS;
    $stat = stat($HTTP_SERVER_VARS["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%c", $stat[9]);
    global $VER;

    $html = <<<EOD
<p>Reference: <em><a
href="http://www.amazon.com/exec/obidos/ASIN/0521777526/ref=nosim/hebcal-20">Calendrical
Calculations</a></em>, Edward M. Reingold, Nachum Dershowitz,
Cambridge University Press, 2001.</p>

<hr noshade size="1"><span class="tiny">
<a name="copyright"></a>Copyright &copy; $year
Michael J. Radwin. All rights reserved.
<a target="_top" href="http://www.hebcal.com/privacy/">Privacy Policy</a> -
<a target="_top" href="http://www.hebcal.com/help/">Help</a> -
<a target="_top" href="http://www.hebcal.com/contact/">Contact</a> -
<a target="_top" href="http://www.hebcal.com/news/">News</a> -
<a target="_top" href="http://www.hebcal.com/donations/">Donate</a>
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.4 for UNIX</a>, Copyright &copy; 2005 Danny Sadinoff. All rights reserved.
<br>Software last updated: $date (Revision: $VER) 
</span>
</body></html>
EOD
	;
    echo $html;
    exit();
}

?>
