<?php
# $Id$
# $Source: /Users/mradwin/hebcal-copy/hebcal.com/shabbat/RCS/index.php,v $

$qs = getenv("QUERY_STRING");
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

$url = "/shabbat/shabbat.cgi";
if ($qs) {
    $url .= "?$qs";
    $cqs = preg_replace('/[&;]?tag=[^&;]+/', "", $qs);
    $cqs = strtr($cqs, "&;./", ",,_-");
    $cqs = str_replace("%20", "+", $cqs);
    $dir = getenv("DOCUMENT_ROOT") . "/cache/shabbat/shabbat_cgi";
    $status = @readfile("$dir/$cqs");
} else {
    $status = false;
}
if (!$status) {
    virtual($url);
}
exit();
?>