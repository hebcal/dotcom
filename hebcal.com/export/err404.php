<?php
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
	$user_agent = "hebcal-export/20130721";
	curl_setopt($ch, CURLOPT_USERAGENT, $user_agent);
	$ref_url = $url_prefix . $request_uri;
	curl_setopt($ch, CURLOPT_REFERER, $ref_url);
	curl_setopt($ch, CURLOPT_HTTPHEADER,
		    array("X-Forwarded-For: " . $_SERVER["REMOTE_ADDR"]));
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
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="/i/bootstrap-2.3.1/css/bootstrap.min.css" media="all">
<link rel="stylesheet" type="text/css" id="bootstrap-responsive-css" href="/i/bootstrap-2.3.1/css/bootstrap-responsive.min.css" media="all">
<script type="text/javascript">
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-967247-1']);
_gaq.push(['_trackPageview']);
(function() {
var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
</script>
<style type="text/css">
.hebrew {font-family:'SBL Hebrew',Arial;direction:rtl}
.navbar{position:static}
body{padding-top:0}
@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
}
</style>
</head>
<body class="error404">
<header role="banner">

<div id="inner-header" class="clearfix">
  
<div class="navbar navbar-fixed-top">
<div class="navbar-inner">
<div class="container-fluid nav-container">
  <nav role="navigation">
  <a class="brand" id="logo" title="Jewish Calendar" href="/">Hebcal</a>
								
  <a class="btn btn-navbar" data-toggle="collapse" data-target=".nav-collapse">
  <span class="icon-bar"></span>
  <span class="icon-bar"></span>
  <span class="icon-bar"></span>
  </a>
								
<div class="nav-collapse">
  <ul id="menu-default" class="nav"><li id="menu-item-441" class="menu-item menu-item-type-post_type menu-item-object-page"><a title="Jewish Holidays" href="http://www.hebcal.com/holidays/" >Holidays</a></li>
<li id="menu-item-443" class="menu-item menu-item-type-post_type menu-item-object-page"><a title="Hebrew Date Converter" href="http://www.hebcal.com/converter/" >Date Converter</a></li>
<li id="menu-item-440" class="menu-item menu-item-type-post_type menu-item-object-page"><a title="Shabbat Times" href="http://www.hebcal.com/shabbat/" >Shabbat</a></li>
<li id="menu-item-445" class="menu-item menu-item-type-post_type menu-item-object-page"><a title="Torah Readings" href="http://www.hebcal.com/sedrot/" >Torah</a></li>
<li id="menu-item-324" class="menu-item menu-item-type-post_type menu-item-object-page"><a href="http://www.hebcal.com/home/about" >About</a></li>
<li id="menu-item-328" class="menu-item menu-item-type-post_type menu-item-object-page current_page_parent"><a href="http://www.hebcal.com/home/help" >Help</a></li>
</ul>								</div>

</nav>
							
<form class="navbar-search pull-right" role="search" method="get" id="searchform" action="http://www.hebcal.com/home/">
<input name="s" id="s" type="text" class="search-query" placeholder="Search">
</form>

</div>
</div>
</div>

</div> <!-- end #inner-header -->

</header> <!-- end header -->

<div class="container-fluid">
  
<div id="content" class="clearfix row-fluid">

<div id="main" class="span12 clearfix" role="main">

<div class="page-header"><h1>Not Found</h1></div>

<p class="lead">The requested URL
<?php echo htmlspecialchars($_SERVER["REQUEST_URI"]) ?>
 was not found on this server.</p>

<p>Please check your request for typing errors and retry.</p>

</div> <!-- end #main -->
    
</div> <!-- end #content -->

<footer role="contentinfo">
<hr>
<div id="inner-footer" class="clearfix">
<div class="row-fluid">
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">Products</li>
<li><a href="/holidays/">Jewish Holidays</a></li>
<li><a href="/converter/">Hebrew Date Converter</a></li>
<li><a href="/shabbat/">Shabbat Times</a></li>
<li><a href="/sedrot/">Torah Readings</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">About Us</li>
<li><a href="/home/about">About Hebcal</a></li>
<li><a href="/home/category/news">News</a></li>
<li><a href="/home/about/privacy-policy">Privacy Policy</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
<ul class="nav nav-list">
<li class="nav-header">Connect</li>
<li><a href="/home/help">Help</a></li>
<li><a href="/home/about/contact">Contact Us</a></li>
<li><a href="/home/about/donate">Donate</a></li>
<li><a href="/home/developer-apis">Developer APIs</a></li>
</ul>
</div><!-- .span3 -->
<div class="span3">
<p><small>Except where otherwise noted, content on
<span xmlns:cc="http://creativecommons.org/ns#" property="cc:attributionName">this site</span>
is licensed under a 
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative
Commons Attribution 3.0 License</a>.</small></p>
</div><!-- .span3 -->
</div><!-- .row-fluid -->
</div><!-- #inner-footer -->
</footer>
</div> <!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
<script src="/i/bootstrap-2.3.1/js/bootstrap.min.js"></script>
</body></html>
