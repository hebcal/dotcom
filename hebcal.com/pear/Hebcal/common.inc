<?php

########################################################################
# Hebcal PHP helper functions
#
# $Id$
#
# Copyright (c) 2005  Michael J. Radwin.
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

function hebcal_gen_cookie()
{
    if (isset($_COOKIE["C"])) {
	parse_str($_COOKIE["C"], $param);
    }

    # can't use $_REQUEST or $_GET because we use ";" as string delim
    # if we controlled our own ini file, we'd set
    # arg_separator.input = "&;"
    $qs = $_SERVER["QUERY_STRING"];
    if ($qs) {
	$kvs = split('[&;]', $qs);
	foreach ($kvs as $kv) {
	    $parts = explode("=", $kv, 2);
	    $param[strip_tags(urldecode($parts[0]))] =
		strip_tags(urldecode($parts[1]));
	}
    }

    $retval = "C=t=" . time();

    # candle-lighting options
    if (isset($param["geo"])) {
	if ($param["geo"] == "zip") {
	    $retval .= "&zip=" . $param["zip"];
	    if (isset($param["dst"]) && $param["dst"] != "") {
		$retval .= "&dst=" . $param["dst"];
	    }
	    if (isset($param["tz"]) && $param["tz"] != "") {
		$retval .= "&tz=" . $param["tz"];
	    }
	} elseif ($param["geo"] == "city") {
	    $retval .= "&city=" . urlencode($param["city"]);
	} elseif ($param["geo"] == "pos") {
	    $retval .= "&lodeg=" . $param["lodeg"];
	    $retval .= "&lomin=" . $param["lomin"];
	    $retval .= "&lodir=" . $param["lodir"];
	    $retval .= "&ladeg=" . $param["ladeg"];
	    $retval .= "&lamin=" . $param["lamin"];
	    $retval .= "&ladir=" . $param["ladir"];
	    if (isset($param["dst"]) && $param["dst"] != "") {
		$retval .= "&dst=" . $param["dst"];
	    }
	    if (isset($param["tz"]) && $param["tz"] != "") {
		$retval .= "&tz=" . $param["tz"];
	    }
	}
	if (isset($param["m"]) && $param["m"] != "") {
	    $retval .= "&m=" . $param["m"];
	}
    }

    # boolean options
    $opts = array("o","s","i","a","d","D");
    foreach ($opts as $o) {
	if (isset($param[$o]) && $param[$o] != "") {
	    $retval .= "&" . $o . "=" . $param[$o];
	}
    }

    # hebcal interactive options
    if (isset($_REQUEST["v"]) && $_REQUEST["v"] == "1") {
	if (!isset($_REQUEST["nh"]) || $_REQUEST["nh"] == "off") {
	    $retval .= "&nh=off";
	}
	if (!isset($_REQUEST["nx"]) || $_REQUEST["nx"] == "off") {
	    $retval .= "&nx=off";
	}

	if (isset($param["heb"]) && $param["heb"] != "") {
	    $retval .= "&heb=" . $param["heb"];
	} else {
	    $retval .= "&heb=off";
	}
    }

    return $retval;
}

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
     "Omaha"		=>	-7,
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
    $db = mysql_pconnect("mysql.hebcal.com", "mradwin_hebcal", $password)
	or die("Could not connect: " . mysql_error());

    $sql = <<<EOD
SELECT zips_latitude, zips_longitude,
       zips_timezone, zips_dst, zips_city, zips_state
FROM hebcal1.hebcal_zips
WHERE zips_zipcode = '$zip'
EOD;

    $result = mysql_query($sql, $db)
	or die("Invalid query: " . mysql_error());

    list($latitude,$longitude,$tz,$dst,$city,$state) =
	mysql_fetch_row($result);

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
    } elseif ($str != "Candle lighting" && $str != "No sunset today." &&
	      strncmp($str, "Havdalah", 8) != 0) {
	$str_copy = $str;
	$str_copy = preg_replace('/ \(CH\'\'M\)$/', '', $str_copy);
	$str_copy = preg_replace('/ \(Hoshana Raba\)$/', '', $str_copy);
	$str_copy = preg_replace('/ [IV]+$/', '', $str_copy);
	$str_copy = preg_replace('/: \d Candles?$/', '', $str_copy);
	$str_copy = preg_replace('/: 8th Day$/', '', $str_copy);
	$str_copy = preg_replace('/^Erev /', '', $str_copy);
	return hebcal_make_holiday_anchor($str_copy);
    }
}

?>