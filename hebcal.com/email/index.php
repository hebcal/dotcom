<?php
// $Id$
// $URL$
header("Cache-Control: private");
$sender = "webmaster@hebcal.com";

require "../pear/Hebcal/smtp.inc";
require "../pear/Hebcal/common.inc";
require "../pear/HTML/Form.php";

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)/', $VER, $matches)) {
    $VER = $matches[1];
}

echo html_header_new("Shabbat Candle Lighting Times by Email",
		     "http://www.hebcal.com/email/");
?>
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">Shabbat Candle Lighting Times by Email</h1>
<div class="entry-content">
<?php

$param = array();
if (!isset($_REQUEST["v"]) && !isset($_REQUEST["e"])
    && isset($_COOKIE["C"]))
{
    parse_str($_COOKIE["C"], $param);
}

foreach($_REQUEST as $key => $value) {
    $param[$key] = trim($value);
}

if ($param["v"])
{
    $email = $param["em"];
    if (!$email)
    {
	form($param,
	     "Please enter your email address.");
    }

    $to_addr = email_address_valid($email);
    if ($to_addr == false) {
	form($param,
	     "Sorry, <b>" . htmlspecialchars($email) . "</b> does\n" .
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
	$info = get_sub_info($param["em"]);
	if (isset($info["status"]) && $info["status"] == "active") {
	    foreach ($info as $k => $v) {
		if ($k == "upd") {
		    $param[$k] = ($v == "1") ? "on" : "";
		} else {
		    $param[$k] = $v;
		}
	    }
	    if (isset($param["city"])) {
		$param["geo"] = "city";
	    }
	    $is_update = true;
	}
    }

    form($param);
}

if ($param["modify"]) {
    subscribe($param);
}
elseif ($param["unsubscribe"]) {
    unsubscribe($param);
}
else {
    form($param);
}
?>
<?php
my_footer();
exit();

function get_password() {
    $passfile = file("../hebcal-db-pass.cgi");
    $password = trim($passfile[0]);
    return $password;
}

function my_open_db() {
    global $db;
    global $db_open;
    if (!isset($db_open)) {
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
	$db_open = true;
    }
    return true;
}

function write_sub_info($param) {
    global $db;
    my_open_db();

    if ($param["geo"] == "zip")
    {
	$geo_sql = "email_candles_zipcode='$param[zip]',email_candles_city=NULL";
    }
    else if ($param["geo"] == "city")
    {
	$geo_sql = "email_candles_city='$param[city]',email_candles_zipcode=NULL";
    }

    $optin_announce = $param["upd"] ? 1 : 0;

    $sql = <<<EOD
UPDATE hebcal_shabbat_email
SET email_status='active',
    $geo_sql,
    email_candles_havdalah='$param[m]',
    email_ip='$_SERVER[REMOTE_ADDR]',
    email_optin_announce='$optin_announce'
WHERE email_address = '$param[em]'
EOD;

    return mysql_query($sql, $db);
}

function get_sub_info($email) {
    global $db;
    error_log("get_sub_info($email);");
    my_open_db();
    $sql = <<<EOD
SELECT email_id, email_address, email_status, email_created,
       email_candles_zipcode, email_candles_city,
       email_candles_havdalah, email_optin_announce
FROM hebcal_shabbat_email
WHERE hebcal_shabbat_email.email_address = '$email'
EOD;

    error_log($sql);
    $result = mysql_query($sql, $db);
    if (!$result) {
	error_log("Invalid query 1: " . mysql_error());
	return array();
    }

    $num_rows = mysql_num_rows($result);
    if ($num_rows != 1) {
	error_log("get_sub_info got $num_rows rows, expected 1");
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

function write_staging_info($param, $old_encoded)
{
    global $db;
    if ($old_encoded)
    {
	$encoded = $old_encoded;
    }
    else
    {
	$now = time();
	$rand = pack("V", $now);

	if ($_SERVER["REMOTE_ADDR"])
	{
	    list($p1,$p2,$p3,$p4) = explode(".", $_SERVER["REMOTE_ADDR"]);
	    $rand .= pack("CCCC", $p1, $p2, $p3, $p4);
	}

	# As of PHP 4.2.0, there is no need to seed the random 
	# number generator as this is now done automatically.
	$rand .= pack("V", rand());

	$encoded = bin2hex($rand);
    }

    my_open_db();

    if ($param["geo"] == "zip")
    {
	$location_name = "email_candles_zipcode";
	$location_value = $param["zip"];
    }
    else if ($param["geo"] == "city")
    {
	$location_name = "email_candles_city";
	$location_value = $param["city"];
    }

    $optin_announce = $param["upd"] ? 1 : 0;

    $sql = <<<EOD
REPLACE INTO hebcal_shabbat_email
(email_id, email_address, email_status, email_created,
 email_candles_havdalah, email_optin_announce,
 $location_name, email_ip)
VALUES ('$encoded', '$param[em]', 'pending', NOW(),
	'$param[m]', '$optin_announce',
	'$location_value', '$_SERVER[REMOTE_ADDR]')
EOD;

    $result = mysql_query($sql, $db)
	or die("Invalid query 2: " . mysql_error());

    if (mysql_affected_rows($db) < 1) {
	die("Strange numrows from MySQL:" . mysql_error());
    }

    return $encoded;
}

function form($param, $message = "", $help = "") {
    if ($message != "") {
	$message = '<hr noshade size="1"><p><font' . "\n" .
	    'color="#ff0000">' .  $message . "</font></p>" . $help . 
	    '<hr noshade size="1">';
    }

    echo $message;

    if (!$param["dst"]) {
	$param["dst"] = "usa";
    }
    if (!$param["tz"]) {
	$param["tz"] = "auto";
    }
    if (!isset($param["m"])) {
	$param["m"] = 72;
    }

?>
<p>Fill out the form to subscribe to weekly Shabbat candle
lighting times and Torah portion.
<br>Email is sent out every week on Thursday morning.</p>

<div id="email-form">
<form name="f1" id="f1" action="<?php echo $_SERVER["PHP_SELF"] ?>" method="post">
<?php if (isset($param["geo"]) && $param["geo"] == "city") { ?>
<input type="hidden" name="geo" value="city">
<label for="city">Closest City:</label>
<?php
global $hebcal_city_tz;
$entries = array();
foreach ($hebcal_city_tz as $k => $v) {
    $entries[$k] = $k;
}
if ($param["city"]) {
    $geo_city = htmlspecialchars($param["city"]);
}
echo HTML_Form::returnSelect("city", $entries,
			     $geo_city ? $geo_city : "Jerusalem", 1,
			     "", false, 'id="city"');
?>
&nbsp;&nbsp;<small>(or select by <a
href="<?php echo $_SERVER["PHP_SELF"] ?>?geo=zip">zip code</a>)</small>
<?php } else { ?>
<input type="hidden" name="geo" value="zip">
<label for="zip">Zip code:
<input type="text" name="zip" size="5" maxlength="5" id="zip"
value="<?php echo htmlspecialchars($param["zip"]) ?>"></label>
&nbsp;&nbsp;<small>(or select by <a
href="<?php echo $_SERVER["PHP_SELF"] ?>?geo=city">closest city</a>)</small>
<?php } ?>
<br><label for="m1">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php
  echo htmlspecialchars($param["m"]) ?>" size="3" maxlength="3" id="m1">
</label>
<br><label for="em">E-mail address:
<input type="text" name="em" size="30"
value="<?php echo htmlspecialchars($param["em"]) ?>" id="em">
</label>
<br><label for="upd">
<input type="checkbox" name="upd" value="on" <?php
  if ($param["upd"] == "on") { echo "checked"; } ?> id="upd">
Contact me occasionally about changes to the hebcal.com website.
</label>
<input type="hidden" name="v" value="1">
<?php global $is_update;
    if ($is_update) { ?>
<input type="hidden" name="prev"
value="<?php echo htmlspecialchars($param["em"]) ?>">
<?php } ?> 
<br><input type="submit" name="modify" value="<?php
  echo ($is_update) ? "Modify Subscription" : "Subscribe"; ?>">
or
<input type="submit" name="unsubscribe" value="Unsubscribe">
</form>
</div><!-- #email-form -->

<div id="privacy-policy">
<h3>Email Privacy Policy</h3>
<p>We will never sell or give your email address to anyone.
<br>We will never use your email address to send you unsolicited
offers.</p>
<p>To unsubscribe, send an email to <a
href="mailto:shabbat-unsubscribe&#64;hebcal.com">shabbat-unsubscribe&#64;hebcal.com</a>.</p>
</div><!-- #privacy-policy -->
<?php
    my_footer();
    exit();
}

function my_footer() {
    $html .= <<<EOD
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOD;
    echo $html;
    echo html_footer_new();
}

function subscribe($param) {
    global $sender, $VER;
    if (preg_match('/\@hebcal.com$/', $param["em"]))
    {
	form($param,
	     "Sorry, can't use a <b>hebcal.com</b> email address.");
    }

    if ($param["geo"] == "zip")
    {
	if (!$param["zip"])
	{
	    form($param,
	    "Please enter your zip code for candle lighting times.");
	}

	if (!$param["dst"]) {
	    $param["dst"] = "usa";
	}
	if (!$param["tz"]) {
	    $param["tz"] = "auto";
	}

	if (!preg_match('/^\d{5}$/', $param["zip"]))
	{
	    form($param,
	    "Sorry, <b>" . $param["zip"] . "</b> does\n" .
	    "not appear to be a 5-digit zip code.");
	}

	$password = get_password();
	list($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    hebcal_get_zipcode_fields($param["zip"], $password);

	if (!$state)
	{
	    form($param,
	    "Sorry, can't find\n".  "<b>" . $param["zip"] .
	    "</b> in the zip code database.\n",
	    "<ul><li>Please try a nearby zip code</li></ul>");
	}

	$city_descr = "$city, $state " . $param["zip"];

	// handle timezone == "auto"
	if ($tz == "?" || $tz == "0")
	{
	    form($param,
	    "Sorry, can't auto-detect\n" .
	    "timezone for <b>" . $city_descr . "</b>\n",
	    "<ul><li>Please select your time zone below.</li></ul>");
	}

	global $hebcal_tz_names;
	$param["tz"] = $tz;
	$tz_descr = "Time zone: " . $hebcal_tz_names["tz_" . $tz];

	if ($dst) {
	    $param["dst"] = "usa";
	} else {
	    $param["dst"] = "none";
	}

	$dst_descr = "Daylight Saving Time: " . $param["dst"];

	unset($param["city"]);
    }
    else if ($param["geo"] == "city")
    {
	if (!$param["city"])
	{
	    form($param,
	    "Please select a city for candle lighting times.");
	}

	global $hebcal_city_tz;
	if (!isset($hebcal_city_tz[$param["city"]]))
	{
	    form($param,
	    "Sorry, <b>" . htmlspecialchars($param["city"]) . "</b> is\n" .
	    "not a recoginized city.");
	}

	$city_descr = $param["city"];
	global $hebcal_tz_names;
	$tz_descr = "Time zone: " .
	     $hebcal_tz_names["tz_" . $hebcal_city_tz[$param["city"]]];
	$dst_descr = "";

	unset($param["zip"]);
    }
    else
    {
	$param["geo"] = "zip";
	form($param, "Sorry, missing zip or city field.");
    }

    # check for old sub
    if (isset($param["prev"]) && $param["prev"] != $param["em"]) {
	$info = get_sub_info($param["prev"]);
	if (isset($info["status"]) && $info["status"] == "active") {
	    sql_unsub($param["prev"]);
	}
    }

    # check if email address already verified
    $info = get_sub_info($param["em"]);
    if (isset($info["status"]) && $info["status"] == "active")
    {
	write_sub_info($param);

	$from_name = "Hebcal Subscription Notification";
    	$from_addr = "shabbat-owner@hebcal.com";
	$return_path = "shabbat-return-" . strtr($param["em"], "@", "=") .
	    "@hebcal.com";
	$subject = "Your subscription is updated";

	$ip = $_SERVER["REMOTE_ADDR"];

	$headers = array("From" => "\"$from_name\" <$from_addr>",
			 "To" => $param["em"],
			 "Reply-To" => $from_addr,
			 "List-Unsubscribe" =>
			 "<mailto:shabbat-unsubscribe@hebcal.com>",
			 "MIME-Version" => "1.0",
			 "Content-Type" => "text/plain",
			 "X-Sender" => $sender,
			 "X-Mailer" => "hebcal web v$VER",
			 "Message-ID" =>
			 "<Hebcal.Web.$VER.".time().".".posix_getpid()."@hebcal.com>",
			 "X-Originating-IP" => "[$ip]",
			 "Subject" => $subject);

	$body = <<<EOD
Hello,

We have updated your weekly Shabbat candle lighting time
subscription for $city_descr.

Regards,
hebcal.com

To unsubscribe from this list, send an email to:
shabbat-unsubscribe@hebcal.com
EOD;

	$err = smtp_send($return_path, $param["em"], $headers, $body);

	$html = <<<EOD
<h2>Subscription Updated</h2>
<p>Your subsciption information has been updated successfully.</p>
<p><small>
$city_descr
<br>&nbsp;&nbsp;$tz_descr
<br>&nbsp;&nbsp;$dst_descr
</small></p>
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

    $from_name = "Hebcal Subscription Notification";
    $return_path = "shabbat-return-" . strtr($param["em"], "@", "=") .
	"@hebcal.com";
    $from_addr = "no-reply@hebcal.com";
    $subject = "Please confirm your request to subscribe to hebcal";

    $ip = $_SERVER["REMOTE_ADDR"];

    $headers = array("From" => "\"$from_name\" <$from_addr>",
		     "To" => $param["em"],
		     "MIME-Version" => "1.0",
		     "Content-Type" => "text/plain",
		     "X-Sender" => $sender,
		     "X-Mailer" => "hebcal web v$VER",
		     "Message-ID" =>
		     "<Hebcal.Web.$VER.".time().".".posix_getpid()."@hebcal.com>",
		     "X-Originating-IP" => "[$ip]",
		     "Subject" => $subject);

    $body = <<<EOD
Hello,

We have received your request to receive weekly Shabbat
candle lighting time information from hebcal.com for
$city_descr.

Please confirm your request by clicking on this link:

http://www.hebcal.com/email/verify.php?$encoded

If you did not request (or do not want) weekly Shabbat
candle lighting time information, please accept our
apologies and ignore this message.

Regards,
hebcal.com

[$_SERVER[REMOTE_ADDR]]
EOD;

    $err = smtp_send($return_path, $param["em"], $headers, $body);
    $html_email = htmlentities($param["em"]);

    if ($err === true)
    {
	$html = <<<EOD
<p>Thank you for your interest in weekly
candle lighting times and parsha information.</p>
<p>A confirmation message has been sent
to <b>$html_email</b>.<br>
Click the link within that message to confirm your subscription.</p>
<p>If you do not receive this acknowledgment message within an hour
or two, then the most likely problem is that you made a typo
in your email address.  If you do not get the confirmation message,
please return to the subscription page and try again, taking care
to avoid typos.</p>
<p><small>
$city_descr
<br>&nbsp;&nbsp;$tz_descr
<br>&nbsp;&nbsp;$dst_descr
</small></p>
EOD
		     ;
    }
    else
    {
	$html = <<<EOD
<h2>Sorry!</h2>
<p>Unfortunately, we are temporarily unable to send email
to <b>$html_email</b>.</p>
<p>Please try again in a few minutes.</p>
<p>If the problem persists, please send email to
<a href="mailto:webmaster&#64;hebcal.com">webmaster&#64;hebcal.com</a>.</p>
EOD
	     ;
    }

    echo $html;
}

function sql_unsub($em) {
    global $db;
    my_open_db();
    $sql = <<<EOD
UPDATE hebcal_shabbat_email
SET email_status='unsubscribed',email_ip='$_SERVER[REMOTE_ADDR]'
WHERE email_address = '$em'
EOD;

   return mysql_query($sql, $db);
}

function unsubscribe($param) {
    global $sender, $VER;
    $html_email = htmlentities($param["em"]);
    $info = get_sub_info($param["em"]);

    if (isset($info["status"]) && $info["status"] == "unsubscribed") {
	$html = <<<EOD
<h2>Already Unsubscribed</h2>
<p><b>$html_email</b>
is already removed from the email subscription list.</p>
EOD
	     ;

	echo $html;
	return false;
    }

    if (!$info) {
	form($param,
	     "Sorry, <b>$html_email</b> is\nnot currently subscribed.");
    }

    if (sql_unsub($param["em"]) === false) {
        $html = <<<EOD
<h2>Database error</h2>
<p>Sorry, an error occurred.  Please try again later.</p>
EOD
	     ;
        echo $html;
        return false;
    }

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-owner@hebcal.com";
    $return_path = "shabbat-return-" . strtr($param["em"], "@", "=") .
	"@hebcal.com";
    $subject = "You have been unsubscribed from hebcal";

    $ip = $_SERVER["REMOTE_ADDR"];

    $headers = array("From" => "\"$from_name\" <$from_addr>",
		     "To" => $param["em"],
		     "Reply-To" => $from_addr,
		     "MIME-Version" => "1.0",
		     "Content-Type" => "text/plain",
		     "X-Sender" => $sender,
		     "X-Mailer" => "hebcal web v$VER",
		     "Message-ID" =>
		     "<Hebcal.Web.$VER.".time().".".posix_getpid()."@hebcal.com>",
		     "X-Originating-IP" => "[$ip]",
		     "Subject" => $subject);

    $body = <<<EOD
Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
hebcal.com
EOD;

    $err = smtp_send($return_path, $param["em"], $headers, $body);

    $html = <<<EOD
<h2>Unsubscribed</h2>
<p>You have been removed from the email subscription list.<br>
A confirmation message has been sent to <b>$html_email</b>.</p>
EOD
	     ;
    echo $html;
    return true;
}

?>
