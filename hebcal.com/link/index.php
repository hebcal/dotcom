<?php

require "../pear/Hebcal/common.inc";

foreach($_REQUEST as $key => $value) {
    $param[$key] = $value;
}

if (isset($param["m"]) && is_numeric($param["m"])) {
    $m = $param["m"];
} else {
    $m = 50;
}
if (isset($param["zip"]) && preg_match('/^\d{5}$/', $param["zip"])) {
    $zip = $param["zip"];
} else {
    $zip = 90210;
}

if (isset($param["city"])) {
    $geo = "city";
    $geo_city = $param["city"];
    $geo_link = "geo=city&amp;city=" . urlencode($geo_city);

    global $hebcal_cities, $hebcal_countries;
    $info = $hebcal_cities[$geo_city];
    $descr = $info[1] . ", " . $hebcal_countries[$info[0]][0];
} elseif (isset($param["geonameid"])) {
    $geo = "geoname";
    $geo_link = "geo=geoname&amp;geonameid=" . $param["geonameid"];
    $descr = $param["city-typeahead"];
} else {
    $geo = "zip";
    list($city,$state,$tzid,$latitude,$longitude,
	 $lat_deg,$lat_min,$long_deg,$long_min) =
	hebcal_get_zipcode_fields($zip);

    if (!$state) {
	$city = "Unknown";
	$state = "ZZ";
    }

    $geo_link = "geo=zip&amp;zip=" . urlencode($zip);
    $descr = htmlspecialchars("$city, $state $zip");
    $zip = htmlspecialchars($zip);
}

if (isset($param["a"]) && ($param["a"] == "1" || $param["a"] == "on")) {
    $geo_link .= "&amp;a=on";
    $ashk = " checked";
} else {
    $ashk = "";
}

$url_base = "http://www.hebcal.com/shabbat/?${geo_link}&amp;m=${m}";
$url_base_double = htmlentities($url_base);

$xtra_head = <<<EOD
<style type="text/css">
ul.hebcal-results { list-style-type: none }
</style>
<script type="text/javascript" src="/i/sh-3.0.83/scripts/shCore.js"></script>
<script type="text/javascript" src="/i/sh-3.0.83/scripts/shBrushXml.js"></script>
<script type="text/javascript" src="/i/sh-3.0.83/scripts/shBrushCss.js"></script>
<link type="text/css" rel="stylesheet" href="/i/sh-3.0.83/styles/shCoreDefault.css">
<link rel="stylesheet" type="text/css" href="/i/typeahead.css">
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
<pre class="brush:html;auto-links:false"">
&lt;script type="text/javascript" charset="utf-8"
src="<?php echo $url_base_double ?>&amp;amp;cfg=j&amp;amp;tgt=_top"&gt;
&lt;/script&gt;
</pre>

<p>The result will look like this (<a href="#fonts">customize fonts</a>):</p>

<div class="box">
<script type="text/javascript" charset="utf-8"
src="<?php echo $url_base ?>&amp;cfg=j&amp;tgt=_top">
</script>
</div><!-- .box -->

<h2 id="change">Change City</h2>

<p>Enter a new city to get revised HTML tags for your
synagogue's web page.</p>

<div class="row-fluid">
<div class="tabbable">
  <ul class="nav nav-tabs">
    <li<?php if ($geo == "zip") { echo ' class="active"';} ?>><a href="#tab-zip" data-toggle="tab">ZIP code</a></li>
    <li<?php if ($geo == "city") { echo ' class="active"';} ?>><a href="#tab-city" data-toggle="tab">Major City</a></li>
    <li<?php if ($geo == "geoname") { echo ' class="active"';} ?>><a href="#tab-search" data-toggle="tab">Search</a></li>
  </ul>
  <div class="tab-content">
    <div class="tab-pane<?php if ($geo == "zip") { echo ' active';} ?>" id="tab-zip">
<form action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<fieldset>
<input type="hidden" name="geo" value="zip">
<label>ZIP code:
<input type="text" name="zip" value="<?php echo $zip ?>" size="5" maxlength="5" style="width:auto"></label>
<label>Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" style="width:auto"></label>
<small class="help-block">(enter "0" to turn off Havdalah times)</small>
<label class="checkbox"><input type="checkbox" name="a"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>
<input type="submit" class="btn btn-primary" value="Get new HTML tags">
</fieldset></form>
    </div><!-- #tab-zip -->
    <div class="tab-pane<?php if ($geo == "city") { echo ' active';} ?>" id="tab-city">
<form action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<fieldset>
<input type="hidden" name="geo" value="city">
<?php
echo html_city_select(isset($geo_city) ? $geo_city : "IL-Jerusalem");
?>
<label>Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" style="width:auto">
</label>
<small class="help-block">(enter "0" to turn off Havdalah times)</small>
<label class="checkbox"><input type="checkbox" name="a"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>
<input type="submit" class="btn btn-primary" value="Get new HTML tags">
</fieldset></form>
    </div><!-- #tab-city -->
    <div class="tab-pane<?php if ($geo == "geoname") { echo ' active';} ?>" id="tab-search">
<form action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<fieldset>
<input type="hidden" name="geo" value="geoname">
<input type="hidden" name="geonameid" id="geonameid" value="">
<div class="city-typeahead form-inline" style="margin-bottom:12px">
<input type="text" name="city-typeahead" id="city-typeahead" class="form-control input-xlarge" placeholder="Search for city" value="<?php echo htmlentities($param["city-typeahead"]) ?>">
</div>
<label>Havdalah minutes past sundown:
<input type="text" name="m" value="<?php echo $m ?>" size="3" maxlength="3" style="width:auto">
</label>
<small class="help-block">(enter "0" to turn off Havdalah times)</small>
<label class="checkbox"><input type="checkbox" name="a"<?php echo $ashk ?>>
Use Ashkenazis Hebrew transliterations</label>
<input type="submit" class="btn btn-primary" value="Get new HTML tags">
</fieldset></form>
    </div><!-- #tab-search -->
  </div><!-- .tab-content -->
</div><!-- .tabbable -->

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
ul.hebcal-results { list-style-type:none }
ul.hebcal-results li {
  margin-bottom: 11px;
  font-size: 21px;
  font-weight: 200;
  line-height: normal;
}
.hebcal-results .candles { color: red; font-size: large }
.hebcal-results .havdalah { color: green } 
.hebcal-results .parashat { color: black; background: #ff9 }
.hebcal-results .holiday { display: none }
&lt;/style&gt;
</pre>

<p>Those fonts and colors are just an example.  <a
href="http://www.w3.org/Style/CSS/">Cascading Style Sheets (CSS)</a> are
very powerful and flexible.</p>

<?php
$xtra_html = <<<EOD
<script src="/i/hogan.min.js"></script>
<script src="/i/typeahead-0.9.3.min.js"></script>
<script type="text/javascript">
$("#city-typeahead").typeahead({
    name: "hebcal-city",
    remote: "/complete.php?q=%QUERY",
    template: '<p><strong>{{asciiname}}</strong> - <small>{{admin1}}, {{country}}</small></p>',
    limit: 7,
    engine: Hogan
}).on('typeahead:selected', function (obj, datum, name) {
  console.debug(datum);
  $('#geonameid').val(datum.id);
});
</script>
EOD;
    echo html_footer_bootstrap(true, $xtra_html);
    exit();
?>
