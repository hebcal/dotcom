<?php
# $Id$
# $Source: /Users/mradwin/hebcal-copy/hebcal.com/shabbat/RCS/index.php,v $

require "../common.inc";

$qs = $_SERVER["QUERY_STRING"];
$matches = array();
if ($qs && preg_match('/\bcfg=([a-z])/', $qs, $matches)) {
    $cfg = $matches[1];
} else {
    $cfg = "";
}

if ($cfg == "j") {
    header("Content-Type: application/x-javascript");
} elseif ($cfg == "r" ) {
    header("Content-Type: text/xml");
} elseif ($cfg == "w") {
    header("Content-Type: text/vnd.wap.wml");
} else {
    header("Content-Type: text/html; charset=UTF-8");
}

if (!$qs && isset($_COOKIE["C"])) {
    parse_str($_COOKIE["C"], $ck);
    if (isset($ck["city"])) {
	$private = true;
	$qs = "geo=city&city=" . urlencode($ck["city"]);
	if (isset($ck["m"]) && is_numeric($ck["m"])) {
	    $qs .= "&m=" . $ck["m"];
	}
    } elseif (isset($ck["zip"]) && is_numeric($ck["zip"])) {
	$private = true;
	$qs = "geo=zip&zip=" . $ck["zip"];
	if (isset($ck["m"]) && is_numeric($ck["m"])) {
	    $qs .= "&m=" . $ck["m"];
	}
    }
}

$url = "/shabbat/shabbat.cgi";
if ($qs) {
    $now = time();
    $lt = localtime($now);
    $wday = $lt[6];
    $saturday = ($wday == 6) ? $now + (60 * 60 * 24) :
	$now + ((6 - $wday) * 60 * 60 * 24);
    header("Expires: ". gmdate("D, d M Y H:i:s", $saturday). " GMT");

    if ($private) {
	header("Cache-Control: private");
    } elseif (!$cfg) {
	header("Cache-Control: private");
	header("Set-Cookie: " . hebcal_gen_cookie() .
	       "; expires=Tue, 02-Jun-2037 20:00:00 GMT; path=/");
    }

    $url .= "?$qs";
    $cqs = preg_replace('/[&;]?tag=[^&;]+/', "", $qs);
    $cqs = preg_replace('/[&;]?\.from=[^&;]+/', "", $cqs);
    $cqs = strtr($cqs, "&;./", ",,_-");
    $cqs = str_replace("%20", "+", $cqs);
    $dir = $_SERVER["DOCUMENT_ROOT"] . "/cache/shabbat/shabbat_cgi";
    $status = @readfile("$dir/$cqs");
} else {
    $status = false;
}
if (!$status) {
    virtual($url);
}
exit();
?>