<?php
// $Id$
// $Source: /Users/mradwin/hebcal-copy/hebcal.com/link/index.php,v $

require "../pear/Hebcal/common.inc";
require "../pear/HTML/Form.php";

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)\.(\d+)/', $VER, $matches)) {
    $VER = $matches[1] . "." . $matches[2];
}

if (isset($_COOKIE["C"])) {
    parse_str($_COOKIE["C"], $param);
}
foreach($_REQUEST as $key => $value) {
    $param[$key] = $value;
}

if (isset($param["m"]) && is_numeric($param["m"])) {
    $m = $param["m"];
} else {
    $m = 72;
}
if ($param["zip"] && preg_match('/^\d{5}$/', $param["zip"])) {
    $zip = $param["zip"];
} else {
    $zip = 90210;
}

if ($param["city"]) {
    $geo_city = $param["city"];
    $geo_link = "geo=city;city=" . urlencode($geo_city);

    $geo_city = htmlspecialchars($geo_city);
    $descr = $geo_city;
} else {
    $passfile = file("../hebcal-db-pass.cgi");
    $password = trim($passfile[0]);
    list($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	hebcal_get_zipcode_fields($zip, $password);

    if (!$state) {
	$city = "Unknown";
	$state = "ZZ";
    }

    $geo_link = "geo=zip;zip=" . urlencode($zip);
    $descr = htmlspecialchars("$city, $state $zip");
    $zip = htmlspecialchars($zip);
}

if (isset($param["a"]) && ($param["a"] == "1" || $param["a"] == "on")) {
    $geo_link .= ";a=on";
    $ashk = " checked";
} else {
    $ashk = "";
}

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Add weekly Shabbat candle-lighting times to your synagogue website</title>
<base target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
</head>
<body>
<table width="100%" class="navbar"><tr><td><strong><a
href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a> <tt>-&gt;</tt>
Link
</td><td align="right"><a href="/help/">Help</a> -
<a href="/search/">Search</a></td></tr></table>
<h1>Add Shabbat Times to your Website</h1>

<p>You can use these HTML tags to add weekly Shabbat candle-lighting
times and Torah portion directly on your synagogue's website. To 
display other information on your site (such as today's Hebrew date 
or a full Jewish Calendar, see our <a href="/help/link.html">Linking
from your Synagogue to Hebcal</a> page.</p>

<p>The following
tags are for <b><?php echo $descr ?></b>
(<a href="#change">change city</a>).</p>

<p><b>Instructions:</b> Copy everything from this box and paste it into
the appropriate place in your HTML:</p>

<form>
<textarea cols="72" rows="12" readonly wrap="virtual">
&lt;script type="text/javascript" language="JavaScript"
src="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>;cfg=j"&gt;
&lt;/script&gt;
&lt;noscript&gt;
&lt;!-- this link seen by people who have JavaScript turned off --&gt;
&lt;a href="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>"&gt;Shabbat
Candle Lighting times for <?php echo $descr ?>&lt;/a&gt;
courtesy of hebcal.com.
&lt;/noscript&gt;

</textarea>
</form>

<p>The result will look like this:</p>

<blockquote>
<script type="text/javascript" language="JavaScript"
src="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>;cfg=j">
</script>
<noscript>
<!-- this link seen by people who have JavaScript turned off -->
<a href="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>">Shabbat
Candle Lighting times for <?php echo $descr ?></a>
courtesy of hebcal.com.
</noscript>
</blockquote>

<p>You can also <a href="#fonts">customize the fonts</a> used.</p>

<hr noshade size="1">
<h2><a name="change">Change City</a></h2>

<p>Enter a new city to get revised HTML tags for your
synagogue's web page.</p>

<table cellpadding="8"><tr><td class="box">
<h4>Zip Code</h4>
<br>
<form action="/link/" method="get">
<input type="hidden" name="geo" value="zip">
<label for="zip">Zip code:
<input type="text" name="zip" size="5" maxlength="5" id="zip"
value="<?php echo $zip ?>"></label>

<br><label for="m1">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" id="m1">
</label>

<br>&nbsp;&nbsp;<span class="tiny">(enter "0" to turn off Havdalah times)</span>

<br><br><label for="a"><input type="checkbox"
name="a" id="a"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>

<input type="hidden" name="type" value="shabbat">

<br><br>
<input type="submit" value="Get new link">
</form>
</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td class="box">
<h4>Major City</h4>
<br>
<form name="f2" id="f2" action="/link/">
<input type="hidden" name="geo" value="city">
<label for="city">Closest City:
<?php
global $hebcal_city_tz;
$entries = array();
foreach ($hebcal_city_tz as $k => $v) {
    $entries[$k] = $k;
}
echo HTML_Form::returnSelect("city", $entries,
			     $geo_city ? $geo_city : "Jerusalem");
?>
</label>
<br><label for="m2">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" id="m2">
</label>

<br>&nbsp;&nbsp;<span class="tiny">(enter "0" to turn off Havdalah times)</span>

<br><br><label for="a2"><input type="checkbox"
name="a" id="a2"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>

<input type="hidden" name="type" value="shabbat">

<br><br>
<input type="submit" value="Get new link">
</form>
</td></tr></table>

<p><hr noshade size="1">
<h2><a name="fonts">Customize Fonts</a></h2>

<p>To change the fonts to match the rest of your site, you can add a
CSS stylesheet like this to the 
<tt>&lt;head&gt; ... &lt;/head&gt;</tt> section at the top of your web
page:</p>

<form>
<textarea cols="80" rows="16">
&lt;style type="text/css"&gt;
&lt;!--
#hebcal {
 font-family: "Gill Sans MT","Gill Sans",GillSans,Arial,Helvetica,sans-serif;
 font-size: small;
}
#hebcal H3 {
 font-family: Georgia,Palatino,"Times New Roman",Times,serif;
}
#hebcal .candles { color: red; font-size: large }
#hebcal .havdalah { color: green } 
#hebcal .parashat { color: black; background: #ff9 }
#hebcal .holiday { display: none }
--&gt;
&lt;/style&gt;

</textarea>
</form>

<p>Those fonts and colors are just an example.  <a
href="http://www.w3.org/Style/CSS/">Cascading Style Sheets (CSS)</a> are
very powerful and flexible.</p>

<?php
    my_footer();

function my_footer() {
    $stat = stat($_SERVER["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%c", $stat[9]);
    global $VER;

    $html = <<<EOD
<hr noshade size="1"><span class="tiny">
<a name="copyright"></a>Copyright &copy; $year
Michael J. Radwin. All rights reserved.
<a target="_top" href="http://www.hebcal.com/privacy/">Privacy Policy</a> -
<a target="_top" href="http://www.hebcal.com/help/">Help</a> -
<a target="_top" href="http://www.hebcal.com/contact/">Contact</a> -
<a target="_top" href="http://www.hebcal.com/news/">News</a> -
<a target="_top" href="http://www.hebcal.com/donations/">Donate</a>
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.7 for UNIX</a>, Copyright &copy; 2006 Danny Sadinoff. All rights reserved.
<br>Software last updated: $date (Revision: $VER) 
</span>
<script src="http://www.google-analytics.com/urchin.js"
type="text/javascript">
</script>
<script type="text/javascript">
_uacct = "UA-967247-1";
urchinTracker();
</script>
</body></html>
EOD
	;
    echo $html;
    exit();
}

?>
