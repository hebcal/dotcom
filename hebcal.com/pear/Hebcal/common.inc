<?php

/***********************************************************************
 * Hebcal PHP helper functions
 *
 * Copyright (c) 2019  Michael J. Radwin.
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

function hebcal_city_to_geoname($city) {
    global $hebcal_cities2;
    global $hebcal_cities_old;
    $city = trim($city);
    if (isset($hebcal_cities_old[$city])) {
        $city = $hebcal_cities_old[$city];
    }
    if (isset($hebcal_cities2[$city])) {
        return $hebcal_cities2[$city];
    }
    return false;
}

function city_cmp($a, $b) {
    return strcmp($a[3], $b[3]);
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

function hebcal_set_timezone_lang() {
    $cc = false;
    $default_lg = 's';
    if (isset($_SERVER['MM_COUNTRY_CODE'])) {
        $cc = $_SERVER['MM_COUNTRY_CODE'];
        $cc_defaults = [
            'US' => ['s', 'America/New_York'],
            'IL' => ['h', 'Asia/Jerusalem'],
            'GB' => ['s', 'Europe/London'],
            'CA' => ['s', 'America/Toronto'],
            'AU' => ['s', 'Australia/Sydney'],
            'ZA' => ['s', 'Africa/Johannesburg'],
            'BR' => ['s', 'America/Sao_Paulo'],
            'FR' => ['fr', 'Europe/Paris'],
            'RU' => ['ru', 'Europe/Moscow'],
            'PL' => ['pl', 'Europe/Warsaw'],
            'FI' => ['fi', 'Europe/Helsinki'],
        ];
        if (isset($cc_defaults[$cc])) {
            $ccinfo = $cc_defaults[$cc];
            $default_lg = $ccinfo[0];
            date_default_timezone_set($ccinfo[1]);
        }
    }
    return array($cc, $default_lg);
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
$hmstr_to_num["Adar"] = 6;

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
    "Adar" => "Adar",
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
    if (strncmp("Adar", $hm, 4) == 0 && !is_leap_year($hy)) {
	$month_name = "Adar";
    } else {
	$month_name = $hmstr_to_hebcal[$hm];
    }

    return numsuffix($hd) . " of " . $month_name . ", $hy";
}

function hebcal_get_ini() {
    return parse_ini_file("/home/hebcal/local/etc/hebcal-dot-com.ini");
}

function hebcal_open_mysqli_db() {
    global $hebcal_db;
    global $hebcal_db_open;
    if (!isset($hebcal_db_open)) {
	$hebcal_ini = hebcal_get_ini();
	$dbpass = $hebcal_ini["hebcal.mysql.password"];
	$dbhost = $hebcal_ini["hebcal.mysql.host"];
	$dbuser = $hebcal_ini["hebcal.mysql.user"];
	$dbname = $hebcal_ini["hebcal.mysql.dbname"];
	$hebcal_db = mysqli_connect($dbhost, $dbuser, $dbpass, $dbname);
        if (mysqli_connect_errno($hebcal_db)) {
            error_log("Failed to connect to MySQL: " . mysqli_connect_error());
	    die();
	}
	$hebcal_db_open = true;
    }
    return $hebcal_db;
}

function geoname_city_descr($name,$admin1,$country) {
    $city_descr = $name;
    if ($admin1 && strncmp($name, $admin1, strlen($name)) != 0) {
        $city_descr .= ", $admin1";
    }
    if ($country) {
        $city_descr .= ", $country";
    }
    return $city_descr;
}

function hebcal_get_geoname($geonameid) {
    $file = $_SERVER["DOCUMENT_ROOT"] . "/hebcal/geonames.sqlite3";
    $db = new SQLite3($file);
    if (!$db) {
	error_log("Could not open SQLite3 $file");
	die();
    }

    $sql = <<<EOD
SELECT g.name, g.asciiname, c.country, a.name, g.latitude, g.longitude, g.timezone
FROM geoname g
LEFT JOIN country c on g.country = c.iso
LEFT JOIN admin1 a on g.country||'.'||g.admin1 = a.key
WHERE g.geonameid = '$geonameid'
EOD;

    $query = $db->query($sql);
    if (!$query) {
	error_log("Loading geonameid $geonameid from $file: " . $db->lastErrorMsg());
	die();
    }

    $result = $query->fetchArray(SQLITE3_NUM);

    // clean up
    unset($query);
    $db->close();
    unset($db);

    if (!$result[0])  {
	return null;
    }

    return $result;
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
    $str = "<li class=\"nav-item";
    if ($class !== false) {
	$str .= " $class";
    }
    $str .= "\"><a class=\"nav-link\" href=\"$path\" title=\"$tooltip\">$title</a>";
    return $str;
}

function html_menu_bootstrap3($selected) {
    global $HTML_MENU_ITEMS_V2;
    $str = "<ul class=\"navbar-nav mr-auto\">";
    foreach ($HTML_MENU_ITEMS_V2 as $item) {
        $path = $item[0];
        $title = $item[1];
        $tooltip = $item[2];
        if (isset($item[3])) {
            $str .= "<li class=\"nav-item dropdown\">";
            $str .= "<a href=\"#\" class=\"nav-link dropdown-toggle\" data-toggle=\"dropdown\">$title <span class=\"caret\"></span></a>";
            $str .= "<div class=\"dropdown-menu\" role=\"menu\">";
            for ($i = 3; isset($item[$i]); $i++) {
                $str .= html_menu_item_bootstrap($item[$i][0], $item[$i][1], $item[$i][2], $selected);
                $str .= "</li>";
            }
            $str .= "</div>";
        } else {
            $str .= html_menu_item_bootstrap($path, $title, $tooltip, $selected);
        }
        $str .= "</li>";
    }
    $str .= "</ul>";
    return $str;
}

function html_header_bootstrap3($title, $xtra_head="", $title_append_suffix=true, $hebrew_stylesheet=false) {
    if ($title_append_suffix) {
        $title .= " | Hebcal Jewish Calendar";
    }
    $self = $_SERVER["PHP_SELF"];
    $pos = strpos($self, "index.php");
    if ($pos !== false) {
        $self = substr($self, 0, $pos);
    }
    $menu = html_menu_bootstrap3($self);
    $logoImage = '<img src="/i/hebcal-logo-1.2.svg" width="77" height="21" alt="Hebcal">';
    $logoIdClassTitle = 'class="navbar-brand" id="logo" title="Hebcal Jewish Calendar"';
    if ($self == "/") {
        $logo = '<span ' . $logoIdClassTitle . '>' . $logoImage . '</span>';
    } else {
        $logo = '<a href="/" ' . $logoIdClassTitle . '>' . $logoImage . '</a>';
    }

    $alef_stylesheet = <<<EOD
<script>
  WebFontConfig = {
    google: { families: [ 'Alef' ] }
  };
  (function(d) {
    var wf = d.createElement('script'), s = d.scripts[0];
    wf.src = 'https://ajax.googleapis.com/ajax/libs/webfont/1.6.26/webfont.js';
    wf.async = true;
    s.parentNode.insertBefore(wf, s);
  })(document);
</script>
EOD;
    $xtra_stylesheet = $hebrew_stylesheet
        ? $alef_stylesheet
        : "";

    $html = <<<EOD
<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8">
<title>$title</title>
<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
<link rel="stylesheet" href="/i/bootstrap-4.2.1/css/bootstrap.min.css">
$xtra_stylesheet<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  ga('create', 'UA-967247-1', 'auto');
  ga('set', 'anonymizeIp', true);
  ga('send', 'pageview');
</script>
<style>
.hebcal-footer {
  padding-top: 40px;
  padding-bottom: 40px;
  margin-top: 40px;
  color: #777;
  text-align: center;
  border-top: 1px solid #e5e5e5;
}
.hebcal-footer p {
  margin-bottom: 2px;
}
.bullet-list-inline {
  padding-left: 0;
  margin-left: -3px;
  list-style: none;
}
.bullet-list-inline > li {
  display: inline-block;
  padding-right: 3px;
  padding-left: 3px;
}
.bullet-list-inline li:after{content:"\\00a0\\00a0\\00b7"}
.bullet-list-inline li:last-child:after{content:""}
.label{text-transform:none}
:lang(he) {
  font-family:'Alef','SBL Hebrew',David,serif;
  font-size:125%;
  direction:rtl;
}
@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
}
@media (min-width: 768px) {
  input#sitesearch {
    width: 132px;
  }
}
@font-face{font-family:'Glyphicons Regular';src:url('/i/glyphicons_pro_1.9.2/fonts/glyphicons-regular.eot');src:url('/i/glyphicons_pro_1.9.2/fonts/glyphicons-regular.eot?#iefix')format('embedded-opentype'),url('/i/glyphicons_pro_1.9.2/fonts/glyphicons-regular.woff')format('woff'),url('/i/glyphicons_pro_1.9.2/fonts/glyphicons-regular.ttf')format('truetype'),url('/i/glyphicons_pro_1.9.2/fonts/glyphicons-regular.svg#glyphiconsregular')format('svg');font-weight:normal;font-style:normal;}.glyphicons{position:relative;top:1px;display:inline-block;font-family:'Glyphicons Regular';font-style:normal;font-weight:400;line-height:1;-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale;}.glyphicons.glyphicons-copy:before{content:"\E512";}.glyphicons.glyphicons-volume-up:before{content:"\E185";}.glyphicons.glyphicons-pencil:before{content:"\E031";}.glyphicons.glyphicons-list:before{content:"\E115";}.glyphicons.glyphicons-cog:before{content:"\E137";}.glyphicons.glyphicons-info-sign:before{content:"\E196";}.glyphicons.glyphicons-wrench:before{content:"\E440";}.glyphicons.glyphicons-print:before{content:"\E016";}.glyphicons.glyphicons-calendar:before{content:"\E046";}.glyphicons.glyphicons-download-alt:before{content:"\E182";}.glyphicons.glyphicons-envelope:before{content:"\E011";}.glyphicons.glyphicons-refresh:before{content:"\E082";}.glyphicons.glyphicons-candle:before{content:"\E335";}.glyphicons.glyphicons-book_open:before{content:"\E352";}.glyphicons.glyphicons-parents:before{content:"\E025";}.glyphicons.glyphicons-cogwheels:before{content:"\E138";}.glyphicons.glyphicons-settings:before{content:"\E281";}.glyphicons.glyphicons-embed-close:before{content:"\E119";}.glyphicons.glyphicons-git-branch:before{content:"\E423";}
</style>
$xtra_head</head>
<body>
<nav class="navbar navbar-expand-lg navbar-light bg-light">
  $logo
  <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
    <span class="navbar-toggler-icon"></span>
  </button>
  <div class="collapse navbar-collapse" id="navbarSupportedContent">
    $menu
    <form class="form-inline my-2 my-lg-0" role="search" method="get" id="searchform" action="/home/">
     <input name="s" id="sitesearch" type="text" class="form-control mr-sm-2" placeholder="Search" aria-label="Search">
    </form>
  </div><!--/.navbar-collapse -->
</nav>

<div class="container">
<div id="content">
EOD;
    return $html;
}

function html_footer_bootstrap3($last_updated = true, $xtra_html = "") {
    $last_updated_text = "";
    if ($last_updated) {
        $stat = stat($_SERVER["SCRIPT_FILENAME"]);
        $last_updated_text = "<li><time datetime=\""
            . date("c", $stat[9]) . "\">"
            . date("j F Y", $stat[9]). "</time></li>";
    }

    $html = <<<EOD
</div><!-- #content -->

<footer class="hebcal-footer d-print-none">
<div class="row">
<div class="col-sm-12">
<p><small>Except where otherwise noted, content on this site is licensed under a <a
rel="license" href="https://creativecommons.org/licenses/by/3.0/deed.en_US">Creative Commons Attribution 3.0 License</a>.</small></p>
<p><small>Some location data comes from <a href="http://www.geonames.org/">GeoNames</a>,
also under a cc-by license.</small></p>
<ul class="bullet-list-inline">
$last_updated_text
<li><a href="/home/about">About</a></li>
<li><a href="/home/about/privacy-policy">Privacy</a></li>
<li><a href="/home/help">Help</a></li>
<li><a href="/home/about/contact">Contact</a></li>
<li><a href="/home/developer-apis">Developer APIs</a></li>
</ul>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
</footer>
</div> <!-- .container -->

<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js"></script>
<script src="/i/bootstrap-4.2.1/js/bootstrap.bundle.min.js"></script>
$xtra_html
<script>
$(document).ready(function(){
  $('a.amzn').click(function(){
    var x = $(this).attr('id');
    if (x) {
      ga('send','event','outbound-amzn',x);
    }
  });
  $('a.outbound').click(function(){
    var c=$(this).attr('href');
    if (c&&c.length) {
      var ss=c.indexOf('//');
      if(ss!=-1) {
        var d=c.indexOf('/',ss+2),d2=d!=-1?d:c.length;
        ga('send','event','outbound-article',c.substring(ss+2,d2));
      }
    }
  });
  $('a.download').click(function(){
    var x = $(this).attr('id');
    if (x) {
      ga('send','event','download',x);
    }
  });
});
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

function hebcal_js_app_url() {
    return "/i/hebcal-app-1.8.min.js";
}

function hebcal_js_typeahead_bundle_url() {
    return "//cdnjs.cloudflare.com/ajax/libs/typeahead.js/0.10.4/typeahead.bundle.min.js";
}

?>
