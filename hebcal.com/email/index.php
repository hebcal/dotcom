<?php
// $Id$
// $Source: /Users/mradwin/hebcal-copy/hebcal.com/email/RCS/index.php,v $
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Hebcal 1-Click Shabbat by Email</title>
<base href="http://www.hebcal.com/email/" target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
<link type="text/css" media="print" rel="stylesheet" href="/print.css">
</head><body><table width="100%"
class="navbar"><tr><td><small><strong><a
href="/">hebcal.com</a></strong>
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
require_once('dblock.inc');
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
global $HTTP_SERVER_VARS;
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
    if ($info && !preg_match('/^action=/', $info)) {
	$array = explode(';', $info);
	foreach ($array as $i) {
	    $parts = explode('=', $i, 2);
	    if ($parts[0] == 'upd') {
		$parts[1] = ($parts[1] == '1') ? 'on' : '';
	    }
	    $param[$parts[0]] = $parts[1];
	}
	if (isset($param['city'])) {
	    $param['geo'] = 'city';
	    $param['city'] = urldecode($param['city']);
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

function write_sub_info($email, $val) {
    list($id, $fd) = dba_lock_open("subs.db", "w", "db3");

    if (!$id) {
	die("dba_open subs.db failed");
    }

    if (!dba_replace($email, $val, $id)) {
	die("dba_replace subs.db failed");
    }

    dba_lock_close($id, $fd);

    return true;
}

function get_sub_info($email) {
    list($id, $fd) = dba_lock_open("subs.db", "r", "db3");

    if (!$id) {
	die("dba_open subs.db failed");
    }

    $val = dba_fetch($email, $id);

    dba_lock_close($id, $fd);

    return $val;
}

function write_staging_info($param)
{
    global $HTTP_SERVER_VARS;

    $now = time();
    $rand = pack("V", rand());
    if ($HTTP_SERVER_VARS["REMOTE_ADDR"]) {
	list($p1,$p2,$p3,$p4) = explode('.', $HTTP_SERVER_VARS["REMOTE_ADDR"]);
	$rand .= pack("CCCC", $p1, $p2, $p3, $p4);
    }
    $rand .= pack("V", $now);

    $encoded = rtrim(base64_encode($rand));
    $encoded = strtr($encoded, '+/=', '._-');
    $encoded = strtolower($encoded);

    list($id, $fd) = dba_lock_open("email.db", "w", "db3");

    if ($param['geo'] == 'zip')
    {
	$val = sprintf("zip=%s;tz=%s;dst=%s",
		       $param['zip'],
		       $param['tz'],
		       $param['dst']);
    }
    else if ($param['geo'] == 'city')
    {
	$val = 'city=' . urlencode($param['city']);
    }
    else
    {
	$val = 'bogus=1';
    }

    $val .= sprintf(";m=%s;upd=%d;t=%d;em=%s",
		   $param['m'],
		   $param['upd'] ? 1 : 0,
		   $now,
		   $param['em']);

    if (!dba_replace($encoded, $val, $id)) {
	die("dba_replace email.db failed");
    }

    dba_lock_close($id, $fd);

    return $encoded;
}


function my_footer() {
    global $HTTP_SERVER_VARS;
    $stat = stat($HTTP_SERVER_VARS["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%c", $stat[9]);
    global $VER;

    $html = <<<EOD
<hr noshade size="1"><span class="tiny">
<a name="copyright">Copyright &copy; $year
Michael J. Radwin. All rights reserved.</a>
<a target="_top" href="http://www.hebcal.com/privacy/">Privacy Policy</a> -
<a target="_top" href="http://www.hebcal.com/help/">Help</a> -
<a target="_top" href="http://www.hebcal.com/contact/">Contact</a>
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
Contact me occasionally about changes to the hebcal.com website.
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
href="mailto:shabbat-unsubscribe@hebcal.com">shabbat-unsubscribe@hebcal.com</a>.</p>

<?php
    my_footer();
}

function subscribe($param) {
    $recipients = $param['em'];
    if (preg_match('/\@hebcal.com$/', $recipients))
    {
	form($param,
	     "Sorry, can't use a <b>hebcal.com</b> email address.");
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
	if ($tz == '?')
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

	$geo_args = sprintf("zip=%s;tz=%s;dst=%s",
			    $param['zip'],
			    $param['tz'],
			    $param['dst']);
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

	$geo_args = "city=" . urlencode($param['city']);
	$city_descr = $param['city'];
	global $tz_names;
	$tz_descr = "Time zone: " .
	     $tz_names['tz_' . $city_tz[$param['city']]];
	$dst_descr = '';
    }
    else
    {
	$param['geo'] = 'zip';
	form($param, "Sorry, missing zip or city field.");
    }

    # check if email address already verified
    $info = get_sub_info($recipients);
    if ($info && !preg_match('/^action=/', $info))
    {
	$now = time();
	write_sub_info(
	    $recipients, 
	    sprintf("%s;m=%s;upd=%d;t=%d",
		    $geo_args,
		    $param['m'],
		    $param['upd'] ? 1 : 0,
		    $now)
	    );

	$from_name = "Hebcal Subscription Notification";
    	$from_addr = "shabbat-owner@hebcal.com";
	$return_path = "shabbat-bounce@hebcal.com";
	$subject = "Your subscription is updated";

	global $HTTP_SERVER_VARS;
	$sender =  'webmaster@';
	$sender .= $HTTP_SERVER_VARS["SERVER_NAME"];

	$ip = $HTTP_SERVER_VARS["REMOTE_ADDR"];

	$headers = array('From' => "\"$from_name\" <$from_addr>",
			 'To' => $recipients,
			 'Reply-To' => $from_addr,
			 'List-Unsubscribe' =>
			 "<mailto:shabbat-unsubscribe@hebcal.com>",
			 'MIME-Version' => '1.0',
			 'Content-Type' => 'text/plain',
			 'X-Sender' => $sender,
			 'X-Originating-IP' => "[$ip]",
			 'Subject' => $subject);

	$body = <<<EOD
Hello,

We have updated your weekly Shabbat candle lighting time
subscription for $city_descr.

Regards,
hebcal.com

To unsubscribe from this list, send an email to:
shabbat-unsubscribe@hebcal.com
EOD;

	$err = smtp_send($return_path, $recipients, $headers, $body);

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

    $encoded = write_staging_info($param);

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-subscribe+$encoded@hebcal.com";
    $return_path = "shabbat-bounce@hebcal.com";
    $subject = "Please confirm your request to subscribe to hebcal";

    global $HTTP_SERVER_VARS;
    $sender =  'webmaster@';
    $sender .= $HTTP_SERVER_VARS["SERVER_NAME"];

    $ip = $HTTP_SERVER_VARS["REMOTE_ADDR"];

    $headers = array('From' => "\"$from_name\" <$from_addr>",
		     'To' => $recipients,
		     'Reply-To' => $from_addr,
		     'MIME-Version' => '1.0',
		     'Content-Type' => 'text/plain',
		     'X-Sender' => $sender,
		     'X-Originating-IP' => "[$ip]",
		     'Subject' => $subject);

    $body = <<<EOD
Hello,

We have received your request to receive weekly Shabbat
candle lighting time information from hebcal.com for
$city_descr.

Please confirm your request by replying to this message.

If you did not request (or do not want) weekly Shabbat
candle lighting time information, please accept our
apologies and ignore this message.

Regards,
hebcal.com
EOD;

    $err = smtp_send($return_path, $recipients, $headers, $body);
    $html_email = htmlentities($recipients);

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
<a href="mailto:webmaster@hebcal.com">webmaster@hebcal.com</a>.</p>
EOD
	     ;
    }

    echo $html;
}

function unsubscribe($param) {
    $html_email = htmlentities($param['em']);
    $info = get_sub_info($param['em']);

    if ($info && preg_match('/^action=/', $info)) {
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

    $now = time();

    write_sub_info($param['em'], "action=UNSUBSCRIBE;t=$now");

    $from_name = "Hebcal Subscription Notification";
    $from_addr = "shabbat-owner@hebcal.com";
    $return_path = "shabbat-bounce@hebcal.com";
    $subject = "You have been unsubscribed from hebcal";

    global $HTTP_SERVER_VARS;
    $sender =  'webmaster@';
    $sender .= $HTTP_SERVER_VARS["SERVER_NAME"];

    $ip = $HTTP_SERVER_VARS["REMOTE_ADDR"];

    $headers = array('From' => "\"$from_name\" <$from_addr>",
		     'To' => $param['em'],
		     'Reply-To' => $from_addr,
		     'MIME-Version' => '1.0',
		     'Content-Type' => 'text/plain',
		     'X-Sender' => $sender,
		     'X-Originating-IP' => "[$ip]",
		     'Subject' => $subject);

    $body = <<<EOD
Hello,

Per your request, you have been removed from the weekly
Shabbat candle lighting time list.

Regards,
hebcal.com
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
