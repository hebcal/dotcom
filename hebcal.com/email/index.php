<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
<head><title>Hebcal 1-Click Shabbat by Email</title>
<base href="http://www.hebcal.com/email/" target="_top">
<link type="text/css" rel="stylesheet" href="/style.css">
<link type="text/css" media="print" rel="stylesheet" href="/print.css">
<link href="mailto:webmaster@hebcal.com" rev="made">
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
<?
require_once('smtp.inc');
require_once('zips.inc');

$VER = '$Revision$';
$matches = array();
if (preg_match('/(\d+)\.(\d+)/', $VER, $matches)) {
    $VER = $matches[1] . "." . $matches[2];
}

global $HTTP_POST_VARS;
global $HTTP_GET_VARS;
$param = array();

foreach($HTTP_POST_VARS as $key => $value) {
    $param[$key] = $value;
}
foreach($HTTP_GET_VARS as $key => $value) {
    $param[$key] = $value;
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
    $fd = fopen("/tmp/hebcal.com.lock", "w");
    if ($fd == false) {
	die("lockfile open failed");
    }

    if (flock($fd, LOCK_EX) == false) {
	die("flock failed");
	fclose($fd);
    }

    $id = dba_open("subs.db", "w", "db3");
    if (!$id) {
	die("dba_open subs.db failed");
    }

    if (!dba_replace($email, $val, $id)) {
	die("dba_replace subs.db failed");
    }

    dba_sync($id);
    dba_close($id);
    flock($fd, LOCK_UN);
    fclose($fd);

    return true;
}

function get_sub_info($email) {
    $fd = fopen("/tmp/hebcal.com.lock", "w");
    if ($fd == false) {
	die("lockfile open failed");
    }

    if (flock($fd, LOCK_SH) == false) {
	die("flock failed");
	fclose($fd);
    }

    $id = dba_open("subs.db", "r", "db3");
    if (!$id) {
	die("dba_open subs.db failed");
    }

    $val = dba_fetch($email, $id);

    dba_close($id);
    flock($fd, LOCK_UN);
    fclose($fd);

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
    $encoded = str_replace('+', '.', $encoded);
    $encoded = str_replace('/', '_', $encoded);
    $encoded = str_replace('=', '-', $encoded);

    $fd = fopen("/tmp/hebcal.com.lock", "w");
    if ($fd == false) {
	die("lockfile open failed");
    }

    if (flock($fd, LOCK_EX) == false) {
	die("flock failed");
	fclose($fd);
    }

    $id = dba_open("email.db", "w", "db3");
    if (!$id) {
	die("dba_open email.db failed");
    }

    $val = sprintf("zip=%s;tz=%s;dst=%s;m=%s;upd=%d;t=%d;em=%s",
		   $param['zip'],
		   $param['tz'],
		   $param['dst'],
		   $param['m'],
		   $param['upd'] ? 1 : 0,
		   $now,
		   $param['em']);

    if (!dba_replace($encoded, $val, $id)) {
	die("dba_replace email.db failed");
    }

    dba_sync($id);
    dba_close($id);
    flock($fd, LOCK_UN);
    fclose($fd);

    return $encoded;
}


function my_footer() {
    global $HTTP_SERVER_VARS;
    $stat = stat($HTTP_SERVER_VARS["SCRIPT_FILENAME"]);
    $year = strftime("%Y", time());
    $date = strftime("%c", $stat[9]);
    global $VER;

    $html = <<<EOD
<hr noshade size="1"><font size="-2" face="Arial">
<a name="copyright">Copyright &copy; $year
Michael J. Radwin. All rights reserved.</a>
<a target="_top" href="http://www.hebcal.com/privacy/">Privacy Policy</a> -
<a target="_top" href="http://www.hebcal.com/help/">Help</a> -
<a target="_top" href="http://www.hebcal.com/contact/">Contact</a>
<br>This website uses <a href="http://sourceforge.net/projects/hebcal/">hebcal
3.2 for UNIX</a>, Copyright &copy; 1994 Danny Sadinoff. All rights reserved.
<br>Software last updated: $date (Revision: $VER) 
</font></body></html>
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
    echo "<p>Subscribe to email weekly Shabbat candle lighting times.\n",
	"Email is sent out every week on Thursday morning.</p>\n";

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
<form name="f1" id="f1" action="/email2/" method="post">

<label for="em">E-mail address:
<input type="text" name="em" size="30"
value="<?php echo htmlspecialchars($param['em']) ?>" id="em">
</label>
&nbsp;&nbsp;<font size="-2" face="Arial"><a href="/privacy/#email">Email
Privacy Policy</a></font>

<br><label for="zip">Zip code:
<input type="text" name="zip" size="5" maxlength="5" id="zip"
value="<?php echo htmlspecialchars($param['zip']) ?>"></label>

&nbsp;&nbsp;&nbsp;&nbsp;<label for="tz">Time zone:
<select name="tz" id="tz">
<option <?php if ($param['tz'] == 'auto') { echo 'selected '; } ?>
value="auto">- Attempt to auto-detect -</option>
<option <?php if ($param['tz'] == '-5') { echo 'selected '; } ?>
value="-5">GMT -05:00 (U.S. Eastern)</option>
<option <?php if ($param['tz'] == '-6') { echo 'selected '; } ?>
value="-6">GMT -06:00 (U.S. Central)</option>
<option <?php if ($param['tz'] == '-7') { echo 'selected '; } ?>
value="-7">GMT -07:00 (U.S. Mountain)</option>
<option <?php if ($param['tz'] == '-8') { echo 'selected '; } ?>
value="-8">GMT -08:00 (U.S. Pacific)</option>
<option <?php if ($param['tz'] == '-9') { echo 'selected '; } ?>
value="-9">GMT -09:00 (U.S. Alaskan)</option>
<option <?php if ($param['tz'] == '-10') { echo 'selected '; } ?>
value="-10">GMT -10:00 (U.S. Hawaii)</option>
</select>
</label>

<br>Daylight Saving Time:
<label for="dst_usa">
<input type="radio" name="dst" <?php
	if ($param['dst'] == 'usa') { echo 'checked '; } ?>
value="usa" id="dst_usa">
USA (except AZ, HI, and IN)
</label>
<label for="dst_none">
<input type="radio" name="dst" <?php 
	if ($param['dst'] == 'none') { echo 'checked '; } ?>
value="none" id="dst_none">
none
</label>

<br><label for="m1">Havdalah minutes past sundown:
<input type="text" name="m" value="<?php
  echo htmlspecialchars($param['m']) ?>" size="3" maxlength="3" id="m1">
</label>

<br><label for="upd">
<input type="checkbox" name="upd" value="on" <?php
  if ($param['upd'] == 'on') { echo 'checked'; } ?> id="upd">
Contact me occasionally about changes to the hebcal.com website.
</label>

<input type="hidden" name="v" value="1">
<input type="hidden" name="geo" value="zip">
<br>
<input type="submit" name="submit_modify" value="Subscribe">
<input type="submit" name="submit_unsubscribe" value="Unsubscribe">
</form>
<?php
    my_footer();
}

function subscribe($param) {
    if (!$param['zip'])
    {
	form($param,
	     "Please enter your zip code for candle lighting times.");
    }

    $recipients = $param['em'];
    if (preg_match('/\@hebcal.com$/', $recipients))
    {
	form($param,
	     "Sorry, can't use a <b>hebcal.com</b> email address.");
    }

    if (!$param['dst']) {
	$param['dst'] = 'usa';
    }
    if (!$param['tz']) {
	$param['tz'] = 'auto';
    }
    $param['geo'] = 'zip';

    if (!preg_match('/^\d{5}$/', $param['zip']))
    {
	form($param,
	     "Sorry, <b>" . $param['zip'] . "</b> does\n" .
	     "not appear to be a 5-digit zip code.");
    }

    $val = get_zip_info($param['zip']);
    if (!$val)
    {
	form($param,
	     "Sorry, can't find\n".  "<b>" . $param['zip'] .
	     "</b> in the zip code database.\n",
	     "<ul><li>Please try a nearby zip code</li></ul>");
    }

    list($city,$state) = explode("\0", substr($val,6), 2);

    if (($state == 'HI' || $state == 'AZ') && $param['dst'] == 'usa')
    {
	$param['dst'] = 'none';
    }

    $city = ucwords(strtolower($city));
    $city_descr = "$city, $state " . $param['zip'];

    // handle timezone == "auto"
    $tz = guess_timezone($param['tz'], $param['zip'], $state);
    if (!$tz)
    {
	form($param,
	     "Sorry, can't auto-detect\n" .
	     "timezone for <b>" . $city_descr . "</b>\n".
	     "(state <b>" . $state . "</b> spans multiple time zones).",
	     "<ul><li>Please select your time zone below.</li></ul>");
    }

    global $tz_names;
    $param['tz'] = $tz;
    $tz_descr = "Time zone: " . $tz_names['tz_' . $tz];

    $dst_descr = "Daylight Saving Time: " . $param['dst'];

    # check if email address already verified
    $info = get_sub_info($recipients);
    if ($info && !preg_match('/^action=/', $info))
    {
	$now = time();
	write_sub_info(
	    $recipients, 
	    sprintf("zip=%s;tz=%s;dst=%s;m=%s;upd=%d;t=%d",
		    $param['zip'],
		    $param['tz'],
		    $param['dst'],
		    $param['m'],
		    $param['upd'] ? 1 : 0,
		    $now)
	    );

	$html = <<<EOD
<h2>Subscription Updated</h2>
<p>Your subsciption information has been updated successfully.</p>
<p><small>
$city_descr
<br>&nbsp;&nbsp;$dst_descr
<br>&nbsp;&nbsp;$tz_descr
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

    $headers = array('From' => "\"$from_name\" <$from_addr>",
		     'To' => $recipients,
		     'Reply-To' => $from_addr,
		     'MIME-Version' => '1.0',
		     'Content-Type' => 'text/plain',
		     'X-Sender' => $sender,
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
<p><small>
$city_descr
<br>&nbsp;&nbsp;$dst_descr
<br>&nbsp;&nbsp;$tz_descr
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

    $headers = array('From' => "\"$from_name\" <$from_addr>",
		     'To' => $param['em'],
		     'Reply-To' => $from_addr,
		     'MIME-Version' => '1.0',
		     'Content-Type' => 'text/plain',
		     'X-Sender' => $sender,
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