<?php
$url_prefix = "http://" . $_SERVER["HTTP_HOST"];
$request_uri = $_SERVER["REQUEST_URI"];
$ics_question = strpos($request_uri, ".ics%3F");
if ($ics_question !== false) {
    $request_uri = substr($request_uri, 0, $ics_question)
        . urldecode(substr($request_uri, $ics_question));
    header("HTTP/1.1 301 Moved");
    header("Location: $url_prefix$request_uri");
    echo "Moved.\n";
    exit();
}
$args_pos = strpos($request_uri, "?");
if ($args_pos !== false) {
    $args = substr($request_uri, $args_pos);
    if (strncmp($args, "?subscribe=1%3B", 15) == 0) {
        $args = str_replace("%3B", ";", $args); // reverse iOS ; => %3B conversion
        header("HTTP/1.1 301 Moved");
        $firstpart = substr($request_uri, 0, $args_pos);
        header("Location: $url_prefix$firstpart$args");
        echo "Moved.\n";
        exit();
    }
    $arg2 = str_replace(";", "&", substr($args, 1));
    parse_str($arg2, $param);
    if (isset($param["v"]) && ($param["v"] == "1" || $param["v"] == "yahrzeit")) {
        $now = date("Y");
        if (isset($param["subscribe"]) && $param["subscribe"] == "1"
            && isset($param["yt"]) && $param["yt"] == "G"
            && isset($param["year"]) && is_numeric($param["year"])
            && (($now > $param["year"] + 4)
                || (isset($param["month"]) && $param["month"] != "x" && $now > $param["year"] + 1))) {
            header("HTTP/1.1 410 Gone");
            header("Content-Type: text/plain");
            echo "Gone.\n";
            exit();
        }
        header("HTTP/1.1 200 OK");
        header("Content-Type: text/calendar; charset=UTF-8");
        if ($param["v"] == "1") {
            $url = "http://localhost:8080/hebcal/index.cgi/export.ics" . $args;
        } elseif ($param["v"] == "yahrzeit") {
            $url = "http://localhost:8080/yahrzeit/yahrzeit.cgi/export.ics" . $args;
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
?>
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title><?php echo $_SERVER["REDIRECT_STATUS"] ?> Not Found</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/css/bootstrap.min.css">
<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.1/css/bootstrap-theme.min.css">
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  ga('create', 'UA-967247-1', 'auto');
  ga('set', 'anonymizeIp', true);
  ga('send', 'pageview');
</script>
<style type="text/css">
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
.bullet-list-inline li:after{content:"\00a0\00a0\00b7"}
.bullet-list-inline li:last-child:after{content:""}
</style>
</head>
<body>
<!-- Static navbar -->
<div class="navbar navbar-default navbar-static-top" role="navigation">
  <div class="container-fluid">
    <div class="navbar-header">
      <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target=".navbar-collapse">
        <span class="sr-only">Toggle navigation</span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
      </button>
      <a class="navbar-brand" id="logo" title="Hebcal Jewish Calendar" href="/">Hebcal</a>
    </div>
    <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav"><li><a href="/holidays/" title="Jewish Holidays">Holidays</a></li><li><a href="/converter/" title="Hebrew Date Converter">Date Converter</a></li><li><a href="/shabbat/" title="Shabbat Times">Shabbat</a></li><li><a href="/sedrot/" title="Torah Readings">Torah</a></li><li><a href="http://www.hebcal.com/home/about" title="About">About</a></li><li><a href="http://www.hebcal.com/home/help" title="Help">Help</a></li></ul>
    <form class="navbar-form navbar-right" role="search" method="get" id="searchform" action="http://www.hebcal.com/home/">
     <input name="s" id="s" type="text" class="form-control" placeholder="Search">
    </form>
    </div><!--/.navbar-collapse -->
  </div>
</div>

<div class="container">
<div id="content">
<div class="row">
<div class="col-sm-12">

<h1>Not Found</h1>

<p class="lead">The requested URL
<?php echo htmlspecialchars($_SERVER["REQUEST_URI"]) ?>
 was not found on this server.</p>

<p>Please check your request for typing errors and retry.</p>

<p>Or, search using the form below.</p>

<form action="http://www.hebcal.com/home/" method="get" class="form-inline">
<fieldset>
<div class="input-group">
<input type="text" name="s" id="search" placeholder="Search" value="" class="form-control" />
<span class="input-group-btn">
<button type="submit" class="btn btn-default">Search</button>
</span>
</div>
</fieldset>
</form>

</div><!-- .col-sm-12 -->
</div><!-- .row -->
</div><!-- #content -->

<footer role="contentinfo" class="hebcal-footer">
<div class="row">
<div class="col-sm-12">
<p><small>Except where otherwise noted, content on this site is licensed under a <a
rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative Commons Attribution 3.0 License</a>.</small></p>
<p><small>Some location data comes from <a href="http://www.geonames.org/">GeoNames</a>,
also under a cc-by licence.</small></p>
<ul class="bullet-list-inline">
<li><time datetime="2015-01-01T15:26:56Z">01 January 2015</time></li>
<li><a href="http://www.hebcal.com/home/about">About</a></li>
<li><a href="http://www.hebcal.com/home/about/privacy-policy">Privacy</a></li>
<li><a href="http://www.hebcal.com/home/help">Help</a></li>
<li><a href="http://www.hebcal.com/home/about/contact">Contact</a></li>
<li><a href="http://www.hebcal.com/home/about/donate">Donate</a></li>
<li><a href="http://www.hebcal.com/home/developer-apis">Developer APIs</a></li>
</ul>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
</footer>
</div> <!-- .container -->

</body>
</html>
