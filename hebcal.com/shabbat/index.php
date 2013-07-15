<?php
/***********************************************************************
 * Shabbat poor man's cache
 *
 * Copyright (c) 2013  Michael J. Radwin.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 *  * Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer.
 *
 *  * Redistributions in binary form must reproduce the above
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

require "../pear/Hebcal/common.inc";

function cache_comment($cfg, $status) {
    global $qs;
    if ($cfg == "json") {
	// json comments not supported
    } elseif ($cfg == "j") {
	echo "// cache $status ($qs)\n";
    } else {
	echo "<!-- cache $status ($qs) -->\n";
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

$url = "http://" . $_SERVER["HTTP_HOST"] . "/shabbat/shabbat.cgi";
if ($qs) {
    $now = time();
    $lt = localtime($now);
    $wday = $lt[6];
    $saturday = ($wday == 6) ? $now + (60 * 60 * 24) :
	$now + ((6 - $wday) * 60 * 60 * 24);
    header("Expires: ". gmdate("D, d M Y H:i:s", $saturday). " GMT");

    if (isset($private)) {
	header("Cache-Control: private");
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
