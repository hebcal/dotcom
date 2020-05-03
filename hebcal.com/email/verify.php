<?php
require "../pear/Hebcal/smtp.inc";
require "../pear/Hebcal/common.inc";

function get_return_path($mailto) {
    return "shabbat-return+" . strtr($mailto, "@", "=") . "@hebcal.com";
}

function bad_request($err) {
    header("HTTP/1.0 400 Bad Request");
    echo "$err\n";
    exit(0);
}

function get_sub_info($id) {
    $sql = <<<EOD
SELECT email_id, email_address, email_status, email_created,
       email_candles_zipcode, email_candles_city,
       email_candles_geonameid,
       email_candles_havdalah, email_optin_announce
FROM hebcal_shabbat_email
WHERE hebcal_shabbat_email.email_id = '$id'
EOD;

    $mysqli = hebcal_open_mysqli_db();
    $result = mysqli_query($mysqli, $sql)
	or die("Invalid query 1: " . mysqli_error($mysqli));

    if (mysqli_num_rows($result) != 1) {
	return array();
    }

    list($id,$address,$status,$created,$zip,$city,
	 $geonameid,
	 $havdalah,$optin_announce) = mysqli_fetch_row($result);

    $val = array(
	"id" => $id,
	"status" => $status,
	"em" => $address,
	"m" => $havdalah,
	"upd" => $optin_announce,
	"zip" => $zip,
	"city" => $city,
	"geonameid" => $geonameid,
	"t" => $created,
	);

    mysqli_free_result($result);

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
    $ip = $_SERVER["REMOTE_ADDR"];
    $sql = <<<EOD
UPDATE hebcal_shabbat_email
SET email_status='active',
    email_ip='$ip'
WHERE email_id = '$info[id]'
EOD;

    $mysqli = hebcal_open_mysqli_db();
    mysqli_query($mysqli, $sql)
	or die("Invalid query 2: " . mysqli_error($mysqli));

    $from_name = "Hebcal";
    $from_addr = "shabbat-owner@hebcal.com";
    $reply_to = "no-reply@hebcal.com";
    $subject = "Your subscription to hebcal is complete";

    $url_prefix = "https://" . $_SERVER["HTTP_HOST"];
    $unsub_url = $url_prefix . "/email/?e=" .
	urlencode(base64_encode($info["em"]));

    $unsub_addr = "shabbat-unsubscribe+" . $info["id"] . "@hebcal.com";

    $headers = array("From" => "\"$from_name\" <$from_addr>",
		     "To" => $info["em"],
		     "Reply-To" => $reply_to,
             "List-Unsubscribe" => "<mailto:$unsub_addr>",
		     "MIME-Version" => "1.0",
		     "Content-Type" => "text/plain",
		     "X-Mailer" => "hebcal web",
		     "Message-ID" =>
		     "<Hebcal.Web.".time().".".posix_getpid()."@hebcal.com>",
		     "X-Originating-IP" => "[$ip]",
		     "Subject" => $subject);

    $body = <<<EOD
Hello,

Your subscription request for hebcal is complete.

You'll receive a maximum of one message per week, typically on Thursday morning.

Regards,
hebcal.com

To modify your subscription or to unsubscribe completely, visit:
$unsub_url
EOD;

    $err = smtp_send(get_return_path($info["em"]), $info["em"], $headers, $body);
    echo html_header_bootstrap3("Email Subscription Confirmed");
?>
<div class="row">
<div class="col-sm-12">
<p class="lead">Confirm your subscription to weekly Shabbat
candle lighting times and Torah portion by email.</p>
<div class="alert alert-success">
<strong>Thank you!</strong> Your subscription is now active.
A confirmation message has been sent
to <strong><?php echo htmlentities($info["em"]) ?></strong>.
</div>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<?php
    echo html_footer_bootstrap3();
    exit();
} else {
    if (isset($info["zip"]) && preg_match('/^\d{5}$/', $info["zip"])) {
	list($city,$state,$tzid,$latitude,$longitude,
	     $lat_deg,$lat_min,$long_deg,$long_min) =
	    hebcal_get_zipcode_fields($info["zip"]);
	$city_descr = "$city, $state " . $info["zip"];
	unset($info["city"]);
	unset($info["geonameid"]);
    } elseif (isset($info["geonameid"]) && preg_match('/^\d+$/', $info["geonameid"])) {
	list($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) =
	    hebcal_get_geoname($info["geonameid"]);
    $city_descr = geoname_city_descr($name,$admin1,$country);
	unset($info["zip"]);
	unset($info["city"]);
    } elseif (isset($info["city"])) {
        $geonameid = hebcal_city_to_geoname($info["city"]);
        if ($geonameid !== false) {
            list($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) =
                hebcal_get_geoname($geonameid);
            $city_descr = geoname_city_descr($name,$admin1,$country);
            $info["geonameid"] = $geonameid;
            unset($info["zip"]);
            unset($info["city"]);
        }
    }
    echo html_header_bootstrap3("Confirm Email Subscription");
?>
<div class="row">
<div class="col-sm-12">
<p class="lead">Confirm your subscription to weekly Shabbat
candle lighting times and Torah portion by email.</p>
<p>Email: <strong><?php echo $info["em"] ?></strong>
<br>Location: <?php echo $city_descr ?>
</p>
<form method="post" action="<?php echo $_SERVER["PHP_SELF"] ?>">
<input type="hidden" name="k" value="<?php echo $info["id"] ?>">
<input type="hidden" name="commit" value="1">
<button type="submit" name="sub1" id="sub1" value="1" class="btn btn-success">Confirm Subscription</button>
</form>
<h3>Email Privacy Policy</h3>
<p>We will never sell or give your email address to anyone.
<br>We will never use your email address to send you unsolicited
offers.</p>
<p>To unsubscribe, send an email to <a
href="mailto:shabbat-unsubscribe&#64;hebcal.com">shabbat-unsubscribe&#64;hebcal.com</a>.</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<?php
 echo html_footer_bootstrap3();
 exit();
}
?>
