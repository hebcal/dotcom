<?php
// $Id$
// $Source: /Users/mradwin/hebcal-copy/hebcal.com/email/RCS/index.php,v $
header("Cache-Control: private");
global $HTTP_SERVER_VARS;
$site = preg_replace('/^www\./', '', $HTTP_SERVER_VARS["SERVER_NAME"]);
$sender = "webmaster@$site";
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Hebcal 1-Click Shabbat by Email</title>
<base href="http://www.<?php echo $site ?>/email/" target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
</head><body><table width="100%"
class="navbar"><tr><td><small><strong><a
href="/"><?php echo $site ?></a></strong>
<tt>-&gt;</tt>
<a href="/shabbat/">1-Click Shabbat</a>
<tt>-&gt;</tt>
Email</small></td><td align="right"><small><a
href="/help/">Help</a> -
<a href="/search/">Search</a></small>
</td></tr></table><h1>1-Click Shabbat by Email</h1>
<?php
require_once('smtp.inc');
require_once('zips.inc');
require_once('HTML/Form.php');

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)\.(\d+)/', $VER, $matches)) {
    $VER = $matches[1] . "." . $matches[2];
}

$param = array();

global $HTTP_POST_VARS;
global $HTTP_GET_VARS;

if (!isset($HTTP_POST_VARS['v']) && !isset($HTTP_GET_VARS['v']) &&
    !isset($HTTP_POST_VARS['e']) && !isset($HTTP_GET_VARS['e']))
{
$cookies = explode(';', $HTTP_SERVER_VARS["HTTP_COOKIE"]);
foreach ($cookies as $ck) {
    if (substr($ck, 0, 2) == 'C=') {
	$cookie_parts = explode('&', substr($ck, 2));
	for ($i = 0; $i < count($cookie_parts); $i++) {
	    $parts = explode('=', $cookie_parts[$i], 2);
	    $param[$parts[0]] = $parts[1];
	}
    }
}
}

foreach($HTTP_POST_VARS as $key => $value) {
    $param[$key] = $value;
}
foreach($HTTP_GET_VARS as $key => $value) {
    $param[$key] = $value;
}

if (isset($param['e']))
{
    $param['em'] = base64_decode($param['e']);
    $info = get_sub_info($param['em']);
    if (isset($info['status']) && $info['status'] == 'active') {
	foreach ($info as $k => $v) {
	    if ($k == 'upd') {
		$param[$k] = ($v == '1') ? 'on' : '';
	    } else {
		$param[$k] = $v;
	    }
	}
	if (isset($param['city'])) {
	    $param['geo'] = 'city';
	}
    }
}

if ($param['v'])
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
    
    $param['em'] = strtolower($email);
}
else
{
    form($param);
}

if ($param['submit_modify']) {
    subscribe($param);
}
elseif ($param['submit_unsubscribe']) {
    unsubscribe($param);
}
else {
    form($param);
}
my_footer();

function my_open_db() {
    $passfile = file('hebcal-db-pass.cgi');
    $password = trim($passfile[0]);
    $db = mysql_pconnect('mysql.hebcal.com', 'mradwin_hebcal', $password)
	or die("Could not connect: " . mysql_error());
    return $db;
}

function write_sub_info($param) {
    $db = my_open_db();

    if ($param['geo'] == 'zip')
    {
	$geo_sql = "email_candles_zipcode='$param[zip]',email_candles_city=NULL";
    }
    else if ($param['geo'] == 'city')
    {
	$geo_sql = "email_candles_city='$param[city]',email_candles_zipcode=NULL";
    }

    $optin_announce = $param['upd'] ? 1 : 0;

    $sql = <<<EOD
UPDATE hebcal1.hebcal_shabbat_email
SET email_status='active',
    $geo_sql,
    email_candles_havdalah='$param[m]',
    email_optin_announce='$optin_announce'
WHERE email_address = '$param[em]'
EOD;

    return mysql_query($sql, $db);
}

function get_sub_info($email) {
    $db = my_open_db();
    $sql = <<<EOD
SELECT email_id, email_address, email_status, email_created,
       email_candles_zipcode, email_candles_city,
       email_candles_havdalah, email_optin_announce
FROM hebcal1.hebcal_shabbat_email
WHERE hebcal1.hebcal_shabbat_email.email_address = '$email'
EOD;

    $result = mysql_query($sql, $db)
	or die("Invalid query 1: " . mysql_error());

    if (mysql_num_rows($result) != 1) {
	return array();
    }

    list($id,$address,$status,$created,$zip,$city,
	 $havdalah,$optin_announce) = mysql_fetch_row($result);

    $val = array(
	'id' => $id,
	'status' => $status,
	'em' => $address,
	'm' => $havdalah,
	'upd' => $optin_announce,
	'zip' => $zip,
	'tz' => $timezone,
	'dst' => $dst,
	'city' => $city,
	't' => $created,
	);

    return $val;
}

function write_staging_info($param, $old_encoded)
{
    global $HTTP_SERVER_VARS;

    if ($old_encoded)
    {
	$encoded = $old_encoded;
    }
    else
    {
	$now = time();
	$rand = pack("V", $now);

	if ($HTTP_SERVER_VARS["REMOTE_ADDR"])
	{
	    list($p1,$p2,$p3,$p4) = explode('.', $HTTP_SERVER_VARS["REMOTE_ADDR"]);
	    $rand .= pack("CCCC", $p1, $p2, $p3, $p4);
	}

	# As of PHP 4.2.0, there is no need to seed the random 
	# number generator as this is now done automatically.
	$rand .= pack("V", rand());

	$encoded = bin2hex($rand);
    }

    $db = my_open_db();

    if ($param['geo'] == 'zip')
    {
	$location_name = 'email_candles_zipcode';
	$location_value = $param['zip'];
    }
    else if ($param['geo'] == 'city')
    {
	$location_name = 'email_candles_city';
	$location_value = $param['city'];
    }

    $optin_announce = $param['upd'] ? 1 : 0;

    $sql = <<<EOD
REPLACE INTO hebcal1.hebcal_shabbat_email
(email_id, email_address, email_status, email_created,
 email_candles_havdalah, email_optin_announce,
 $location_name)
VALUES ('$encoded', '$param[em]', 'pending', NOW(),
	'$param[m]', '$optin_announce',
	'$location_value')
EOD;

    $result = mysql_query($sql, $db)
	or die("Invalid query 2: " . mysql_error());

    if (mysql_affected_rows($db) < 1) {
	die("Strange numrows from MySQL:" . mysql_error());
    }

    return $encoded;
}


function my_footer() {
    global $HTTP_SERVER_VARS;
    $stat = stat($HTTP_SERVER_VARS["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%c", $stat[9]);
    global $VER;
    global $site;

    $html = <<<EOD
<hr noshade size="1"><span class="tiny">
<a name="copyright">Copyright &copy; $year
Michael J. Radwin. All rights reserved.</a>
<a target="_top" href="http://www.$site/privacy/">Privacy Policy</a> -
<a target="_top" href="http://www.$site/help/">Help</a> -
<a target="_top" href="http://www.$site/contact/">Contact</a>
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.3 for UNIX</a>, Copyright &copy; 2002 Danny Sadinoff. All rights reserved.
<br>Software last updated: $date (Revision: $VER) 
</span>
</body></html>
EOD
	;
    echo $html;
    exit();
}

function form($param, $message = '', $help = '') {
    global $site;

    if ($message != '') {
	$message = '<hr noshade size="1"><p><font' . "\n" .
	    'color="#ff0000">' .  $message . '</font></p>' . $help . 
	    '<hr noshade size="1">';
    }

    echo $message;

    if (!$param['dst']) {
	$param['dst'] = 'usa';
    }
    if (!$param['tz']) {
	$param['tz'] = 'auto';
    }
    if (!$param['m']) {
	$param['m'] = 72;
    }

?>
<p>Fill out the form to subscribe to email weekly Shabbat candle
lighting times.  Email is sent out every week on Thursday morning.</p>

<form name="f1" id="f1" action="/email/" method="post">

<?php if (isset($param['geo']) && $param['geo'] == 'city') { ?>
<input type="hidden" name="geo" value="city">
<label for="city">Closest City:</label>
<?php
global $city_tz;
$entries = array();
foreach ($city_tz as $k => $v) {
    $entries[$k] = $k;
}
if ($param['city']) {
    $geo_city = htmlspecialchars($param['city']);
}
echo HTML_Form::returnSelect('city', $entries,
			     $geo_city ? $geo_city : 'Jerusalem', 1,
			     '', false, 'id="city"');
?>
&nbsp;&nbsp;<small>(or select by <a
href="/email/?geo=zip">zip code</a></small>)
<?php } else { ?>
<input type="hidden" name="geo" value="zip">
<label for="zip">Zip code:
<input type="text" name="zip" size="5" maxlength="5" id="zip"
value="<?php echo htmlspecialchars($param['zip']) ?>"></label>
&nbsp;&nbsp;<small>(or select by <a
href="/email/?geo=city">closest city</a></small>)
<?php } ?>

<br><label for="m1">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php
  echo htmlspecialchars($param['m']) ?>" size="3" maxlength="3" id="m1">
</label>

<br><label for="em">E-mail address:
<input type="text" name="em" size="30"
value="<?php echo htmlspecialchars($param['em']) ?>" id="em">
</label>

<br><label for="upd">
<input type="checkbox" name="upd" value="on" <?php
  if ($param['upd'] == 'on') { echo 'checked'; } ?> id="upd">
Contact me occasionally about changes to the <?php
  echo $site ?> website.
</label>

<br>
<input type="hidden" name="v" value="1">
<br>
<input type="submit" name="submit_modify" value="Subscribe">
<input type="submit" name="submit_unsubscribe" value="Unsubscribe">
</form>

<p><hr noshade size="1">
<h3><a name="privacy">Email Privacy Policy</a></h3>

<p>We will never sell or give your email address to anyone.
<br>We will never use your email address to send you unsolicited
offers.</p>

<p>To unsubscribe, send an email to <a
href="mailto:shabbat-unsubscribe&#64;<?php
 echo $site ?>">shabbat-unsubscribe&#64;<?php echo $site ?></a>.</p>

<?php
    my_footer();
}

function subscribe($param) {
    global $site, $sender, $VER;
    if (preg_match('/\@' . $site . '$/', $param['em']))
    {
	form($param,
	     "Sorry, can't use a <b>$site</b> email address.");
    }

    if ($param['geo'] == 'zip')
    {
	if (!$param['zip'])
	{
	    form($param,
	    "Please enter your zip code for candle lighting times.");
	}

	if (!$param['dst']) {
	    $param['dst'] = 'usa';
	}
	if (!$param['tz']) {
	    $param['tz'] = 'auto';
	}

	if (!preg_match('/^\d{5}$/', $param['zip']))
	{
	    form($param,
	    "Sorry, <b>" . $param['zip'] . "</b> does\n" .
	    "not appear to be a 5-digit zip code.");
	}

	list($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    get_zipcode_fields($param['zip']);
	if (!$state)
	{
	    form($param,
	    "Sorry, can't find\n".  "<b>" . $param['zip'] .
	    "</b> in the zip code database.\n",
	    "<ul><li>Please try a nearby zip code</li></ul>");
	}

	$city_descr = "$city, $state " . $param['zip'];

	// handle timezone == "auto"
	if ($tz == '?' || $tz == '0')
	{
	    form($param,
	    "Sorry, can't auto-detect\n" .
	    "timezone for <b>" . $city_descr . "</b>\n",
	    "<ul><li>Please select your time zone below.</li></ul>");
	}

	global $tz_names;
	$param['tz'] = $tz;
	$tz_descr = "Time zone: " . $tz_names['tz_' . $tz];

	if ($dst) {
	    $param['dst'] = 'usa';
	} else {
	    $param['dst'] = 'none';
	}

	$dst_descr = "Daylight Saving Time: " . $param['dst'];

	unset($param['city']);
    }
    else if ($param['geo'] == 'city')
    {
	if (!$param['city'])
	{
	    form($param,
	    "Please select a city for candle lighting times.");
	}

	global $city_tz;
	if (!isset($city_tz[$param['city']]))
	{
	    form($param,
	    "Sorry, <b>" . htmlspecialchars($param['city']) . "</b> is\n" .
	    "not a recoginized city.");
	}

	$city_descr = $param['city'];
	global $tz_names;
	$tz_descr = "Time zone: " .
	     $tz_names['tz_' . $city_tz[$param['city']]];
	$dst_descr = '';

	unset($param['zip']);
    }
    else
    {
	$param['geo'] = 'zip';
	form($param, "Sorry, missing zip or city field.");
    }

    # check if email address already verified
    $info = get_sub_info($param['em']);
    if (isset($info['status']) && $info['status'] == 'active')
    {
	write_sub_info($param);

	$from_name = "Hebcal Subscription Notification";
    	$from_addr = "shabbat-owner@$site";
	$return_path = "shabbat-return-" . strtr($param['em'], '@', '=') . "@$site";
	$subject = "Your subscription is updated";

	global $HTTP_SERVER_VARS;
	$ip = $HTTP_SERVER_VARS["REMOTE_ADDR"];

	$headers = array('From' => "\"$from_name\" <$from_addr>",
			 'To' => $param['em'],
			 'Reply-To' => $from_addr,
			 'List-Unsubscribe' =>
			 "<mailto:shabbat-unsubscribe@$site>",
			 'MIME-Version' => '1.0',
			 'Content-Type' => 'text/plain',
			 'X-Sender' => $sender,
			 'X-Mailer' => "hebcal web v$VER",
			 'Message-ID' =>
			 "<Hebcal.Web.$VER.".time().".".posix_getpid()."@$site>",
			 'X-Originating-IP' => "[$ip]",
			 'Subject' => $subject);

	$body = <<<EOD
Hello,

We have updated your weekly Shabbat candle lighting time
subscription for $city_descr.

Regards,
$site

To unsubscribe from this list, send an email to:
shabbat-unsubscribe@$site
EOD;

	$err = smtp_send($return_path, $param['em'], $headers, $body);

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

    if (isset($info['status']) && $info['status'] == 'pending' && isset($info['id']))
    {
	$old_encoded = $info['id'];
    }
    else
    {
	$old_encoded = null;
    }

    $encoded = write_staging_info($param, $old_encoded);

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-subscribe-$encoded@$site";
    $return_path = "shabbat-return-" . strtr($param['em'], '@', '=') . "@$site";
    $subject = "Please confirm your request to subscribe to hebcal";

    global $HTTP_SERVER_VARS;
    $ip = $HTTP_SERVER_VARS["REMOTE_ADDR"];

    $headers = array('From' => "\"$from_name\" <$from_addr>",
		     'To' => $param['em'],
		     'Reply-To' => $from_addr,
		     'MIME-Version' => '1.0',
		     'Content-Type' => 'text/plain',
		     'X-Sender' => $sender,
		     'X-Mailer' => "hebcal web v$VER",
		     'Message-ID' =>
		     "<Hebcal.Web.$VER.".time().".".posix_getpid()."@$site>",
		     'X-Originating-IP' => "[$ip]",
		     'Subject' => $subject);

    $body = <<<EOD
Hello,

We have received your request to receive weekly Shabbat
candle lighting time information from $site for
$city_descr.

Please confirm your request by replying to this message.

If you did not request (or do not want) weekly Shabbat
candle lighting time information, please accept our
apologies and ignore this message.

Regards,
$site
EOD;

    $err = smtp_send($return_path, $param['em'], $headers, $body);
    $html_email = htmlentities($param['em']);

    if ($err === true)
    {
	$html = <<<EOD
<p>Thank you for your interest in weekly
candle lighting times and parsha information.</p>
<p>A confirmation message has been sent
to <b>$html_email</b>.<br>
Simply reply to that message to confirm your subscription.</p>
<p>If you do not receive this acknowledgment message within an hour
or two, then the most likely problem is that you made a typo
in your email address.  If you don't get the confirmation message,
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
<a href="mailto:webmaster&#64;$site">webmaster&#64;$site</a>.</p>
EOD
	     ;
    }

    echo $html;
}

function unsubscribe($param) {
    global $site, $sender, $VER;
    $html_email = htmlentities($param['em']);
    $info = get_sub_info($param['em']);

    if (isset($info['status']) && $info['status'] == 'unsubscribed') {
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

    $db = my_open_db();
    $sql = <<<EOD
UPDATE hebcal1.hebcal_shabbat_email
SET email_status='unsubscribed'
WHERE email_address = '$param[em]'
EOD;
    if (mysql_query($sql, $db) === false) {
        $html = <<<EOD
<h2>Database error</h2>
<p>Sorry, an error occurred.  Please try again later.</p>
EOD
	     ;
        echo $html;
        return false;
    }

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-owner@$site";
    $return_path = "shabbat-return-" . strtr($param['em'], '@', '=') . "@$site";
    $subject = "You have been unsubscribed from hebcal";

    global $HTTP_SERVER_VARS;
    $ip = $HTTP_SERVER_VARS["REMOTE_ADDR"];

    $headers = array('From' => "\"$from_name\" <$from_addr>",
		     'To' => $param['em'],
		     'Reply-To' => $from_addr,
		     'MIME-Version' => '1.0',
		     'Content-Type' => 'text/plain',
		     'X-Sender' => $sender,
		     'X-Mailer' => "hebcal web v$VER",
		     'Message-ID' =>
		     "<Hebcal.Web.$VER.".time().".".posix_getpid()."@$site>",
		     'X-Originating-IP' => "[$ip]",
		     'Subject' => $subject);

    $body = <<<EOD
Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
$site
EOD;

    $err = smtp_send($return_path, $param['em'], $headers, $body);

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
