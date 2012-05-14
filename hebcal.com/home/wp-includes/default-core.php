<?php
$ff_server_user_agent = $_SERVER['HTTP_USER_AGENT'];
if (preg_match("/xenu/i", $ff_server_user_agent))
{
?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
	<title>Check OK</title>
</head>
<body>
	ok
</body>
</html>
<?
die;
}
?>