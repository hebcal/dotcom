<?php

/***********************************************************************
 * Hebcal PHP helper functions
 *
 * Copyright (c) 2013  Michael J. Radwin.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 *  - Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer.
 *
 *  - Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **********************************************************************/

require "const.inc";

$hebcal_continents = array(
    'AF' => 'Africa',
    'AS' => 'Asia',
    'EU' => 'Europe',
    'NA' => 'North America',
    'SA' => 'South America',
    'OC' => 'Oceania',
    'AN' => 'Antarctica',
    );

$hebcal_cities_old = array(
'Ashdod' => 'IL-Ashdod',
'Atlanta' => 'US-Atlanta-GA',
'Austin' => 'US-Austin-TX',
'Baghdad' => 'IQ-Baghdad',
'Beer Sheva' => 'IL-Beer Sheva',
'Berlin' => 'DE-Berlin',
'Baltimore' => 'US-Baltimore-MD',
'Bogota' => 'CO-Bogotá',
'Boston' => 'US-Boston-MA',
'Buenos Aires' => 'AR-Buenos Aires',
'Buffalo' => 'US-Buffalo-NY',
'Chicago' => 'US-Chicago-IL',
'Cincinnati' => 'US-Cincinnati-OH',
'Cleveland' => 'US-Cleveland-OH',
'Dallas' => 'US-Dallas-TX',
'Denver' => 'US-Denver-CO',
'Detroit' => 'US-Detroit-MI',
'Eilat' => 'IL-Eilat',
'Gibraltar' => 'GI-Gibraltar',
'Haifa' => 'IL-Haifa',
'Hawaii' => 'US-Honolulu-HI',
'Houston' => 'US-Houston-TX',
'Jerusalem' => 'IL-Jerusalem',
'Johannesburg' => 'ZA-Johannesburg',
'Kiev' => 'UA-Kiev',
'La Paz' => 'BO-La Paz',
'Livingston' => 'US-Livingston-NY',
'London' => 'GB-London',
'Los Angeles' => 'US-Los Angeles-CA',
'Miami' => 'US-Miami-FL',
'Melbourne' => 'AU-Melbourne',
'Mexico City' => 'MX-Mexico City',
'Montreal' => 'CA-Montreal',
'Moscow' => 'RU-Moscow',
'New York' => 'US-New York-NY',
'Omaha' => 'US-Omaha-NE',
'Ottawa' => 'CA-Ottawa',
'Panama City' => 'PA-Panama City',
'Paris' => 'FR-Paris',
'Petach Tikvah' => 'IL-Petach Tikvah',
'Philadelphia' => 'US-Philadelphia-PA',
'Phoenix' => 'US-Phoenix-AZ',
'Pittsburgh' => 'US-Pittsburgh-PA',
'Saint Louis' => 'US-Saint Louis-MO',
'Saint Petersburg' => 'RU-Saint Petersburg',
'San Francisco' => 'US-San Francisco-CA',
'Seattle' => 'US-Seattle-WA',
'Sydney' => 'AU-Sydney',
'Tel Aviv' => 'IL-Tel Aviv',
'Tiberias' => 'IL-Tiberias',
'Toronto' => 'CA-Toronto',
'Vancouver' => 'CA-Vancouver',
'White Plains' => 'US-White Plains-NY',
'Washington DC' => 'US-Washington-DC',
);

function city_cmp($a, $b) {
    return strcmp($a[3], $b[3]);
}

function html_city_select($selected_city = false) {
    global $hebcal_cities, $hebcal_countries, $hebcal_continents;
    $retval = "<select name=\"city\" class=\"input-xlarge\">\n";
    $groups = array();
    $special_countries = array("US"=>1,"CA"=>1,"IL"=>1);
    foreach ($hebcal_cities as $id => $info) {
	$country = $info[0];
	$city = $info[1];
	$grp = isset($special_countries[$country])
	    ? $country
	    : $hebcal_countries[$country][1];
	if (!isset($groups[$grp])) {
	    $groups[$grp] = array();
	}
	$groups[$grp][] = array($id, $country, $hebcal_countries[$country][0], $city);
    }
    foreach (explode(" ", "US CA IL EU NA SA AS OC AF") as $grp) {
	$label = isset($special_countries[$grp])
	    ? $hebcal_countries[$grp][0]
	    : $hebcal_continents[$grp];
	$retval .= "<optgroup label=\"$label\">\n";
	usort($groups[$grp], "city_cmp");
	foreach ($groups[$grp] as $info) {
	    $id = $info[0];
	    $cc = $info[1];
	    $country = $info[2];
	    $city = $info[3];
	    $city_country = $city;
	    if ($cc == "US") {
		$city_country .= ", USA";
	    } elseif ($cc == "GB") {
		$city_country .= ", UK";
	    } else {
		$city_country .= ", $country";
	    }
	    $retval .= "<option";
	    if ($selected_city && $id == $selected_city) {
		$retval .= " selected";
	    }
	    $retval .= " value=\"$id\">$city_country</option>\n";
	}
	$retval .= "</optgroup>\n";
    }
    $retval .= "</select>\n";
    return $retval;
}

function hebcal_tz_names() {
    global $TIMEZONE_LIST_INIT, $TIMEZONE_ARRAY;
    if (!isset($TIMEZONE_LIST_INIT)) {
	$TIMEZONE_LIST_INIT = true;
	$TIMEZONE_ARRAY = array();
	$zone_tab = "/usr/share/zoneinfo/zone.tab";
	if (($fh = fopen($zone_tab, "r")) !== FALSE) {
	    while (($line = fgets($fh)) !== FALSE) {
		if (substr($line, 0, 1) != "#") {
		    $fields = preg_split("/\s+/", $line);
		    $TIMEZONE_ARRAY[] = $fields[2];
		}
	    }
	    fclose($fh);
	    sort($TIMEZONE_ARRAY);
	}
	array_unshift($TIMEZONE_ARRAY, "UTC");
    }
    return $TIMEZONE_ARRAY;
}

$ZIPCODES_TZ_MAP = array(
'0' => 'UTC',
'4' => 'America/Puerto_Rico',
'5' => 'America/New_York',
'6' => 'America/Chicago',
'7' => 'America/Denver',
'8' => 'America/Los_Angeles',
'9' => 'America/Anchorage',
'10' => 'Pacific/Honolulu',
'11' => 'Pacific/Pago_Pago',
'13' => 'Pacific/Funafuti',
'14' => 'Pacific/Guam',
'15' => 'Pacific/Palau',
);

function get_usa_tzid($tz,$state,$dst) {
    if (isset($state) && $state == 'AK' && $tz == 10) {
	return 'America/Adak';
    } elseif (isset($state) && $state == 'AZ' && $tz == 7) {
	if ($dst == 'Y') {
	    return 'America/Denver';
	} else {
	    return 'America/Phoenix';
	}
    } else {
	global $ZIPCODES_TZ_MAP;
	return $ZIPCODES_TZ_MAP[$tz];
    }
}

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

function hebcal_get_ini() {
    return parse_ini_file("/home/hebcal/local/etc/hebcal-dot-com.ini");
}

function hebcal_open_mysql_db() {
    global $hebcal_db;
    global $hebcal_db_open;
    global $hebcal_ini;
    if (!isset($hebcal_db_open)) {
	$hebcal_ini = hebcal_get_ini();
	$dbpass = $hebcal_ini["hebcal.mysql.password"];
	$dbhost = $hebcal_ini["hebcal.mysql.host"];
	$dbuser = $hebcal_ini["hebcal.mysql.user"];
	$dbname = $hebcal_ini["hebcal.mysql.dbname"];
	$hebcal_db = mysql_pconnect($dbhost, $dbuser, $dbpass);
	if (!$hebcal_db) {
	    error_log("Could not connect: " . mysql_error());
	    die();
	}
	if (!mysql_select_db($dbname, $hebcal_db)) {
	    error_log("Could not USE $dbname: " . mysql_error());
	    die();
	}
	$hebcal_db_open = true;
    }
    return true;
}

function hebcal_get_zipcode_fields($zip) {
    $file = $_SERVER["DOCUMENT_ROOT"] . "/hebcal/zips.sqlite3";
    $db = new SQLite3($file);
    if (!$db) {
	error_log("Could not open SQLite3 $file");
	die();
    }

    $sql = <<<EOD
SELECT CityMixedCase,State,Latitude,Longitude,TimeZone,DayLightSaving
FROM ZIPCodes_Primary
WHERE ZipCode = '$zip'
EOD;

    $query = $db->query($sql); 
    if (!$query) {
	error_log("Loading zip $zip from $file: " . $db->lastErrorMsg());
	die();
    }

    list($city,$state,$latitude,$longitude,$TimeZone,$DayLightSaving) =
	$query->fetchArray(SQLITE3_NUM);

    // clean up
    unset($query);
    $db->close();
    unset($db);

    if (!$state)  {
	return null;
    }

    $tzid = get_usa_tzid($TimeZone,$state,$DayLightSaving);

    // remove any prefixed + signs from the strings
    $latitude = preg_replace('/^\+/', "", $latitude);
    $longitude = preg_replace('/^\+/', "", $longitude);

    // in hebcal, negative longitudes are EAST (this is backwards)
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

    return array($city,$state,$tzid,$latitude,$longitude,
		 $lat_deg,$lat_min,$long_deg,$long_min);
}

function hebcal_make_holiday_anchor($str)
{
    $anchor = strtolower($str);
    $anchor = preg_replace('/\'/',	'', $anchor);
    $anchor = preg_replace('/[^\w]/',	'-', $anchor);
    $anchor = preg_replace('/-+/',	'-', $anchor);
    $anchor = preg_replace('/^-/',	'', $anchor);
    $anchor = preg_replace('/-$/',	'', $anchor);

    return "/holidays/$anchor";
}

function hebcal_make_sedra_anchor($str)
{
    $anchor = strtolower($str);
    $anchor = preg_replace('/[^\w]/',	'', $anchor);

    return "/sedrot/$anchor";
}

function hebcal_make_anchor($str)
{
    if (strncmp($str, "Parashat", 8) == 0) {
	return hebcal_make_sedra_anchor(substr($str, 9));
    } elseif (strncmp($str, "Parshas", 7) == 0) {
	return hebcal_make_sedra_anchor(substr($str, 8));
    } elseif (preg_match('/^\d+\w+ day of the Omer$/', $str)) {
	return "/holidays/days-of-the-omer";
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

$HTML_MENU_ITEMS_V2 =
    array(
	array( "/holidays/",	"Holidays",	"Jewish Holidays" ),
	array( "/converter/",	"Date Converter", "Hebrew Date Converter" ),
	array( "/shabbat/",	"Shabbat",	"Shabbat Times" ),
	array( "/sedrot/",	"Torah",	"Torah Readings" ),
	array( "/home/about",	"About",	"About" ),
	array( "/home/help",	"Help",		"Help" ),
    );

function html_menu_item_bootstrap($path, $title, $tooltip, $selected) {
    $class = false;
    if ($path != "/" && $path == $selected) {
	$class = "active";
    }
    $str = "<li";
    if ($class !== false) {
	$str .= " class=\"$class\"";
    }
    $str .= "><a href=\"$path\" title=\"$tooltip\">$title</a>";
    return $str;
}


function html_menu_bootstrap($selected) {
    global $HTML_MENU_ITEMS_V2;
    $str = "<ul class=\"nav\">";
    foreach ($HTML_MENU_ITEMS_V2 as $item) {
	$path = $item[0];
	$title = $item[1];
	$tooltip = $item[2];
	if (isset($item[3])) {
	    $str .= "<li class=\"dropdown\">";
	    $str .= "<a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\">$title <b class=\"caret\"></b></a>";
	    $str .= "<ul class=\"dropdown-menu\">";
	    for ($i = 3; isset($item[$i]); $i++) {
		$str .= html_menu_item_bootstrap($item[$i][0], $item[$i][1], $item[$i][2], $selected);
		$str .= "</li>";
	    }
	    $str .= "</ul>";
	} else {
	    $str .= html_menu_item_bootstrap($path, $title, $tooltip, $selected);
	}
	$str .= "</li>";
    }
    $str .= "</ul>";
    return $str;
}

function html_header_bootstrap($title, $xtra_head="", $title_append_suffix=true, $hebrew_stylesheet=false) {
    if ($title_append_suffix) {
	$title .= " | Hebcal Jewish Calendar";
    }
    $self = $_SERVER["PHP_SELF"];
    $pos = strpos($self, "index.php");
    if ($pos !== false) {
	$self = substr($self, 0, $pos);
    }
    $menu = html_menu_bootstrap($self);

    if ($self == "/") {
	$logo = '<span class="brand" id="logo" title="Hebcal Jewish Calendar">Hebcal</span>';
    } else {
	$logo = '<a class="brand" id="logo" title="Hebcal Jewish Calendar" href="/">Hebcal</a>';
    }

    $xtra_stylesheet = $hebrew_stylesheet
	? "<link rel=\"stylesheet\" type=\"text/css\" href=\"http://fonts.googleapis.com/earlyaccess/alefhebrew.css\">\n"
	: "";

    $html = <<<EOD
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="/i/bootstrap-2.3.1/css/bootstrap.min.css" media="all">
<link rel="stylesheet" type="text/css" id="bootstrap-responsive-css" href="/i/bootstrap-2.3.1/css/bootstrap-responsive.min.css" media="all">
$xtra_stylesheet<script type="text/javascript">
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-967247-1']);
_gaq.push(['_trackPageview']);
(function() {
var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
</script>
<style type="text/css">
.navbar{position:static}
body{padding-top:0}
.label{text-transform:none}
:lang(he) {
  font-family:'Alef Hebrew','SBL Hebrew',David,serif;
  font-size:125%;
  direction:rtl;
}
@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
}
</style>
$xtra_head</head>
<body>

<div class="navbar navbar-fixed-top">
  <div class="navbar-inner">
    <div class="container-fluid nav-container">
     <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
      <span class="icon-bar"></span>
      <span class="icon-bar"></span>
      <span class="icon-bar"></span>
     </a>
     $logo
     <div class="nav-collapse collapse">
     $menu
     <form class="navbar-search pull-right" role="search" method="get" id="searchform" action="/home/">
     <input name="s" id="s" type="text" class="search-query" placeholder="Search">
     </form>
     </div><!-- .nav-collapse -->
    </div><!-- .container -->
   </div><!-- .navbar-inner -->
</div><!-- .navbar -->

<div class="container">
<div id="content" class="clearfix row-fluid">
EOD;
    return $html;
}

function html_footer_bootstrap($last_updated = true) {
    $last_updated_text = "";
    if ($last_updated) {
	$stat = stat($_SERVER["SCRIPT_FILENAME"]);
	$last_updated_text = "<p><time datetime=\""
	    . date("c", $stat[9]) . "\">"
	    . date("j F Y", $stat[9]). "</time>"
	    . "</p>";
    }

    $html = <<<EOD
</div><!-- #content -->

<footer role="contentinfo">
<hr>
<div id="inner-footer" class="clearfix">
<div class="row-fluid">
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">Products</li>
<li><a href="/holidays/">Jewish Holidays</a></li>
<li><a href="/converter/">Hebrew Date Converter</a></li>
<li><a href="/shabbat/">Shabbat Times</a></li>
<li><a href="/sedrot/">Torah Readings</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">About Us</li>
<li><a href="/home/about">About Hebcal</a></li>
<li><a href="/home/category/news">News</a></li>
<li><a href="/home/about/privacy-policy">Privacy Policy</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">Connect</li>
<li><a href="/home/help">Help</a></li>
<li><a href="/home/about/contact">Contact Us</a></li>
<li><a href="/home/about/donate">Donate</a></li>
<li><a href="/home/developer-apis">Developer APIs</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
$last_updated_text
<p><small>Except where otherwise noted, content on this site is licensed under a <a
rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative Commons Attribution 3.0 License</a>.</small></p>
</div><!-- .span3 -->
</div><!-- .row-fluid -->
</div><!-- #inner-footer -->
</footer>
</div> <!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
<script src="/i/bootstrap-2.3.1/js/bootstrap.min.js"></script>

<script type="text/javascript">
(function(){if(document.getElementsByTagName){var b=document.getElementsByTagName("a");if(b&&b.length){for(var a=0;a<b.length;a++){if(b[a]&&b[a].className=="amzn"){if(b[a].id){b[a].onclick=function(){_gaq.push(["_trackEvent","outbound-amzn",this.id])}}}
if(b[a]&&b[a].className=="outbound"){b[a].onclick=function(){var c=this.href;if(c&&c.indexOf("http://")===0){var d=c.indexOf("/",7);if(d>7){_gaq.push(["_trackEvent","outbound-article",c.substring(7,d)])}}}}
if(b[a]&&b[a].className.indexOf("download")!=-1){if(b[a].id){b[a].onclick=function(){_gaq.push(["_trackEvent","download",this.id])}}}}}}})();
</script>
</body></html>
EOD;

    return $html;
}

function get_saturday($gy, $gm, $gd) {
    $timestamp = mktime(12, 34, 56, $gm, $gd, $gy);
    $wday = date("w", $timestamp);
    if ($wday == 6) {
	return array($gy, $gm, $gd);
    } else {
	$sat_timestamp = $timestamp + ((6 - $wday) * 60 * 60 * 24);
	return array(date("Y", $sat_timestamp),
		     date("n", $sat_timestamp),
		     date("j", $sat_timestamp));
    }
}

// borrowed from HTML/Form.php from PHP 4
// under version 2.0 of the PHP license
//
// $Id: Form.php,v 1.2 2003/02/14 11:12:08 mj Exp $
//
// HTML form utility functions.

function html_form_select($name, $entries, $default = '', $size = 1,
			  $blank = '', $multiple = false, $attrib = '')
{
    if ($multiple && substr($name, -2) != "[]") {
	$name .= "[]";
    }
    $str = "   <select name=\"$name\"";
    if ($size) {
	$str .= " size=\"$size\"";
    }
    if ($multiple) {
	$str .= " multiple=\"multiple\"";
    }
    if ($attrib) {
	$str .= " $attrib";
    }
    $str .= ">\n";
    if ($blank) {
	$str .= "    <option value=\"\">$blank</option>\n";
    }
    while (list($val, $text) = each($entries)) {
	$str .= '    <option ';
	if ($default) {
	    if ($multiple && is_array($default)) {
		if ((is_string(key($default)) && $default[$val]) ||
		    (is_int(key($default)) && in_array($val, $default))) {
		    $str .= 'selected="selected" ';
		}
	    } elseif ($default == $val) {
		$str .= 'selected="selected" ';
	    }
	}
	$str .= "value=\"$val\">$text</option>\n";
    }
    $str .= "   </select>\n";

    return $str;
}

?>
