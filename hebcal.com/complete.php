<?php
if (isset($_SERVER["HTTP_IF_MODIFIED_SINCE"])) {
    header("HTTP/1.0 304 Not Modified");
    echo "Not Modified\n";
    exit;
}

$file = $_SERVER["DOCUMENT_ROOT"] . "/hebcal/geonames.sqlite3";
$db = new SQLite3($file);
if (!$db) {
    error_log("Could not open SQLite3 $file");
    die();
}

$sql = <<<EOD
SELECT geonameid,
asciiname, admin1, country,
population, latitude, longitude, timezone
FROM geoname_fulltext
WHERE longname MATCH '"$_REQUEST[q]*"'
ORDER BY population DESC
LIMIT 10
EOD;

$query = $db->query($sql);
if (!$query) {
    error_log("Querying '$_REQUEST[q]' from $file: " . $db->lastErrorMsg());
    die();
}

$search_results = array();

while ($res = $query->fetchArray(SQLITE3_ASSOC)) {
    $tokens = array_merge(explode(" ", $res["asciiname"]), explode(" ", $res["country"]));
    $search_results[] = array("id" => $res["geonameid"],
			      "value" => $res["asciiname"],
			      "admin1" => $res["admin1"],
			      "asciiname" => $res["asciiname"],
			      "country" => $res["country"],
			      "latitude" => $res["latitude"],
			      "longitude" => $res["longitude"],
			      "timezone" => $res["timezone"],
			      "population" => $res["population"],
			      "tokens" => $tokens);
}

// clean up
unset($query);
$db->close();
unset($db);

if (count($search_results) == 0) {
    header("HTTP/1.1 404 Not Found");
    echo "Not Found\n";
} else {
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode($search_results, JSON_NUMERIC_CHECK);
}

?>
