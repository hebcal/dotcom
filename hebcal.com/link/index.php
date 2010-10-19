<?php
// $Id$
// $URL$

require "../pear/Hebcal/common.inc";
require "../pear/HTML/Form.php";

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)/', $VER, $matches)) {
    $VER = $matches[1];
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

$xtra_head = <<<EOD
<style type="text/css">
.entry-content fieldset {
border:1px solid #E7E7E7;
margin:0 0 12px;
padding:6px;
}
.entry-content input, .entry-content select {
margin:0;
}
form ol {
list-style:none inside none;
margin:0 0 12px 12px;
}
#hebcal-form-left { float:left; width:48%;}
#hebcal-form-right { float:right; width:48%;}
#hebcal-form-bottom { clear:both; }
ul#hebcal-results { list-style-type: none }
</style>
<script type="text/javascript" src="/i/sh-3.0.83/scripts/shCore.js"></script>
<script type="text/javascript" src="/i/sh-3.0.83/scripts/shBrushXml.js"></script>
<script type="text/javascript" src="/i/sh-3.0.83/scripts/shBrushCss.js"></script>
<link type="text/css" rel="stylesheet" href="/i/sh-3.0.83/styles/shCoreDefault.css">
<script type="text/javascript">SyntaxHighlighter.all();</script>
EOD;

echo html_header_new("Add weekly Shabbat candle-lighting times to your synagogue website",
		     "http://www.hebcal.com" . $_SERVER["REQUEST_URI"],
		     $xtra_head);
?>
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">Add Shabbat Times to your Website</h1>
<div class="entry-content">
<p>You can use these HTML tags to add weekly Shabbat candle-lighting
times and Torah portion directly on your synagogue's website. Browse
the <a href="/home/category/developers">Hebcal web developer
APIs</a> to display other information on your site (e.g. today's
Hebrew date, a full Jewish Calendar, RSS feeds).</p>
<p>The following tags are for
<b><?php echo $descr ?></b>
(<a href="#change">change city</a>).</p>
<p><b>Instructions:</b> Copy everything from this box and paste it into
the appropriate place in your HTML:</p>
<pre class="brush:html">
&lt;script type="text/javascript"
src="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>;cfg=j"&gt;
&lt;/script&gt;
&lt;noscript&gt;
&lt;!-- this link seen by people who have JavaScript turned off --&gt;
&lt;a href="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>"&gt;Shabbat
Candle Lighting times for <?php echo $descr ?>&lt;/a&gt;
courtesy of hebcal.com.
&lt;/noscript&gt;
</pre>

<p>The result will look like this (<a href="#fonts">customize fonts</a>):</p>

<div class="box">
<script type="text/javascript"
src="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>;cfg=j">
</script>
<noscript>
<!-- this link seen by people who have JavaScript turned off -->
<a href="http://www.hebcal.com/shabbat/?<?php echo $geo_link ?>;m=<?php echo $m ?>">Shabbat
Candle Lighting times for <?php echo $descr ?></a>
courtesy of hebcal.com.
</noscript>
</div><!-- .box -->
<div>&nbsp</div>

<h2 id="change">Change City</h2>

<p>Enter a new city to get revised HTML tags for your
synagogue's web page.</p>

<div id="hebcal-form-left">
<fieldset><legend>Get Shabbat times by Zip Code</legend>
<form name="f1" id="f1" action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<input type="hidden" name="geo" value="zip">
<input type="hidden" name="type" value="shabbat">
<ol>
<li><label for="zip">Zip code:
<input type="text" name="zip" value="<?php echo $zip ?>" size="5" maxlength="5" id="zip"></label>
<li><label for="m1">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" id="m1">
</label>
<ol><li><small>(enter "0" to turn off Havdalah times)</small></ol>
<li><label for="a1"><input type="checkbox" name="a" id="a1"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>
<li><input type="submit" value="Get new HTML tags">
</ol></fieldset></form>
</div><!-- #hebcal-form-left -->

<div id="hebcal-form-right">
<form name="f2" id="f2" action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<fieldset><legend>Get Shabbat times by Major City</legend>
<input type="hidden" name="geo" value="city">
<input type="hidden" name="type" value="shabbat">
<ol>
<li><?php
global $hebcal_city_tz;
$entries = array();
foreach ($hebcal_city_tz as $k => $v) {
    $entries[$k] = $k;
}
echo HTML_Form::returnSelect("city", $entries,
			     $geo_city ? $geo_city : "Jerusalem");
?>
<li><label for="m2">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" id="m2">
</label>
<ol><li><small>(enter "0" to turn off Havdalah times)</small></ol>
<li><label for="a2"><input type="checkbox" name="a" id="a2"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>
<li><input type="submit" value="Get new HTML tags">
</ol>
</fieldset></form>
</div><!-- #hebcal-form-right -->

<div id="hebcal-form-bottom"></div>

<h2 id="fonts">Customize Fonts</h2>

<p>To change the fonts to match the rest of your site, you can add a
CSS stylesheet like this to the 
<tt>&lt;head&gt; ... &lt;/head&gt;</tt> section at the top of your web
page:</p>

<pre class="brush:html">
&lt;style type="text/css"&gt;
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
&lt;/style&gt;
</pre>

<p>Those fonts and colors are just an example.  <a
href="http://www.w3.org/Style/CSS/">Cascading Style Sheets (CSS)</a> are
very powerful and flexible.</p>

<?php
    $html = <<<EOD
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOD;
    echo $html;
    echo html_footer_new();
    exit();
?>
