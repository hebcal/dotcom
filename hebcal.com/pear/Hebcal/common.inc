<?php

/*
 * Hebcal PHP helper functions
 *
 * $Id$
 *
 * Copyright (c) 2012  Michael J. Radwin.
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
 *  - Neither the name of Hebcal.com nor the names of its
 *    contributors may be used to endorse or promote products
 *    derived from this software without specific prior written
 *    permission.
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
     array( "Services", "#",
       array( "Jewish Holidays", "/holidays/" ),
       array( "Custom Calendar", "/hebcal/" ),
       array( "Hebrew Date Converter", "/converter/" ),
       array( "Yahrzeit + Anniversary Calendar", "/yahrzeit/" ),
       array( "Shabbat Times", "/shabbat/" ),
	    array( "Torah Readings", "/sedrot/" )),
     array( "About", "/home/about",
       array( "About Hebcal", "/home/about" ),
       array( "Contact Us", "/home/about/contact" ),
       array( "Donate", "/home/about/donate" ),
       array( "News", "/home/category/news" ),
       array( "Privacy Policy", "/home/about/privacy-policy") ),
     array( "Help", "/home/help" ),
    );

function html_menu_item_bootstrap($title, $path, $selected) {
    $class = false;
    if ($path != "/" && $path == $selected) {
	$class = "active";
    }
    $str = "<li";
    if ($class !== false) {
	$str .= " class=\"$class\"";
    }
    $str .= "><a href=\"$path\" title=\"$title\">$title</a>";
    return $str;
}


function html_menu_bootstrap($selected) {
    global $HTML_MENU_ITEMS_V2;
    $str = "<ul class=\"nav\">";
    foreach ($HTML_MENU_ITEMS_V2 as $item) {
	$title = $item[0];
	$path = $item[1];
	if (isset($item[2])) {
	    $str .= "<li class=\"dropdown\">";
	    $str .= "<a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\">$title <b class=\"caret\"></b></a>";
	    $str .= "<ul class=\"dropdown-menu\">";
	    for ($i = 2; isset($item[$i]); $i++) {
		$str .= html_menu_item_bootstrap($item[$i][0], $item[$i][1], $selected);
		$str .= "</li>";
	    }
	    $str .= "</ul>";
	} else {
	    $str .= html_menu_item_bootstrap($title, $path, $selected);
	}
	$str .= "</li>";
    }
    $str .= "</ul>";
    return $str;
}

function html_header_bootstrap($title, $xtra_head="", $title_append_suffix=true) {
    if ($title_append_suffix) {
	$title .= " | Hebcal Jewish Calendar";
    }
    $base_href = "http://" . $_SERVER["HTTP_HOST"] . $_SERVER["REQUEST_URI"];
    $base_href = preg_replace('/&/', '&amp;', $base_href);
    $menu = html_menu_bootstrap($_SERVER["SCRIPT_URL"]);
    $html = <<<EOD
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<base href="$base_href" target="_top">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="/bootstrap/css/bootstrap.min.css" media="all">
<link rel="stylesheet" type="text/css" id="bootstrap-responsive-css" href="/bootstrap/css/bootstrap-responsive.min.css" media="all">
<link rel="stylesheet" type="text/css" id="wp-bootstrap-css" href="/bootstrap/css/wordpress-bootstrap.min.css" media="all">
<script type="text/javascript">
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-967247-1']);
_gaq.push(['_trackPageview']);
_gaq.push(['_trackPageLoadTime']);
(function() {
var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
</script>
<style type="text/css">
.hebrew {font-family:'SBL Hebrew',Arial;direction:rtl}
</style>
$xtra_head</head>
<body>

<div class="navbar">
  <div class="navbar-inner">
    <div class="container">
     <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
      <span class="icon-bar"></span>
      <span class="icon-bar"></span>
      <span class="icon-bar"></span>
     </a>
     <a class="brand" id="logo" title="Hebcal Jewish Calendar" href="/">Hebcal</a>
     <div class="nav-collapse collapse">
     $menu
     <form class="navbar-form pull-right" role="search" method="get" id="searchform" action="/home/">
   <fieldset>
   <div class="input-append input-prepend">
   <span class="add-on"><i class="icon-search"></i></span><input class="input-medium" type="text" name="s"><button type="submit" class="btn btn-primary">Search</button></div>
   </fieldset>
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
	$year = strftime("%Y", time());
	$date = strftime("%d %B %Y", $stat[9]);
	global $VER;
	$last_updated_text = "<p>$date <small class=\"muted\">Revision: $VER</small></p>";
    }

    $html = <<<EOD
</div><!-- #content -->

<footer role="contentinfo">
<hr>
<div id="inner-footer" class="clearfix row">
<div class="span5">
<p><a href="/">Hebcal Jewish Calendar</a></p>
<iframe src="//www.facebook.com/plugins/like.php?app_id=205907769446397&amp;href=http%3A%2F%2Fwww.facebook.com%2Fhebcal&amp;send=false&amp;layout=standard&amp;width=360&amp;show_faces=false&amp;font&amp;colorscheme=light&amp;action=like&amp;height=35" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:360px; height:35px;" allowTransparency="true"></iframe>
</div>
<div class="span4 offset3">
$last_updated_text
<p><small>Except where otherwise noted, content on
<span xmlns:cc="http://creativecommons.org/ns#" property="cc:attributionName">this site</span>
is licensed under a 
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative
Commons Attribution 3.0 License</a>.</small></p>
</div>
</div><!-- #inner-footer -->
</footer>
</div> <!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.3/jquery.min.js"></script>
<script src="/bootstrap/js/bootstrap.min.js"></script>

<script type="text/javascript">
function tvis(b){var a=document.getElementById(b);if(a.style.display=="block"){a.style.display="none"}else{a.style.display="block"}return false}(function(){if(document.getElementsByTagName){var b=document.getElementsByTagName("a");if(b&&b.length){for(var a=0;a<b.length;a++){if(b[a]&&b[a].className=="amzn"){if(b[a].id){b[a].onclick=function(){_gaq.push(["_trackEvent","outbound-amzn",this.id])}}}if(b[a]&&b[a].className=="outbound"){b[a].onclick=function(){var c=this.href;if(c&&c.indexOf("http://")===0){var d=c.indexOf("/",7);if(d>7){_gaq.push(["_trackEvent","outbound-article",c.substring(7,d)])}}}}if(b[a]&&b[a].className=="download"){if(b[a].id){b[a].onclick=function(){_gaq.push(["_trackEvent","download",this.id])}}}if(b[a]&&b[a].className=="dlhead"){if(b[a].id){b[a].onclick=function(){return tvis(this.id+"-body")}}}}}}})();
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

?>
