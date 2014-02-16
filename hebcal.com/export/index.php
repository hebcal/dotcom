<?php
$url_prefix = "http://download.hebcal.com";
$request_uri = $_SERVER["REQUEST_URI"];
$ics_question = strpos($request_uri, ".ics%3F");
if ($ics_question !== false) {
    $request_uri = substr($request_uri, 0, $ics_question)
        . urldecode(substr($request_uri, $ics_question));
    header("HTTP/1.1 301 Moved");
    header("Status: 301 Moved");
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
        header("Status: 301 Moved");
        $firstpart = substr($request_uri, 0, $args_pos);
        header("Location: $url_prefix$firstpart$args");
        echo "Moved.\n";
        exit();
    }
}
header("HTTP/1.1 301 Moved");
header("Status: 301 Moved");
header("Location: $url_prefix$request_uri");
echo "Moved.\n";
exit();
?>
