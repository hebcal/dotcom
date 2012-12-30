<?php
$VERSION = '$Revision: 3343 $';
$matches = array();
if (preg_match('/(\d+)/', $VERSION, $matches)) {
    $VERSION = $matches[1];
}
$url_prefix = "http://" . $_SERVER["HTTP_HOST"];
$request_uri = $_SERVER["REQUEST_URI"];
$ics_question = strpos($request_uri, ".ics%3F");
if ($ics_question !== false) {
    $request_uri = substr($request_uri, 0, $ics_question)
	. urldecode(substr($request_uri, $ics_question));
}
$args = strstr($request_uri, "?");
if ($args !== false) {
    if (strncmp($args, "?subscribe=1%3B", 15) == 0) {
	$args = str_replace("%3B", ";", $args); // reverse iOS ; => %3B conversion
    }
    $arg2 = str_replace(";", "&", substr($args, 1));
    parse_str($arg2, $param);
    if (isset($param["v"]) && ($param["v"] == "1" || $param["v"] == "yahrzeit")) {
	header("HTTP/1.1 200 OK");
	header("Status: 200 OK");
	header("Content-Type: text/calendar; charset=UTF-8");
	if ($param["v"] == "1") {
	    $url = $url_prefix . "/hebcal/index.cgi/export.ics" . $args;
	} elseif ($param["v"] == "yahrzeit") {
	    $url = $url_prefix . "/yahrzeit/yahrzeit.cgi/export.ics" . $args;
	}
	$ch = curl_init($url);
	$user_agent = "hebcal-export/$VERSION";
	curl_setopt($ch, CURLOPT_USERAGENT, $user_agent);
	$ref_url = $url_prefix . $request_uri;
	curl_setopt($ch, CURLOPT_REFERER, $ref_url);
	curl_exec($ch);
	curl_close($ch);
	exit();
    }
}

header("HTTP/1.1 404 Not Found");
header("Status: 404 Not Found");
?>
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title><?php echo $_SERVER["REDIRECT_STATUS"] ?> Not Found</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link href="/bootstrap/css/bootstrap.min.css" rel="stylesheet">
<link href="/bootstrap/css/bootstrap-responsive.min.css" rel="stylesheet">
<link rel="stylesheet" type="text/css" id="wp-bootstrap-css" href="/bootstrap/css/wordpress-bootstrap.min.css" media="all">
</head>
<body>
<div class="container">

    <div class="navbar navbar-fixed-top">
      <div class="navbar-inner">
        <div class="container">
          <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </a>
          <a class="brand" id="logo" title="Hebcal Jewish Calendar" href="/">Hebcal</a>
         <div class="nav-collapse collapse">
         <form class="navbar-form pull-right" role="search" method="get" id="searchform" action="/home/">
      <fieldset>
      <div class="input-append input-prepend">
      <span class="add-on"><i class="icon-search"></i></span><input class="input-mini" type="text" name="s" id="s"><button type="submit" class="btn btn-primary">Search</button></div>
      </fieldset>
         </form>
         </div><!-- .nav-collapse -->
        </div><!-- .container -->
       </div><!-- .navbar-inner -->
      </div><!-- .navbar -->


<div class="hero-unit">
<h1>Not Found</h1>
</div><!-- .hero-unit -->

<p class="lead">The requested URL
<?php echo htmlspecialchars($_SERVER["REQUEST_URI"]) ?>
 was not found on this server.</p>

<p>Please check your request for typing errors and retry.</p>

<hr>

<footer>
Copyright &copy; <?php echo date("Y") ?> Michael J. Radwin. All rights reserved.
</footer>

</div> <!-- .container -->
</body>
</html>
