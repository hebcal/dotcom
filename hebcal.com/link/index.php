<?php
// $Id$
// $Source: /Users/mradwin/hebcal-copy/hebcal.com/link/index.php,v $

require_once('zips.inc');
require_once('HTML/Form.php');

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)\.(\d+)/', $VER, $matches)) {
    $VER = $matches[1] . "." . $matches[2];
}

global $HTTP_GET_VARS;
if ($HTTP_GET_VARS['m']) {
    $m = htmlspecialchars($HTTP_GET_VARS['m']);
} else {
    $m = 72;
}
if ($HTTP_GET_VARS['zip'] && preg_match('/^\d{5}$/', $HTTP_GET_VARS['zip'])) {
    $zip = $HTTP_GET_VARS['zip'];
} else {
    $zip = 90210;
}

if ($HTTP_GET_VARS['city']) {
    $geo_city = $HTTP_GET_VARS['city'];
    $geo_link = "geo=city;city=" . urlencode($geo_city);

    $geo_city = htmlspecialchars($geo_city);
    $descr = $geo_city;
} else {
    list($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	get_zipcode_fields($zip);

    if (!$state) {
	$city = 'Unknown';
	$state = 'ZZ';
    }

    $geo_link = "geo=zip;zip=" . urlencode($zip);
    $descr = htmlspecialchars("$city, $state $zip");
    $zip = htmlspecialchars($zip);
}

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Add weekly Shabbat candle-lighting times to your synagogue</title>
<base target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
</head><body><table width="100%"
class="navbar"><tr><td><small><strong><a
href="/">hebcal.com</a></strong>
<tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a>
<tt>-&gt;</tt>
Link</small></td><td align="right"><small><a
href="/help/">Help</a> -
<a href="/search/">Search</a></small>
</td></tr></table><h1>Add 1-Click Shabbat to your website</h1>

<p>You can use these HTML tags to insert weekly candle-lighting times
and Torah portion directly on your synagogue's web page.  The following
results are for <b><?php echo $descr ?></b>
(<a href="#change">change city</a>).</p>

<p><b>Instructions:</b> Copy everything from this box and paste it into
the appropriate place in your HTML:</p>

<form>
<textarea cols="66" rows="10" wrap="virtual">
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
<h3>Shabbat times for <?php echo $descr ?></h3>
<dl>
<dt class="candles">Candle lighting:
<b>4:08pm</b> on Friday, 02 January 2004</dt>
<dt class="parashat">This week's Torah portion is <a target="_top"
href="http://www.hebcal.com/sedrot/vayigash.html">Parashat Vayigash</a></dt>
<dt class="havdalah">Havdalah (72 min):
<b>5:39pm</b> on Saturday, 03 January 2004</dt>
</dl>
<span class="tiny"><a target="_top"
href="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>">1-Click
Shabbat</a> Copyright &copy; <?php echo strftime("%Y", time()) ?> 
Michael J. Radwin. All rights reserved.</a>
</span>
</blockquote>

<hr noshade size="1">
<h2><a name="change">Change City</a></h2>

<p>Enter a new city to get revised HTML tags for your
synagogue's web page.</p>

<table cellpadding="8"><tr><td class="box">
<h4>Zip Code</h4>

<form action="/link/" method="get">
<input type="hidden" name="geo" value="zip">
<label for="zip">Zip code:
<input type="text" name="zip" size="5" maxlength="5" id="zip"
value="<?php echo $zip ?>"></label>

<br><label for="m1">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" id="m1">
</label>

<input type="hidden" name="type" value="shabbat">

<br>
<input type="submit" value="Get new link">
</form>
</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td class="box">
<h4>Major City</h4>
<form name="f2" id="f2" action="/link/">
<input type="hidden" name="geo" value="city">
<label for="city">Closest City:
<?php
global $city_tz;
$entries = array();
foreach ($city_tz as $k => $v) {
    $entries[$k] = $k;
}
echo HTML_Form::returnSelect('city', $entries,
			     $geo_city ? $geo_city : 'Jerusalem');
?>
</label>
<br><label for="m2">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" id="m2">
</label>

<input type="hidden" name="type" value="shabbat">

<br>
<input type="submit" value="Get new link">
</form>
</td></tr></table>

<p><hr noshade size="1">
<h2><a name="fonts">Customize Fonts</a></h2>

<p>To change the fonts to match the rest of your site, you can add a
CSS stylesheet like this to the 
<tt>&lt;head&gt; ... &lt;/head&gt;</tt> section at the top of your web
page:</p>

<blockquote><pre>
&lt;style type="text/css"&gt;
&lt;!--
H1, H2, H3, H4, H5, H6 {
 font-family: Tahoma,Verdana,Arial,Helvetica,Geneva,sans-serif;
}
.candles {
 color: red;
 font-size: large;
}
.parashat {
 color: green;
}
--&gt;
&lt;/style&gt;
</pre></blockquote>

<p>Those fonts and colors are just an example.  <a
href="http://www.w3.org/Style/CSS/">Cascading Style Sheets (CSS)</a> are
very powerful and flexible.</p>

<?php
    my_footer();

function my_footer() {
    global $HTTP_SERVER_VARS;
    $stat = stat($HTTP_SERVER_VARS["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%c", $stat[9]);
    global $VER;

    $html = <<<EOD
<hr noshade size="1"><span class="tiny">
<a name="copyright">Copyright &copy; $year
Michael J. Radwin. All rights reserved.</a>
<a target="_top" href="http://www.hebcal.com/privacy/">Privacy Policy</a> -
<a target="_top" href="http://www.hebcal.com/help/">Help</a> -
<a target="_top" href="http://www.hebcal.com/contact/">Contact</a>
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.3 for UNIX</a>, Copyright &copy; 2002 Danny Sadinoff. All rights reserved.
<br>Software last updated: $date (Revision: $VER) 
</span>
</body></html>
EOD
	;
    echo $html;
    exit();
}

?>
