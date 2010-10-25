<?php

########################################################################
# Hebcal PHP helper functions
#
# $Id$
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

$hebcal_city_tz = array(
     "Ashdod"		=>	2,
     "Atlanta"		=>	-5,
     "Austin"		=>	-6,
     "Baghdad"		=>	3,
     "Berlin"		=>	1,
     "Beer Sheva"	=>	2,
     "Baltimore"	=>	-5,
     "Bogota"		=>	-5,
     "Boston"		=>	-5,
     "Buenos Aires"	=>	-3,
     "Buffalo"		=>	-5,
     "Chicago"		=>	-6,
     "Cincinnati"	=>	-5,
     "Cleveland"	=>	-5,
     "Dallas"		=>	-6,
     "Denver"		=>	-7,
     "Detroit"		=>	-5,
     "Eilat"		=>	2,
     "Gibraltar"	=>	-10,
     "Haifa"		=>	2,
     "Hawaii"		=>	-10,
     "Houston"		=>	-6,
     "Jerusalem"	=>	2,
     "Johannesburg"	=>	2,
     "Kiev"		=>	2,
     "La Paz"		=>	-4,
     "London"		=>	0,
     "Los Angeles"	=>	-8,
     "Miami"		=>	-5,
     "Mexico City"	=>	-6,
     "Montreal"		=>	-5,
     "Moscow"		=>	3,
     "New York"		=>	-5,
     "Omaha"		=>	-6,
     "Paris"		=>	1,
     "Petach Tikvah"	=>	2,
     "Philadelphia"	=>	-5,
     "Phoenix"		=>	-7,
     "Pittsburgh"	=>	-5,
     "Saint Louis"	=>	-6,
     "Saint Petersburg"	=>	3,
     "San Francisco"	=>	-8,
     "Seattle"		=>	-8,
     "Tel Aviv"		=>	2,
     "Tiberias"		=>	2,
     "Toronto"		=>	-5,
     "Vancouver"	=>	-8,
     "Washington DC"	=>	-5,
     "Melbourne"	=>	10,
     "Sydney"		=>	10,
     "Ottawa"		=>	-5,
     );
ksort($hebcal_city_tz);

$hebcal_tz_names = array(
     "tz_auto" => "- Attempt to auto-detect -",
     "tz_-5"   => "GMT -05:00 (U.S. Eastern)",
     "tz_-6"   => "GMT -06:00 (U.S. Central)",
     "tz_-7"   => "GMT -07:00 (U.S. Mountain)",
     "tz_-8"   => "GMT -08:00 (U.S. Pacific)",
     "tz_-9"   => "GMT -09:00 (U.S. Alaskan)",
     "tz_-10"  => "GMT -10:00 (U.S. Hawaii)",
     "tz_-11"  => "GMT -11:00",
     "tz_-12"  => "GMT -12:00",
     "tz_12"   => "GMT +12:00",
     "tz_11"   => "GMT +11:00",
     "tz_10"   => "GMT +10:00",
     "tz_9"    => "GMT +09:00",
     "tz_8"    => "GMT +08:00",
     "tz_7"    => "GMT +07:00",
     "tz_6"    => "GMT +06:00",
     "tz_5"    => "GMT +05:00",
     "tz_4"    => "GMT +04:00",
     "tz_3"    => "GMT +03:00",
     "tz_2"    => "GMT +02:00",
     "tz_1"    => "GMT +01:00",
     "tz_0"    => "Greenwich Mean Time",
     "tz_-1"   => "GMT -01:00",
     "tz_-2"   => "GMT -02:00",
     "tz_-3"   => "GMT -03:00",
     "tz_-4"   => "GMT -04:00",
     );

function hebcal_get_zipcode_fields($zip, $password)
{
    $db = mysql_pconnect("mysql5.hebcal.com", "mradwin_hebcal", $password)
	or die("Could not connect: " . mysql_error());

    $sql = <<<EOD
SELECT zips_latitude, zips_longitude,
       zips_timezone, zips_dst, zips_city, zips_state
FROM hebcal5.hebcal_zips
WHERE zips_zipcode = '$zip'
EOD;

    $result = mysql_query($sql, $db)
	or die("Invalid query: " . mysql_error());

    list($latitude,$longitude,$tz,$dst,$city,$state) =
	mysql_fetch_row($result);

    mysql_free_result($result);

    if (!$state)  {
	return null;
    }

    # remove any prefixed + signs from the strings
    $latitude = preg_replace('/^\+/', "", $latitude);
    $longitude = preg_replace('/^\+/', "", $longitude);

    # in hebcal, negative longitudes are EAST (this is backwards)
    $longitude *= -1.0;

    list($long_deg,$long_min) = explode(".", $longitude, 2);
    list($lat_deg,$lat_min) = explode(".", $latitude, 2);

    if ($long_min != "")
    {
	$long_min = "." . $long_min;
    }
    else
    {
	$long_min = 0;
    }

    if ($lat_min != "")
    {
	$lat_min = "." . $lat_min;
    }
    else
    {
	$lat_min = 0;
    }

    $long_min = $long_min * 60;
    if ($long_deg < 0) {
	$long_min *= -1;
    }
    $long_min = sprintf("%.0f", $long_min);

    $lat_min = $lat_min * 60;
    if ($lat_deg < 0) {
	$lat_min *= -1;
    }
    $lat_min = sprintf("%.0f", $lat_min);

    $city = ucwords(strtolower($city));

    return array($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state);
}

function hebcal_make_holiday_anchor($str)
{
    $anchor = strtolower($str);
    $anchor = preg_replace('/\'/',	'', $anchor);
    $anchor = preg_replace('/[^\w]/',	'-', $anchor);
    $anchor = preg_replace('/-+/',	'-', $anchor);
    $anchor = preg_replace('/^-/',	'', $anchor);
    $anchor = preg_replace('/-$/',	'', $anchor);

    return "/holidays/$anchor.html";
}

function hebcal_make_sedra_anchor($str)
{
    $anchor = strtolower($str);
    $anchor = preg_replace('/[^\w]/',	'', $anchor);

    return "/sedrot/$anchor.html";
}

function hebcal_make_anchor($str)
{
    if (strncmp($str, "Parashat", 8) == 0) {
	return hebcal_make_sedra_anchor(substr($str, 9));
    } elseif (strncmp($str, "Parshas", 7) == 0) {
	return hebcal_make_sedra_anchor(substr($str, 8));
    } elseif (preg_match('/^\d+\w+ day of the Omer$/', $str)) {
	return "/holidays/days-of-the-omer.html";
    } elseif ($str != "Candle lighting" && $str != "No sunset today." &&
	      strncmp($str, "Havdalah", 8) != 0) {
	$str_copy = $str;
	$str_copy = preg_replace('/ \d{4}$/', '', $str_copy);
	$str_copy = preg_replace('/ \(CH\'\'M\)$/', '', $str_copy);
	$str_copy = preg_replace('/ \(Hoshana Raba\)$/', '', $str_copy);
	$str_copy = preg_replace('/ [IV]+$/', '', $str_copy);
	$str_copy = preg_replace('/: \d Candles?$/', '', $str_copy);
	$str_copy = preg_replace('/: 8th Day$/', '', $str_copy);
	$str_copy = preg_replace('/^Erev /', '', $str_copy);
	return hebcal_make_holiday_anchor($str_copy);
    }
}

function html_footer_new($last_updated = true) {
    $stat = stat($_SERVER["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%d %B %Y", $stat[9]);
    global $VER;

    $site_generator_div = "";
    if ($last_updated) {
	$site_generator_div = <<<EOD
<div id="site-generator">
$date (Revision: $VER)
</div><!-- #site-generator -->
EOD;
    }

    $html = <<<EOD
</div><!-- #main -->
<div id="footer" role="contentinfo">
<div id="colophon">
<div id="site-info">
<a href="http://www.hebcal.com/" title="Hebcal Jewish Calendar" rel="home">
Hebcal Jewish Calendar</a>
</div><!-- #site-info -->
$site_generator_div
</div><!-- #colophon -->
</div><!-- #footer -->
</div><!-- #wrapper -->
<script type="text/javascript">
if(document.getElementsByTagName){
var e3=document.getElementsByTagName("a");
if(e3&&e3.length){
for(var i=0;i<e3.length;i++){if(e3[i]&&e3[i].className=="amzn"){
if(e3[i].id){e3[i].onclick=function(){_gaq.push(['_trackPageview','/amzn/'+this.id]);}}
}}}
}
</script>
</body></html>
EOD;

    return $html;
}

$HTML_MENU_ITEMS =
    array(
     array( "Home", "/" ),
     array( "Calendar", "/hebcal/" ),
     array( "Holidays", "/holidays/" ),
     array( "Date Converter", "/converter/",
       array( "Hebrew/Gregorian date converter", "/converter/" ),
       array( "Yahrzeit, Birthday and Anniversary Calendar", "/yahrzeit/" ) ),
     array( "Shabbat Times", "/shabbat/", 
       array( "Candle lighting times", "/shabbat/" ),
       array( "Email List", "/email/" ),
       array( "Year at a glance", "/home/shabbat/fridge" ),
       array( "Widgets", "/home/shabbat/widgets" ) ),
     array( "Torah Readings", "/sedrot/" ),
     array( "About Hebcal", "/home/about",
       array( "About Hebcal", "/home/about" ),
       array( "Contact Us", "/home/about/contact" ),
       array( "Donate", "/home/about/donate" ),
       array( "News", "/home/category/news" ),
       array( "Privacy Policy", "/home/about/privacy-policy") ),
     array( "Help", "/home/help" ),
    );


function html_menu_item($title, $path, $selected) {
    $classes = array();
    if ($path != "/") {
	$classes[] = "page_item";
    }
    if ($path == $selected) {
	$classes[] = "current_page_item";
    }
    $str = "<li";
    if (!empty($classes)) {
	$str .= " class=\"" . implode(" ", $classes) . "\"";
    }
    $str .= "><a href=\"$path\" title=\"$title\">$title</a>";
    return $str;
}

function html_menu($selected) {
    global $HTML_MENU_ITEMS;
    $str = "<ul>";
    foreach ($HTML_MENU_ITEMS as $item) {
	$title = $item[0];
	$path = $item[1];
	$str .= html_menu_item($title, $path, $selected);
	if (isset($item[2])) {
	    $str .= "<ul class=\"children\">";
	    for ($i = 2; isset($item[$i]); $i++) {
		$str .= html_menu_item($item[$i][0], $item[$i][1], $selected);
		$str .= "</li>";
	    }
	    $str .= "</ul>";
	}
	$str .= "</li>";
    }
    $str .= "</ul>";
    return $str;
}

function html_header_new($title, $xtra_head="", $title_append_suffix=true) {
    if ($title_append_suffix) {
	$title .= " | Hebcal Jewish Calendar";
    }
    $base_href = "http://" . $_SERVER["HTTP_HOST"] . $_SERVER["REQUEST_URI"];
    $menu = html_menu($_SERVER["SCRIPT_URL"]);
    $html = <<<EOD
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html><head><title>$title</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
<base href="$base_href" target="_top">
<link rel="stylesheet" type="text/css" media="all" href="/home/wp-content/themes/twentyten/style.css">
<script type="text/javascript">
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-967247-1']);
_gaq.push(['_trackPageview']);
(function() {
var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
</script>
$xtra_head</head>
<body class="single single-post">
<div id="wrapper" class="hfeed">
<div id="header">
<div id="masthead">
<div id="branding" role="banner">
<div id="site-title"><span><a href="/" title="Hebcal Jewish Calendar" rel="home">Hebcal Jewish Calendar</a></span></div>
<div id="site-description"></div>
</div><!-- #branding -->
<div id="access" role="navigation">
<div class="skip-link screen-reader-text"><a href="#content" title="Skip to content">Skip to content</a></div>
<div class="menu">$menu</div>
</div><!-- #access -->
</div><!-- #masthead -->
</div><!-- #header -->
<div id="main">
EOD;
    return $html;
}

?>
