<?php
// $Id$
// $URL$

require "../pear/Hebcal/smtp.inc";
require "../pear/Hebcal/common.inc";

function bad_request($err) {
    header("HTTP/1.0 400 Bad Request");
    echo "$err\n";
    exit(0);
}

function get_password() {
    $passfile = file("../hebcal-db-pass.cgi");
    $password = trim($passfile[0]);
    return $password;
}

function my_open_db() {
    $dbpass = get_password();
    $db = mysql_pconnect("mysql5.hebcal.com", "mradwin_hebcal", $dbpass);
    if (!$db) {
	error_log("Could not connect: " . mysql_error());
	die();
    }
    $dbname = "hebcal5";
    if (!mysql_select_db($dbname, $db)) {
	error_log("Could not USE $dbname: " . mysql_error());
	die();
    }
    return $db;
}

function get_sub_info($id) {
    $db = my_open_db();
    $sql = <<<EOD
SELECT email_id, email_address, email_status, email_created,
       email_candles_zipcode, email_candles_city,
       email_candles_havdalah, email_optin_announce
FROM hebcal_shabbat_email
WHERE hebcal_shabbat_email.email_id = '$id'
EOD;

    $result = mysql_query($sql, $db)
	or die("Invalid query 1: " . mysql_error());

    if (mysql_num_rows($result) != 1) {
	return array();
    }

    list($id,$address,$status,$created,$zip,$city,
	 $havdalah,$optin_announce) = mysql_fetch_row($result);

    $val = array(
	"id" => $id,
	"status" => $status,
	"em" => $address,
	"m" => $havdalah,
	"upd" => $optin_announce,
	"zip" => $zip,
	"tz" => $timezone,
	"dst" => $dst,
	"city" => $city,
	"t" => $created,
	);

    mysql_free_result($result);

    return $val;
}

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)\.(\d+)/', $VER, $matches)) {
    $VER = $matches[1] . "." . $matches[2];
}

header("Cache-Control: private");

$param = array();
foreach($_REQUEST as $key => $value) {
    $param[$key] = trim($value);
}

if (isset($param["k"])) {
    if (!preg_match('/^[0-9a-f]{24}$/', $param["k"])) {
	bad_request("Invalid confirmation key");
    }
    $info = get_sub_info($param["k"]);
} elseif (isset($_SERVER["QUERY_STRING"]) &&
	  preg_match('/^[0-9a-f]{24}$/', $_SERVER["QUERY_STRING"])) {
    $info = get_sub_info($_SERVER["QUERY_STRING"]);
} else {
    bad_request("No confirmation key");
    exit(0);
}

if (!isset($info["em"])) {
    header("HTTP/1.0 404 Not Found");
    echo "Can't find $_SERVER[QUERY_STRING] in DB";
    exit(0);
}

if (isset($param["commit"]) && $param["commit"] == "1") {
    $db = my_open_db();
    $sql = <<<EOD
UPDATE hebcal_shabbat_email
SET email_status='active',
    email_ip='$_SERVER[REMOTE_ADDR]'
WHERE email_id = '$info[id]'
EOD;

    mysql_query($sql, $db)
	or die("Invalid query 2: " . mysql_error());

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-owner@hebcal.com";
    $return_path = "shabbat-return-" . strtr($info["em"], "@", "=") .
	"@hebcal.com";
    $subject = "Your subscription to hebcal is complete";

    $ip = $_SERVER["REMOTE_ADDR"];

    $unsub_url = "http://www.hebcal.com/email/?e=" .
	urlencode(base64_encode($info["em"]));

    $headers = array("From" => "\"$from_name\" <$from_addr>",
		     "To" => $info["em"],
		     "Reply-To" => $from_addr,
		     "List-Unsubscribe" => "<$unsub_url&unsubscribe=1&v=1>",
		     "MIME-Version" => "1.0",
		     "Content-Type" => "text/plain",
		     "X-Sender" => $sender,
		     "Precedence" => "bulk",
		     "X-Mailer" => "hebcal web v$VER",
		     "Message-ID" =>
		     "<Hebcal.Web.$VER.".time().".".posix_getpid()."@hebcal.com>",
		     "X-Originating-IP" => "[$ip]",
		     "Subject" => $subject);

    $body = <<<EOD
Hello,

Your subscription request for hebcal is complete.

Regards,
hebcal.com

To modify your subscription or to unsubscribe completely, visit:
$unsub_url
EOD;

    $err = smtp_send($return_path, $info["em"], $headers, $body);
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Email Subscription Confirmed</title>
<base href="http://www.hebcal.com/email/verify.php" target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
</head><body><table width="100%"
class="navbar"><tr><td><strong><a
href="/">hebcal.com</a></strong>
<tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a>
<tt>-&gt;</tt>
Email</td><td align="right"><a
href="/help/">Help</a> -
<a href="/search/">Search</a>
</td></tr></table><h1>Email Subscription Confirmed</h1>
<p>Thank you for your interest in weekly
candle lighting times and parsha information.</p>
<p>A confirmation message has been sent
to <b><?php echo htmlentities($info["em"]) ?></b>.</p>
<?php
    echo html_footer_lite();
    exit();
} else {
    if (isset($info["zip"]) && preg_match('/^\d{5}$/', $info["zip"])) {
	$password = get_password();
	list($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    hebcal_get_zipcode_fields($info["zip"], $password);
	$city_descr = "$city, $state " . $info["zip"];
	global $hebcal_tz_names;
	$info["tz"] = $tz;
	$tz_descr = "Time zone: " . $hebcal_tz_names["tz_" . $tz];
	$dst_descr = "Daylight Saving Time: " . ($dst ? "usa" : "none");
	unset($info["city"]);
    } else {
	$city_descr = $info["city"];
	global $hebcal_tz_names;
	$tz_descr = "Time zone: " .
	     $hebcal_tz_names["tz_" . $hebcal_city_tz[$info["city"]]];
	$dst_descr = "";
	unset($info["zip"]);
    }
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Confirm Email Subscription</title>
<base href="http://www.hebcal.com/email/verify.php" target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
</head><body><table width="100%"
class="navbar"><tr><td><strong><a
href="/">hebcal.com</a></strong>
<tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a>
<tt>-&gt;</tt>
Email</td><td align="right"><a
href="/help/">Help</a> -
<a href="/search/">Search</a>
</td></tr></table><h1>Confirm Email Subscription</h1>
<?php
	$html = <<<EOD
<p>Please confirm your subscription to hebcal.com weekly Shabbat Candle
Lighting Times.</p>
<p>Email: <b>$info[em]</b>
<br>Location: $city_descr
<br><small>&nbsp;&nbsp;$tz_descr
<br>&nbsp;&nbsp;$dst_descr
</small></p>
<p>
<form method="post" name="f1" id="f1" action="/email/verify.php">
<input type="hidden" name="k" value="$info[id]">
<input type="hidden" name="commit" value="1">
<input type="submit" name="sub1" id="sub1" value="Confirm Subscription">
</form>
</p>
<h4>Email Privacy Policy</h4>

<p>We will never sell or give your email address to anyone.
<br>We will never use your email address to send you unsolicited
offers.</p>

<p>To unsubscribe, send an email to <a
href="mailto:shabbat-unsubscribe&#64;hebcal.com">shabbat-unsubscribe&#64;hebcal.com</a>.</p>
EOD
 ;

 echo $html;
 echo html_footer_lite();
 exit();
}
?>
