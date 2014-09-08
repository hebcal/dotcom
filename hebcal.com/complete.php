<?php
if (isset($_SERVER["HTTP_IF_MODIFIED_SINCE"])) {
    header("HTTP/1.0 304 Not Modified");
    echo "Not Modified\n";
    exit;
}

$qraw = isset($_REQUEST["q"]) ? trim($_REQUEST["q"]) : "";
if (strlen($qraw) == 0) {
    header("HTTP/1.1 404 Not Found");
    echo "Not Found\n";
    exit;
}

$search_results = array();

if (is_numeric($qraw)) {
    require("./pear/Hebcal/common.inc");

    $file = $_SERVER["DOCUMENT_ROOT"] . "/hebcal/zips.sqlite3";
    $db = new SQLite3($file);
    if (!$db) {
        error_log("Could not open SQLite3 $file");
        die();
    }

    $sql = <<<EOD
SELECT ZipCode,CityMixedCase,State,Latitude,Longitude,TimeZone,DayLightSaving
FROM ZIPCodes_Primary
WHERE ZipCode LIKE '$qraw%'
LIMIT 10
EOD;

    $query = $db->query($sql);
    if (!$query) {
        error_log("Querying '$qraw' from $file: " . $db->lastErrorMsg());
        die();
    }

    while ($res = $query->fetchArray(SQLITE3_ASSOC)) {
        $longname = $res["CityMixedCase"] . ", " . $res["State"] . " " . $res["ZipCode"];
        $tzid = get_usa_tzid($res["TimeZone"],$res["State"],$res["DayLightSaving"]);
        $search_results[] = array(
            "id" => strval($res["ZipCode"]),
            "value" => $longname,
            "admin1" => $res["State"],
            "asciiname" => $res["CityMixedCase"],
            "country" => "United States",
            "latitude" => $res["Latitude"],
            "longitude" => $res["Longitude"],
            "timezone" => $tzid,
            "geo" => "zip");
    }

    // clean up
    unset($query);
    $db->close();
    unset($db);
} else {
    $file = $_SERVER["DOCUMENT_ROOT"] . "/hebcal/geonames.sqlite3";
    $db = new SQLite3($file);
    if (!$db) {
        error_log("Could not open SQLite3 $file");
        die();
    }

    $qe = SQLite3::escapeString($qraw);
    $sql = <<<EOD
SELECT geonameid,
asciiname, admin1, country,
population, latitude, longitude, timezone
FROM geoname_fulltext
WHERE longname MATCH '"$qe*"'
ORDER BY population DESC
LIMIT 10
EOD;

    $query = $db->query($sql);
    if (!$query) {
        error_log("Querying '$qe' from $file: " . $db->lastErrorMsg());
        die();
    }

    while ($res = $query->fetchArray(SQLITE3_ASSOC)) {
        $longname = $res["asciiname"];
        if (!empty($res["admin1"])
            && strncmp($res["admin1"], $res["asciiname"], strlen($res["asciiname"])) != 0) {
            $longname .= ", " . $res["admin1"];
            $a1tokens = explode(" ", $res["admin1"]);
        } else {
            $a1tokens = array();
        }
        $longname .= ", " . $res["country"];
        $tokens = array_merge(explode(" ", $res["asciiname"]),
                  $a1tokens,
                  explode(" ", $res["country"]));
        $search_results[] = array("id" => $res["geonameid"],
                      "value" => $longname,
                      "admin1" => $res["admin1"],
                      "asciiname" => $res["asciiname"],
                      "country" => $res["country"],
                      "latitude" => $res["latitude"],
                      "longitude" => $res["longitude"],
                      "timezone" => $res["timezone"],
                      "population" => $res["population"],
                      "geo" => "geoname",
                      "tokens" => $tokens);
    }

    // clean up
    unset($query);
    $db->close();
    unset($db);
}

if (count($search_results) == 0) {
    header("HTTP/1.1 404 Not Found");
    echo "Not Found\n";
} else {
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode($search_results, 0);
}

?>
