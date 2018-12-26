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

function my_geoname_city_descr($geonameid) {
    list($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) =
        hebcal_get_geoname($geonameid);
    return geoname_city_descr($name,$admin1,$country);
}

$geo = $geonameid = $zip = $city_descr = "";

if (isset($param["city"])) {
    $geonameid = hebcal_city_to_geoname($param["city"]);
    unset($param["city"]);
    if ($geonameid !== false) {
        $param["geonameid"] = $geonameid;
    }
}

if (isset($param["geonameid"]) && is_numeric($param["geonameid"])) {
    $geonameid = $param["geonameid"];
    $geo = "geoname";
    $city_descr = my_geoname_city_descr($geonameid);
    $geo_link = "geonameid=$geonameid";
} elseif (isset($param["zip"]) && is_numeric($param["zip"])) {
    $zip = $param["zip"];
    $geo = "zip";
    list($city,$state,$tzid,$latitude,$longitude,$lat_deg,$lat_min,$long_deg,$long_min) =
        hebcal_get_zipcode_fields($zip);
    $city_descr = "$city, $state $zip";
    $geo_link = "zip=$zip";
} else {
    $geonameid = 281184;
    $geo = "geoname";
    $city_descr = my_geoname_city_descr($geonameid);
    $geo_link = "geonameid=$geonameid";
}

if (empty($param["city-typeahead"])) {
    $param["city-typeahead"] = $city_descr;
}

if (isset($param["a"]) && ($param["a"] == "1" || $param["a"] == "on")) {
    $geo_link .= "&amp;a=on";
    $ashk = " checked";
} else {
    $ashk = "";
}

$xtra_head = <<<EOD
<style type="text/css">
ul.hebcal-results { list-style-type: none }
#change-city {
  margin-top: 30px;
  margin-bottom: 80px;
}
</style>
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/8.4/styles/github.min.css">
<link rel="stylesheet" type="text/css" href="/i/hyspace-typeahead.css">
EOD;

echo html_header_bootstrap3("Add weekly Shabbat candle-lighting times to your synagogue website",
                     $xtra_head);
?>
<div class="row">
<div class="col-sm-12">
<h1>Add Shabbat Times to your Website</h1>
<p class="lead">Use these HTML tags to add weekly Shabbat candle-lighting
times and Torah portion directly on your synagogue's website.</p>
<p>Browse the <a href="/home/category/developers">Hebcal web developer
APIs</a> to display other information on your site (e.g. today's
Hebrew date, a full Jewish Calendar, RSS feeds).</p>
<p>The following tags are for
<b><?php echo $city_descr ?></b>
(<a href="#change">change city</a>).</p>
<p><b>Instructions:</b> Copy everything from this box and paste it into
the appropriate place in your HTML:</p>
<?php
$script_tag = <<<EOHTML
<script type="text/javascript" charset="utf-8"
src="https://$_SERVER[HTTP_HOST]/shabbat/?geo=${geo}&amp;${geo_link}&amp;m=${m}&amp;cfg=j&amp;tgt=_top">
</script>
EOHTML;
$script_tag_double = htmlentities($script_tag);
?>
<pre><code class="html"><?php echo $script_tag_double ?>
</code></pre>

<p>The result will look like this (<a href="#fonts">customize fonts</a>):</p>

<div class="box">
<?php echo $script_tag ?>
</div><!-- .box -->

<div id="change-city">
<h2 id="change">Change City</h2>

<p>Enter a new city to get revised HTML tags for your
synagogue's web page.</p>

<form action="<?php echo $_SERVER["PHP_SELF"] ?>" method="get">
<input type="hidden" name="geo" id="geo" value="geoname">
<input type="hidden" name="zip" id="zip" value="">
<input type="hidden" name="geonameid" id="geonameid" value="<?php echo htmlspecialchars($geonameid) ?>">

<div class="form-group">
  <label for="city-typeahead">City</label>
  <div class="city-typeahead" style="margin-bottom:12px">
    <input type="text" name="city-typeahead" id="city-typeahead" class="form-control" placeholder="Search for city or ZIP code" value="<?php echo htmlentities($param["city-typeahead"]) ?>">
  </div>
</div>

<div class="form-group">
  <label for="m">Havdalah minutes past sundown
    <a href="#" id="havdalahInfo" data-toggle="tooltip" data-placement="top" title="Use 42 min for three medium-sized stars, 50 min for three small stars, 72 min for Rabbeinu Tam, or 0 to suppress Havdalah times"><span class="glyphicon glyphicon-info-sign"></span></a>
  </label>
  <input type="text" name="m" id="m" class="form-control" pattern="\d*" value="<?php echo $m ?>" maxlength="3">
</div>
<div class="checkbox">
  <label>
    <input type="checkbox" name="a"<?php echo $ashk ?>>
    Use Ashkenazis Hebrew transliterations
  </label>
</div>
<input type="submit" class="btn btn-primary" value="Get new HTML tags">
</fieldset></form>
</div><!-- #change-city -->

<h2 id="fonts">Customize Fonts</h2>

<p>To change the fonts to match the rest of your site, you can add a
<code>&lt;style type="text/css"&gt;</code> stylesheet like this to the
<code>&lt;head&gt; ... &lt;/head&gt;</code> section at the top of your web
page:</p>

<script src="https://gist.github.com/mjradwin/fc4f38384a6335ab9963.js"></script>

<p>Those fonts and colors are just an example.  <a
href="https://www.w3.org/Style/CSS/">Cascading Style Sheets (CSS)</a> are
very powerful and flexible.</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<?php
$js_typeahead_url = hebcal_js_typeahead_bundle_url();
$js_hebcal_app_url = hebcal_js_app_url();
$xtra_html = <<<EOD
<script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/8.4/highlight.min.js"></script>
<script src="$js_typeahead_url"></script>
<script src="$js_hebcal_app_url"></script>
<script type="text/javascript">
hljs.initHighlightingOnLoad();
window['hebcal'].createCityTypeahead(false);
$('#havdalahInfo').click(function(e){
 e.preventDefault();
}).tooltip();
</script>
EOD;
    echo html_footer_bootstrap3(true, $xtra_html);
    exit();
?>
