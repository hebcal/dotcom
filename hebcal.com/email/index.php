<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
	"http://www.w3.org/TR/html4/loose.dtd">
<?
require_once('smtp.inc');

global $HTTP_SERVER_VARS;

$rand = pack("V", rand());
if ($HTTP_SERVER_VARS["REMOTE_ADDR"]) {
    list($p1,$p2,$p3,$p4) = explode('.', $HTTP_SERVER_VARS["REMOTE_ADDR"]);
    $rand .= pack("CCCC", $p1, $p2, $p3, $p4);
}
$rand .= pack("V", time());

$encoded = rtrim(base64_encode($rand));
$encoded = str_replace('+', '.', $encoded);
$encoded = str_replace('/', '_', $encoded);
$encoded = str_replace('=', '-', $encoded);

$from_name = "Hebcal Subscription Notification";
$from_addr = "shabbat-subscribe+$encoded@hebcal.com";
$return_path = "shabbat-bounce@hebcal.com";

$subject = "Please confirm your request to subscribe to hebcal";

global $HTTP_GET_VARS;
$to = $HTTP_GET_VARS["to"];

$recipients = $to;

$headers = array('From' => "\"$from_name\" <$from_addr>",
		'To' => $to,
		'Reply-To' => $from_addr,
		'MIME-Version' => '1.0',
		'Content-Type' => 'text/plain',
		'X-Sender' => "webmaster@$SERVER_NAME",
		'Subject' => $subject);

$body = "hello!\n";
$body .= "there!\n\nbye.\n";

$title = "success!";
$err = smtp_send($return_path, $recipients, $headers, $body);
if ($err !== true)
{
	$title = $err;
}
?>
<html lang="en"><head><title><? echo $title ?></title>
<meta http-equiv="PICS-Label" content='(PICS-1.1 "http://www.rsac.org/ratingsv01.html" l gen true on "1998.03.10T11:49-0800" r (n 0 s 0 v 0 l 0))'>
<link rev="made" href="mailto:michael@radwin.org">
<link rel="stylesheet" href="/style.css" type="text/css">
</head><body>
<table width="100%" class="navbar">
<tr><td><small>
<strong><a href="/">radwin.org</a></strong> <tt>-&gt;</tt>
<? echo $title ?>
</small></td>
<td align="right"><small><a href="/search/">Search</a></small>
</td></tr></table>

<h1><? echo $title ?></h1>

foobar

<p>
<hr noshade size="1"><em><a
href="/michael/contact.html">Michael J. Radwin</a></em><br><br><small>
<!-- hhmts start -->
<!-- hhmts end -->
</small></body></html>
