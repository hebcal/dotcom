<?php
# $Id$
# $URL$

require "../pear/Hebcal/common.inc";

function cache_comment($cfg, $status) {
    if ($cfg == "j" || $cfg == "json") {
	echo "// cache ", $status, "\n";
    } else {
	echo "<!-- cache ", $status, " -->\n";
    }
}

$qs = $_SERVER["QUERY_STRING"];
$matches = array();
if ($qs && preg_match('/\bcfg=([^;&]+)/', $qs, $matches)) {
    $cfg = $matches[1];
} else {
    $cfg = "";
}

if ($cfg == "j") {
    header("Content-Type: application/x-javascript");
} elseif ($cfg == "json") {
    header("Content-Type: text/json; charset=UTF-8");
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

$url = "http://www.hebcal.com/shabbat/shabbat.cgi";
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
	$newck = hebcal_gen_cookie();
	if (isset($_COOKIE["C"])) {
	    $oldck = "C=" . strtr($_COOKIE["C"], " ", "+");
	} else {
	    $oldck = "C=t=0&z=0";
	}
	$cmp1 = strchr($newck, "&");
	$cmp2 = strchr($oldck, "&");
	if ($cmp1 != $cmp2) {
	    header("Cache-Control: private");
	    header("Set-Cookie: " . $newck .
		   "; path=/; expires=Tue, 02-Jun-2037 20:00:00 GMT");
	}
    }

    $url .= "?$qs";
    $qs = preg_replace('/[&;]?(tag|set)=[^&;]+/', "", $qs);
    $qs = preg_replace('/[&;]?\.(from|cgifields|s)=[^&;]+/', "", $qs);
    $qs = strtr($qs, "&;./", ",,_-");
    $qs = str_replace("%20", "+", $qs);
    $dir = $_SERVER["DOCUMENT_ROOT"] . "/cache/shabbat/shabbat_cgi";
    $cachefile = "$dir/$qs";
    if (file_exists($cachefile) && filesize($cachefile) > 0) {
	$status = @readfile($cachefile);
    } else {
	$status = false;
    }
} else {
    $status = false;
}
if (!$status) {
    $ch = curl_init($url);
    curl_exec($ch);
    curl_close($ch);
    cache_comment($cfg, "miss");
} else {
    cache_comment($cfg, "hit");
}
exit();
?>
