<?php

require "../pear/Hebcal/common.inc";
require "../pear/HTML/Form.php";

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
    list($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	hebcal_get_zipcode_fields($zip);

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

$url_base = "http://www.hebcal.com/shabbat/?${geo_link};m=${m}";

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

echo html_header_bootstrap("Add weekly Shabbat candle-lighting times to your synagogue website",
		     $xtra_head);
?>
<div class="page-header">
<h1>Add Shabbat Times to your Website</h1>
</div>
<p class="lead">Use these HTML tags to add weekly Shabbat candle-lighting
times and Torah portion directly on your synagogue's website.</p>
<p>Browse the <a href="/home/category/developers">Hebcal web developer
APIs</a> to display other information on your site (e.g. today's
Hebrew date, a full Jewish Calendar, RSS feeds).</p>
<p>The following tags are for
<b><?php echo $descr ?></b>
(<a href="#change">change city</a>).</p>
<p><b>Instructions:</b> Copy everything from this box and paste it into
the appropriate place in your HTML:</p>
<pre class="brush:html">
&lt;script type="text/javascript"
src="<?php echo $url_base ?>;cfg=j;tgt=_top"&gt;
&lt;/script&gt;
&lt;noscript&gt;
&lt;!-- this link seen by people who have JavaScript turned off --&gt;
&lt;a target="_top" href="<?php echo $url_base ?>"&gt;Shabbat
Candle Lighting times for <?php echo $descr ?>&lt;/a&gt;
courtesy of hebcal.com.
&lt;/noscript&gt;
</pre>

<p>The result will look like this (<a href="#fonts">customize fonts</a>):</p>

<div class="box">
<script type="text/javascript"
src="<?php echo $url_base ?>;cfg=j;tgt=_top">
</script>
<noscript>
<!-- this link seen by people who have JavaScript turned off -->
<a target="_top" href="<?php echo $url_base ?>">Shabbat
Candle Lighting times for <?php echo $descr ?></a>
courtesy of hebcal.com.
</noscript>
</div><!-- .box -->

<h2 id="change">Change City</h2>

<p>Enter a new city to get revised HTML tags for your
synagogue's web page.</p>

<div class="row-fluid">
<div class="span6">
<form action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<fieldset><legend>Shabbat times by Zip Code</legend>
<input type="hidden" name="geo" value="zip">
<input type="hidden" name="type" value="shabbat">
<label>ZIP code:
<input type="text" name="zip" value="<?php echo $zip ?>" size="5" maxlength="5" style="width:auto"></label>
<label>Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" style="width:auto"></label>
<small class="help-block">(enter "0" to turn off Havdalah times)</small>
<label class="checkbox"><input type="checkbox" name="a"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>
<input type="submit" class="btn btn-primary" value="Get new HTML tags">
</fieldset></form>
</div><!-- .span6 -->

<div class="span6">
<form action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<fieldset><legend>Shabbat times by Major City</legend>
<input type="hidden" name="geo" value="city">
<input type="hidden" name="type" value="shabbat">
<?php
global $hebcal_cities;
$entries = array();
foreach ($hebcal_cities as $k => $v) {
    $entries[$k] = "$v[1], $v[0]";
}
echo HTML_Form::returnSelect("city", $entries,
			     $geo_city ? $geo_city : "IL-Jerusalem",
			     1, "", false, 'class="input-medium"');
?>
<label>Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" style="width:auto">
</label>
<small class="help-block">(enter "0" to turn off Havdalah times)</small>
<label class="checkbox"><input type="checkbox" name="a"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>
<input type="submit" class="btn btn-primary" value="Get new HTML tags">
</fieldset></form>
</div><!-- .span6 -->
</div><!-- .row-fluid -->

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
    echo html_footer_bootstrap();
    exit();
?>
