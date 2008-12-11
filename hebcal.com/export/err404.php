<?php
$args = strstr($_SERVER["REQUEST_URI"], "?");
if ($args !== false) {
    $arg2 = str_replace(";", "&", substr($args, 1));
    parse_str($arg2, $param);
    if (isset($param["v"]) && $param["v"] == "1") {
	header("HTTP/1.1 200 OK");
	header("Content-Type: text/calendar; charset=UTF-8");
	$url = "http://www.hebcal.com/hebcal/index.cgi/export.ics" . $args;
	$ch = curl_init($url);
	curl_exec($ch);
	curl_close($ch);
	exit();
    } elseif (isset($param["v"]) && $param["v"] == "yahrzeit") {
	header("HTTP/1.1 200 OK");
	header("Content-Type: text/calendar; charset=UTF-8");
	$url = "http://www.hebcal.com/yahrzeit/yahrzeit.cgi/export.ics" . $args;
	$ch = curl_init($url);
	curl_exec($ch);
	curl_close($ch);
	exit();
    }
}

header("HTTP/1.1 404 Not Found");
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head>
<title><?php echo $_SERVER["REDIRECT_STATUS"] ?> Not Found</title>
<link rel="stylesheet" href="/style.css" type="text/css">
</head>
<body>

<table width="100%" class="navbar">
<tr><td>
<strong><a href="/">hebcal.com</a></strong> <tt>-&gt;</tt>
Not Found
</td>
<td align="right">
<a href="/help/">Help</a> -
<a href="/search/">Search</a>
</td></tr></table>

<h1>Not Found</h1>
<p>The requested URL
<?php echo htmlspecialchars($_SERVER["REQUEST_URI"]) ?>
 was not found on this server.</p>

<p>Please check your request for typing errors and retry.</p>

<form action="/cgi-bin/htsearch" method="get">
<input type="text" name="words" size="30">
<input type="hidden" name="config" value="hebcal">
<input type="submit" value="Search"></td></tr></table>
</form>

<p>
<hr noshade size="1">
<span class="tiny">Copyright
&copy; <?php echo date("Y") ?> Michael J. Radwin. All rights reserved.
<a href="/privacy/">Privacy Policy</a> -
<a href="/help/">Help</a> -
<a href="/contact/">Contact</a> -
<a href="/news/">News</a> -
<a href="/donations/">Donate</a>
</span>
</body></html>
