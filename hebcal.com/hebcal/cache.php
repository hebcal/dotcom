<?php
# $Id: index.php,v 1.5 2005/01/23 17:02:56 mradwin Exp $
# $Source: /home/mradwin/web/hebcal.com/shabbat/RCS/index.php,v $

$qs = $_SERVER["QUERY_STRING"];
$pi = $_SERVER["PATH_INFO"];

if (!$qs && !$pi && !isset($_COOKIE["C"])) {
    readfile("./default.html");
    exit();
}

require "../common.inc";

$matches = array();
if ($pi && preg_match('/\.(csv|dba|ics|vcs|tsv)$/', $pi, $matches)) {
    $download = $matches[1];
    $filename = basename($pi);
    $fn = "filename=\"$filename\"";
} else {
    $download = "";
}

if ($download) {
    header("Content-Disposition: filename=$filename");
    if ($download == "csv") {
	header("Content-Type: text/x-csv; $fn");
    } elseif ($download == "dba") {
	header("Content-Type: application/x-palm-dba; $fn");
    } elseif ($download == "ics") {
	header("Content-Type: text/calendar; charset=UTF-8; $fn");
    } elseif ($download == "vcs") {
	header("Content-Type: text/x-vCalendar; $fn");
    } elseif ($download == "tsv") {
	header("Content-Type: text/tab-separated-values; $fn");
    } else {
	trigger_error("Unknown download type $download", E_USER_ERROR);
    }
} else {
    if ($qs && strpos($qs, "cfg=e") !== false) {
	header("Content-Type: application/x-javascript");
    } else {
	header("Content-Type: text/html; charset=UTF-8");
	if (isset($_GET["v"]) && $_GET["v"] == "1") {
	    header("Cache-Control: private");
	    header("Set-Cookie: " . hebcal_gen_cookie() .
		   "; path=/; expires=Tue, 02-Jun-2037 20:00:00 GMT");
	}
    }
}

$url = "/hebcal/hebcal.cgi";
if (isset($_GET["v"]) && $_GET["v"] == "1") {
    if (isset($_GET["year"]) && $_GET["year"] == "now" &&
	isset($_GET["month"]) && (($_GET["month"] == "now") ||
				  ($_GET["month"] == "x"))) {
	$now = time();
	$lt = localtime($now);
	$wday = $lt[6];
	$saturday = ($wday == 6) ? $now + (60 * 60 * 24) :
	    $now + ((6 - $wday) * 60 * 60 * 24);
#	header("Expires: ". gmdate("D, d M Y H:i:s", $saturday). " GMT");
    } else {
	header("Expires: Tue, 02 Jun 2037 20:00:00 GMT");
    }

    $url .= "?$qs";
    $qs = preg_replace('/[&;]?(tag|set)=[^&;]+/', "", $qs);
    $qs = preg_replace('/[&;]?\.(from|cgifields|s)=[^&;]+/', "", $qs);
    $qs = strtr($qs, "&;./", ",,_-");
    $qs = str_replace("%20", "+", $qs);
    $dir = $_SERVER["DOCUMENT_ROOT"] . "/cache/hebcal/hebcal_cgi";
    $status = @readfile("$dir/$qs");
    echo "<!-- cached -->\n";
} else {
    $status = false;
}
if (!$status) {
    virtual($url);
}
exit();
?>
