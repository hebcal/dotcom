<?php
// don't visit DreamHost php4 /usr/local/lib/php
set_include_path(".:/usr/local/php5/lib/pear");

require "../pear/Hebcal/smtp.inc";
require "../pear/Hebcal/common.inc";

function bad_request($err) {
    header("HTTP/1.0 400 Bad Request");
    echo "$err\n";
    exit(0);
}

function get_sub_info($id) {
    global $hebcal_db;
    hebcal_open_mysql_db();
    $sql = <<<EOD
SELECT email_id, email_address, email_status, email_created,
       email_candles_zipcode, email_candles_city,
       email_candles_havdalah, email_optin_announce
FROM hebcal_shabbat_email
WHERE hebcal_shabbat_email.email_id = '$id'
EOD;

    $result = mysql_query($sql, $hebcal_db)
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
	"city" => $city,
	"t" => $created,
	);

    mysql_free_result($result);

    return $val;
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
    global $hebcal_db;
    hebcal_open_mysql_db();
    $sql = <<<EOD
UPDATE hebcal_shabbat_email
SET email_status='active',
    email_ip='$_SERVER[REMOTE_ADDR]'
WHERE email_id = '$info[id]'
EOD;

    mysql_query($sql, $hebcal_db)
	or die("Invalid query 2: " . mysql_error());

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-owner@hebcal.com";
    $reply_to = "no-reply@hebcal.com";
    $return_path = "shabbat-return-" . strtr($info["em"], "@", "=") .
	"@hebcal.com";
    $subject = "Your subscription to hebcal is complete";

    $ip = $_SERVER["REMOTE_ADDR"];

    $url_prefix = "http://" . $_SERVER["HTTP_HOST"];
    $unsub_url = $url_prefix . "/email/?e=" .
	urlencode(base64_encode($info["em"]));

    $headers = array("From" => "\"$from_name\" <$from_addr>",
		     "To" => $info["em"],
		     "Reply-To" => $reply_to,
		     "List-Unsubscribe" => "<$unsub_url&unsubscribe=1&v=1>",
		     "MIME-Version" => "1.0",
		     "Content-Type" => "text/plain",
		     "X-Sender" => $sender,
		     "Precedence" => "bulk",
		     "X-Mailer" => "hebcal web",
		     "Message-ID" =>
		     "<Hebcal.Web.".time().".".posix_getpid()."@hebcal.com>",
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
    echo html_header_bootstrap("Email Subscription Confirmed");
?>
<p class="lead">Confirm your subscription to weekly Shabbat
candle lighting times and Torah portion by email.</p>
<div class="alert alert-success">
<strong>Thank you!</strong> Your subscription is now active.
A confirmation message has been sent
to <strong><?php echo htmlentities($info["em"]) ?></strong>.
</div>
<?php
    echo html_footer_bootstrap();
    exit();
} else {
    if (isset($info["zip"]) && preg_match('/^\d{5}$/', $info["zip"])) {
	list($city,$state,$tzid,$latitude,$longitude,
	     $lat_deg,$lat_min,$long_deg,$long_min) =
	    hebcal_get_zipcode_fields($param["zip"]);
	$city_descr = "$city, $state " . $info["zip"];
	unset($info["city"]);
    } else {
	global $hebcal_cities, $hebcal_countries;
	$city_info = $hebcal_cities[$info["city"]];
	$city_descr = $city_info[1] . ", " . $hebcal_countries[$city_info[0]][0];
	$tzid = $hebcal_cities[$info["city"]][4];
	unset($info["zip"]);
    }
    $tz_descr = "Time zone: " . $tzid;
    echo html_header_bootstrap("Confirm Email Subscription");
?>
<p class="lead">Confirm your subscription to weekly Shabbat
candle lighting times and Torah portion by email.</p>
<div class="well">
<p>Email: <strong><?php echo $info["em"] ?></strong>
<br>Location: <?php echo $city_descr ?> &nbsp;&nbsp;(<?php echo $tz_descr ?>)
</p>
<form method="post" action="<?php echo $_SERVER["PHP_SELF"] ?>">
<input type="hidden" name="k" value="<?php echo $info["id"] ?>">
<input type="hidden" name="commit" value="1">
<button type="submit" name="sub1" id="sub1" value="1" class="btn btn-success">Confirm Subscription</button>
</form>
</div><!-- .well -->
<h3>Email Privacy Policy</h3>
<p>We will never sell or give your email address to anyone.
<br>We will never use your email address to send you unsolicited
offers.</p>
<p>To unsubscribe, send an email to <a
href="mailto:shabbat-unsubscribe&#64;hebcal.com">shabbat-unsubscribe&#64;hebcal.com</a>.</p>
<?php
 echo html_footer_bootstrap();
 exit();
}
?>
