<?php
// $Id$
// $Source: /Users/mradwin/hebcal-copy/hebcal.com/shabbat/RCS/fridge.php,v $
require "../pear/Hebcal/common.inc";
require "../pear/HTML/Form.php";

header("Cache-Control: private");
if (isset($_COOKIE["C"])) {
    parse_str($_COOKIE["C"], $param);
}
if (isset($_GET["city"])) {
    $param["city"] = $_GET["city"];
}
if (isset($_GET["zip"]) && is_numeric($_GET["zip"])) {
    $param["zip"] = $_GET["zip"];
}

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)\.(\d+)/', $VER, $matches)) {
    $VER = $matches[1] . "." . $matches[2];
}
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Hebcal Printable Shabbat Times</title>
<base href="http://www.hebcal.com/email/" target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
</head><body><table width="100%"
class="navbar"><tr><td><small><strong><a
href="/">hebcal.com</a></strong>
<tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a>
<tt>-&gt;</tt>
Fridge</small></td><td align="right"><small><a
href="/help/">Help</a> -
<a href="/search/">Search</a></small>
</td></tr></table>
<h1>Printable Shabbat Times</h1>

<p>Fill out the form below to get a page of Shabbat times for the
entire year. You can print it out and post it on your refrigerator.</p>

<blockquote>
<form name="f1" id="f1" action="/shabbat/fridge.cgi" method="get">

<?php if (isset($_GET["geo"]) && $_GET["geo"] == "city") { ?>
<label for="city">Closest City:</label>
<?php
global $hebcal_city_tz;
$entries = array();
foreach ($hebcal_city_tz as $k => $v) {
    $entries[$k] = $k;
}
if ($param["city"]) {
    $geo_city = htmlspecialchars($param["city"]);
}
echo HTML_Form::returnSelect("city", $entries,
			     $geo_city ? $geo_city : "Jerusalem", 1,
			     "", false, 'id="city"');
?>
&nbsp;&nbsp;<input type="submit" value="Get Printable Page">
<br>
&nbsp;&nbsp;<small>(or select by <a
href="/shabbat/fridge.php?geo=zip">zip code</a></small>)
<?php } else { ?>
<label for="zip">Zip code:
<input type="text" name="zip" size="5" maxlength="5"
<?php if ($param["zip"]) { echo "value=\"$param[zip]\" "; } ?>
id="zip"></label>
&nbsp;&nbsp;<input type="submit" value="Get Printable Page">
<br>
&nbsp;&nbsp;<small>(or select by <a
href="/shabbat/fridge.php?geo=city">closest city</a></small>)
<?php } ?>
</form>
</blockquote>

<p>You can also <a href="/email/">subscribe</a> to weekly candle
lighting times by Email.</p>

<?php
    $stat = stat($_SERVER["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%c", $stat[9]);
?>
<hr noshade size="1"><span class="tiny">
<a name="copyright"></a>Copyright &copy; <?php echo $year ?>
Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a> -
<a href="/news/">News</a> -
<a href="/donations/">Donate</a>
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.3 for UNIX</a>, Copyright &copy; 2002 Danny Sadinoff. All rights reserved.
<br>Software last updated:
<?php echo $date ?> (Revision: <?php echo $VER ?>)
</span>
</body></html>
