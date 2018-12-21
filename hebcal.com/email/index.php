<?php
// don't visit DreamHost php4 /usr/local/lib/php
//set_include_path(".:/usr/local/php5/lib/pear");

require "../pear/Hebcal/smtp.inc";
require "../pear/Hebcal/common.inc";

function city_to_geonameid($param) {
    $geonameid = hebcal_city_to_geoname($param["city"]);
    //error_log("city_to_geonameid $param[city] => $geonameid");
    unset($param["city"]);
    if ($geonameid !== false) {
        $param["geo"] = "geoname";
        $param["geonameid"] = $geonameid;
    }
    return $param;
}

$remoteAddr = $_SERVER["REMOTE_ADDR"];

$sender = "webmaster@hebcal.com";

header("Cache-Control: private");

$xtra_head = <<<EOD
<link rel="stylesheet" type="text/css" href="/i/hyspace-typeahead.css">
EOD;
echo html_header_bootstrap3("Shabbat Candle Lighting Times by Email",
			   $xtra_head);

$param = array();
if (!isset($_REQUEST["v"]) && !isset($_REQUEST["e"])
    && isset($_COOKIE["C"]))
{
    parse_str($_COOKIE["C"], $param);
}

foreach($_REQUEST as $key => $value) {
    $param[$key] = trim($value);
}

if (isset($param["city"])) {
    $param = city_to_geonameid($param);
}

if (!isset($param["m"])) {
    $param["m"] = 50;
}

$default_unsubscribe = false;
if (isset($param["v"]) && $param["v"])
{
    $email = isset($param["em"]) ? $param["em"] : false;
    if (!$email)
    {
	form($param,
	     "Please enter your email address.");
    }

    $to_addr = email_address_valid($email);
    if ($to_addr == false) {
	form($param,
	     "Sorry, <strong>" . htmlspecialchars($email) . "</strong> does\n" .
	     "not appear to be a valid email address.");
    }

    // email is OK, write canonicalized version
    $email = $to_addr;

    $param["em"] = strtolower($email);
}
else
{
    if (isset($param["e"])) {
	$param["em"] = base64_decode($param["e"]);
    }

    if (isset($param["em"])) {
	$info = get_sub_info($param["em"], true);
	if (isset($info["status"]) && $info["status"] == "active") {
	    foreach ($info as $k => $v) {
                if (isset($v)) {
                    $param[$k] = $v;
                }
	    }
            if (isset($param["city"])) {
                $param = city_to_geonameid($param);
            } elseif (isset($param["zip"])) {
                $param["geo"] = "zip";
            } elseif (isset($param["geonameid"])) {
                $param["geo"] = "geoname";
            }
	    $is_update = true;
	}
    }

    if (isset($param["unsubscribe"]) && $param["unsubscribe"]) {
	$default_unsubscribe = true;
    }

    form($param);
}

if (isset($param["modify"]) && $param["modify"]) {
    subscribe($param);
}
elseif (isset($param["unsubscribe"]) && $param["unsubscribe"]) {
    unsubscribe($param);
}
else {
    form($param);
    // form always writes footer and exits
}

echo html_footer_bootstrap3();
exit();

function get_return_path($mailto) {
    return "shabbat-return+" . strtr($mailto, "@", "=") . "@hebcal.com";
}

function echo_lead_text($unsub) {
    global $echoed_lead_text;
    if (!$echoed_lead_text) {
        $prefix = $unsub ? "Unsubscribe from" : "Subscribe to";
?>
<div class="row">
<div class="col-sm-12">
<p class="lead"><?php echo $prefix ?> weekly Shabbat candle
lighting times and Torah portion by email.</p>
<?php
	$echoed_lead_text = true;
    }
}

function write_sub_info($param) {
    global $remoteAddr;

    if ($param["geo"] == "zip")
    {
	$geo_sql = "email_candles_zipcode='$param[zip]',email_candles_city=NULL,email_candles_geonameid=NULL";
    }
    elseif ($param["geo"] == "geoname")
    {
	$geo_sql = "email_candles_geonameid='$param[geonameid]',email_candles_city=NULL,email_candles_zipcode=NULL";
    }

    $sql = <<<EOD
UPDATE hebcal_shabbat_email
SET email_status='active',
    $geo_sql,
    email_candles_havdalah='$param[m]',
    email_ip='$remoteAddr',
    email_optin_announce='0'
WHERE email_address = '$param[em]'
EOD;

    $mysqli = hebcal_open_mysqli_db();
    return mysqli_query($mysqli, $sql);
}

function get_sub_info($email, $expected_present = false) {
    //error_log("get_sub_info($email);");
    $sql = <<<EOD
SELECT email_id, email_address, email_status, email_created,
       email_candles_zipcode, email_candles_city,
       email_candles_geonameid,
       email_candles_havdalah
FROM hebcal_shabbat_email
WHERE hebcal_shabbat_email.email_address = '$email'
EOD;

    //error_log($sql);
    $mysqli = hebcal_open_mysqli_db();
    $result = mysqli_query($mysqli, $sql);
    if (!$result) {
	error_log("Invalid query 1: " . mysqli_error($mysqli));
	return array();
    }

    $num_rows = mysqli_num_rows($result);
    if ($num_rows != 1) {
    	if ($num_rows != 0 || $expected_present) {
	    error_log("get_sub_info($email) got $num_rows rows, expected 1");
    	}
	return array();
    }

    list($id,$address,$status,$created,$zip,$city,
	 $geonameid,
	 $havdalah) = mysqli_fetch_row($result);

    global $hebcal_cities_old;
    if (isset($city) && isset($hebcal_cities_old[$city])) {
	$city = $hebcal_cities_old[$city];
    }
    $val = array(
	"id" => $id,
	"status" => $status,
	"em" => $address,
	"m" => $havdalah,
	"zip" => $zip,
	"city" => $city,
	"geonameid" => $geonameid,
	"t" => $created,
	);

    //error_log("get_sub_info($email) got " . json_encode($val));
    mysqli_free_result($result);

    return $val;
}

function write_staging_info($param, $old_encoded)
{
    global $remoteAddr;
    if ($old_encoded)
    {
	$encoded = $old_encoded;
    }
    else
    {
	$now = time();
	$rand = pack("V", $now);

	if ($remoteAddr)
	{
	    list($p1,$p2,$p3,$p4) = explode(".", $remoteAddr);
	    $rand .= pack("CCCC", $p1, $p2, $p3, $p4);
	}

	// As of PHP 4.2.0, there is no need to seed the random
	// number generator as this is now done automatically.
	$rand .= pack("V", rand());

	$encoded = bin2hex($rand);
    }

    if ($param["geo"] == "zip")
    {
	$location_name = "email_candles_zipcode";
	$location_value = $param["zip"];
    }
    elseif ($param["geo"] == "geoname")
    {
	$location_name = "email_candles_geonameid";
	$location_value = $param["geonameid"];
    }

    $sql = <<<EOD
REPLACE INTO hebcal_shabbat_email
(email_id, email_address, email_status, email_created,
 email_candles_havdalah, email_optin_announce,
 $location_name, email_ip)
VALUES ('$encoded', '$param[em]', 'pending', NOW(),
	'$param[m]', '0',
	'$location_value', '$remoteAddr')
EOD;

    $mysqli = hebcal_open_mysqli_db();
    $result = mysqli_query($mysqli, $sql)
	or die("Invalid query 2: " . mysqli_error($mysqli));

    if (mysqli_affected_rows($mysqli) < 1) {
	die("Strange numrows from MySQL:" . mysqli_error($mysqli));
    }

    return $encoded;
}

function form($param, $message = "", $help = "") {
    global $is_update, $default_unsubscribe;

    echo_lead_text($default_unsubscribe);

    if ($message != "") {
?>
<div class="alert alert-danger alert-dismissable">
  <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
  <?php echo $message; echo $help; ?>
</div><!-- .alert -->
<?php
    }

    $action = $_SERVER["PHP_SELF"];
    $pos = strpos($action, "index.php");
    if ($pos !== false) {
	$action = substr($action, 0, $pos);
    }
    $geo = isset($param["geo"]) ? $param["geo"] : "geoname";
    if ($geo == "geoname" && !isset($param["city-typeahead"]) && isset($param["geonameid"])) {
        list($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) =
            hebcal_get_geoname($param["geonameid"]);
        $param["city-typeahead"] = geoname_city_descr($name,$admin1,$country);
    } elseif ($geo == "zip" && isset($param["zip"])) {
        list($city,$state,$tzid,$latitude,$longitude,
             $lat_deg,$lat_min,$long_deg,$long_min) =
            hebcal_get_zipcode_fields($param["zip"]);
        $param["city-typeahead"] = "$city, $state " . $param["zip"];
    }
?>
<div id="email-form">
<form id="f1" action="<?php echo $action ?>" method="post">
<div class="form-group">
<label for="em">E-mail address</label>
<input type="email" name="em" id="em" class="form-control" placeholder="user@example.com"
value="<?php if (isset($param["em"])) { echo htmlspecialchars($param["em"]); } ?>">
</div>
<?php if (!$default_unsubscribe) { ?>
<div class="form-group">
<label for="city-typeahead">City</label>
<input type="hidden" name="geo" id="geo" value="<?php echo $geo ?>">
<input type="hidden" name="zip" id="zip" value="<?php if (isset($param["zip"])) { echo htmlspecialchars($param["zip"]); } ?>">
<input type="hidden" name="geonameid" id="geonameid" value="<?php if (isset($param["geonameid"])) { echo htmlspecialchars($param["geonameid"]); } ?>">
<div class="city-typeahead" style="margin-bottom:12px">
<input type="text" name="city-typeahead" id="city-typeahead" class="form-control" placeholder="Search for city or ZIP code" value="<?php if (isset($param["city-typeahead"])) { echo htmlentities($param["city-typeahead"]); } ?>">
</div>
</div>
<div class="form-group">
<label for="m">Havdalah minutes past sundown
<a href="#" id="havdalahInfo" data-toggle="tooltip" data-placement="top" title="Use 42 min for three medium-sized stars, 50 min for three small stars, 72 min for Rabbeinu Tam, or 0 to suppress Havdalah times"><span class="glyphicons glyphicons-info-sign"></span></a>
</label>
<input type="text" name="m" id="m" class="form-control" pattern="\d*" value="<?php
  echo htmlspecialchars($param["m"]) ?>" maxlength="3">
</div>
<?php } /* !$default_unsubscribe */ ?>
<input type="hidden" name="v" value="1">
<?php
    $modify_class = $default_unsubscribe ? "btn btn-secondary" : "btn btn-primary";
    $unsub_class = $default_unsubscribe ? "btn btn-primary" : "btn btn-secondary";
    if ($is_update) { ?>
<input type="hidden" name="prev"
value="<?php echo htmlspecialchars($param["em"]) ?>">
<?php } ?>
<?php if (!$default_unsubscribe) { ?>
<button type="submit" class="<?php echo $modify_class ?>" name="modify" value="1">
<?php echo ($is_update) ? "Update Subscription" : "Subscribe"; ?></button>
<?php } ?>
<button type="submit" class="<?php echo $unsub_class ?>" name="unsubscribe" value="1">Unsubscribe</button>
</fieldset>
</form>
</div><!-- #email-form -->

<hr>
<p>You&apos;ll receive a maximum of one message per week, typically on Thursday morning.</p>

<div id="privacy-policy">
<h3>Email Privacy Policy</h3>
<p>We will never sell or give your email address to anyone.
<br>We will never use your email address to send you unsolicited
offers.</p>
<p>To unsubscribe, send an email to <a
href="mailto:shabbat-unsubscribe&#64;hebcal.com">shabbat-unsubscribe&#64;hebcal.com</a>.</p>
</div><!-- #privacy-policy -->
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<?php
$js_typeahead_url = hebcal_js_typeahead_bundle_url();
$js_hebcal_app_url = hebcal_js_app_url();
$xtra_html = <<<EOD
<script src="$js_typeahead_url"></script>
<script src="$js_hebcal_app_url"></script>
<script>
window['hebcal'].createCityTypeahead(false);
$('#havdalahInfo').click(function(e){
 e.preventDefault();
}).tooltip();
</script>
EOD;
    echo html_footer_bootstrap3(true, $xtra_html);
    exit();
}

function subscribe($param) {
    global $sender;
    if (preg_match('/\@hebcal.com$/', $param["em"]))
    {
	form($param,
	     "Sorry, can't use a <strong>hebcal.com</strong> email address.");
    }

    if ($param["geo"] == "zip")
    {
	if (!$param["zip"])
	{
	    form($param,
	    "Please enter your zip code for candle lighting times.");
	}

	if (!preg_match('/^\d{5}$/', $param["zip"]))
	{
	    form($param,
		 "Sorry, <strong>" . htmlspecialchars($param["zip"]) . "</strong> does\n" .
		 "not appear to be a 5-digit zip code.");
	}

	list($city,$state,$tzid,$latitude,$longitude,
	     $lat_deg,$lat_min,$long_deg,$long_min) =
	    hebcal_get_zipcode_fields($param["zip"]);

	if (!$state)
	{
	    form($param,
		 "Sorry, can't find\n".  "<strong>" . htmlspecialchars($param["zip"]) .
	    "</strong> in the zip code database.\n",
	    "<ul><li>Please try a nearby zip code</li></ul>");
	}

	$city_descr = "$city, $state " . $param["zip"];

	unset($param["city"]);
	unset($param["geonameid"]);
    }
    elseif ($param["geo"] == "geoname")
    {
	if (!$param["geonameid"])
	{
	    form($param,
	    "Please search for your city for candle lighting times.");
	}

	if (!preg_match('/^\d+$/', $param["geonameid"]))
	{
	    form($param,
		 "Sorry, <strong>" . htmlspecialchars($param["geonameid"]) . "</strong> does\n" .
		 "not appear to be a valid geonameid.");
	}

	list($name,$asciiname,$country,$admin1,$latitude,$longitude,$tzid) =
	    hebcal_get_geoname($param["geonameid"]);

	if (!isset($tzid))
	{
	    form($param,
	    "Sorry, <strong>" . htmlspecialchars($param["geonameid"]) . "</strong> is\n" .
	    "not a recoginized geonameid.");
	}

    $city_descr = geoname_city_descr($name,$admin1,$country);

	unset($param["zip"]);
	unset($param["city"]);
    }
    else
    {
	$param["geo"] = "geoname";
	form($param, "Sorry, missing location (zip, geonameid) field.");
    }

    // check for old sub
    if (isset($param["prev"]) && $param["prev"] != $param["em"]) {
	$info = get_sub_info($param["prev"], false);
	if (isset($info["status"]) && $info["status"] == "active") {
	    sql_unsub($param["prev"]);
	}
    }

    // check if email address already verified
    $info = get_sub_info($param["em"], false);
    if (isset($info["status"]) && $info["status"] == "active")
    {
	write_sub_info($param);

	$from_name = "Hebcal";
    	$from_addr = "shabbat-owner@hebcal.com";
	$reply_to = "no-reply@hebcal.com";
	$subject = "Your subscription is updated";

        global $remoteAddr;
	$ip = $remoteAddr;

        $unsub_addr = "shabbat-unsubscribe+" . $info["id"] . "@hebcal.com";

	$headers = array("From" => "\"$from_name\" <$from_addr>",
			 "To" => $param["em"],
			 "Reply-To" => $reply_to,
			 "List-Unsubscribe" => "<mailto:$unsub_addr>",
			 "MIME-Version" => "1.0",
			 "Content-Type" => "text/html; charset=UTF-8",
			 "X-Sender" => $sender,
			 "X-Mailer" => "hebcal web",
			 "Message-ID" =>
			 "<Hebcal.Web.".time().".".posix_getpid()."@hebcal.com>",
			 "X-Originating-IP" => "[$ip]",
			 "Subject" => $subject);

	$body = <<<EOD
<div dir="ltr">
<div>Hello,</div>
<div><br></div>
<div>We have updated your weekly Shabbat candle lighting time
subscription for $city_descr.</div>
<div><br></div>
<div>Regards,
<br>hebcal.com</div>
<div><br></div>
<div>To unsubscribe from this list, send an email to:
<br><a href="mailto:shabbat-unsubscribe@hebcal.com">shabbat-unsubscribe@hebcal.com</a></div>
</div>
EOD;

	$err = smtp_send(get_return_path($param["em"]), $param["em"], $headers, $body);

	$html_email = htmlentities($param["em"]);
	$html = <<<EOD
<div class="alert alert-success">
<strong>Success!</strong> Your subsciption information has been updated.
<p>Email: <strong>$html_email</strong>
<br>Location: $city_descr</p>
</div>
EOD
	     ;

	echo $html;
	return true;
    }

    if (isset($info["status"]) && $info["status"] == "pending" &&
	isset($info["id"]))
    {
	$old_encoded = $info["id"];
    }
    else
    {
	$old_encoded = null;
    }

    $encoded = write_staging_info($param, $old_encoded);

    $from_name = "Hebcal";
    $from_addr = "no-reply@hebcal.com";
    $subject = "Please confirm your request to subscribe to hebcal";

    global $remoteAddr;
    $ip = $remoteAddr;

    $headers = array("From" => "\"$from_name\" <$from_addr>",
		     "To" => $param["em"],
		     "MIME-Version" => "1.0",
		     "Content-Type" => "text/html; charset=UTF-8",
		     "X-Sender" => $sender,
		     "X-Mailer" => "hebcal web",
		     "Message-ID" =>
		     "<Hebcal.Web.".time().".".posix_getpid()."@hebcal.com>",
		     "X-Originating-IP" => "[$ip]",
		     "Subject" => $subject);

    $url_prefix = "https://" . $_SERVER["HTTP_HOST"];
    $body = <<<EOD
<div dir="ltr">
<div>Hello,</div>
<div><br></div>
<div>We have received your request to receive weekly Shabbat
candle lighting time information from hebcal.com for
$city_descr.</div>
<div><br></div>
<div>Please confirm your request by clicking on this link:</div>
<div><br></div>
<div><a href="$url_prefix/email/verify.php?$encoded">$url_prefix/email/verify.php?$encoded</a></div>
<div><br></div>
<div>If you did not request (or do not want) weekly Shabbat
candle lighting time information, please accept our
apologies and ignore this message.</div>
<div><br></div>
<div>Regards,
<br>hebcal.com</div>
<div><br></div>
<div>[$remoteAddr]</div>
</div>
EOD;

    $err = smtp_send(get_return_path($param["em"]), $param["em"], $headers, $body);
    $html_email = htmlentities($param["em"]);

    if ($err === true)
    {
	$html = <<<EOD
<div class="alert alert-success">
<strong>Thank you!</strong>
A confirmation message has been sent
to <strong>$html_email</strong> for $city_descr.<br>
Click the link within that message to confirm your subscription.
</div>
<p>If you do not receive this acknowledgment message within an hour
or two, then the most likely problem is that you made a typo
in your email address.  If you do not get the confirmation message,
please return to the subscription page and try again, taking care
to avoid typos.</p>
EOD
		     ;
    }
    else
    {
	$html = <<<EOD
<div class="alert alert-danger">
<h4>Server Error</h4>
Sorry, we are temporarily unable to send email
to <strong>$html_email</strong>.
</div>
<p>Please try again in a few minutes.</p>
<p>If the problem persists, please send email to
<a href="mailto:webmaster&#64;hebcal.com">webmaster&#64;hebcal.com</a>.</p>
EOD
	     ;
    }

    echo $html;
}

function sql_unsub($em) {
    global $remoteAddr;
    $sql = <<<EOD
UPDATE hebcal_shabbat_email
SET email_status='unsubscribed',email_ip='$remoteAddr'
WHERE email_address = '$em'
EOD;

    $mysqli = hebcal_open_mysqli_db();
    return mysqli_query($mysqli, $sql);
}

function unsubscribe($param) {
    global $sender;
    $html_email = htmlentities($param["em"]);
    $info = get_sub_info($param["em"], true);

    if (isset($info["status"]) && $info["status"] == "unsubscribed") {
	$html = <<<EOD
<div class="alert alert-warning">
<strong>$html_email</strong>
is already removed from the email subscription list.
</div>
EOD
	     ;

	echo $html;
	return false;
    }

    if (!$info) {
	form($param,
	     "Sorry, <strong>$html_email</strong> is\nnot currently subscribed.");
    }

    if (sql_unsub($param["em"]) === false) {
        $html = <<<EOD
<div class="alert alert-danger">
<h4>Database Error</h4>
Sorry, a database error occurred on our servers. Please try again later.
</div>
EOD
	     ;
        echo $html;
        return false;
    }

    $html = <<<EOD
<div class="alert alert-success">
<h4>Unsubscribed</h4>
<strong>$html_email</strong> has been removed from the email subscription list.
</div>
EOD
	     ;
    echo $html;
    return true;
}

?>
