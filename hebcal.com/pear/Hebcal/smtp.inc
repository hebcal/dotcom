<?php

$incpath = get_include_path();
set_include_path("$incpath:" . $_SERVER["DOCUMENT_ROOT"] . "/pear");

require "Mail.php";
require "Mail/RFC822.php";
require "Net/SMTP.php";

function email_address_valid($str)
{
    $addr = Mail_RFC822::parseAddressList($str, '', false, true);
    if (!is_array($addr)) {
	return false;
    }
    if (!$addr[0]->host || !$addr[0]->mailbox) {
	return false;
    }

    // check for FQDN
    if (!preg_match('/^.+\..+$/', $addr[0]->host)) {
	return false;
    }

    $mailbox = str_replace(" ", "", $addr[0]->mailbox);
    $host = str_replace(" ", "", $addr[0]->host);

    return $mailbox . '@' . $host;
}


function smtp_send($return_path, $recipients, $headers, $body)
{
    if (!($mail = new Mail())) {
	return ('unable to instantiate Mail object');
    }
    $hebcal_ini = parse_ini_file("/home/hebcal/local/etc/hebcal-dot-com.ini");
    $host = "ssl://" . $hebcal_ini["hebcal.email.adhoc.host"];
    $port = 465;
    $username = $hebcal_ini["hebcal.email.adhoc.user"];
    $password = $hebcal_ini["hebcal.email.adhoc.password"];
    if (!($smtp = new Net_SMTP($host, $port))) {
	return ('unable to instantiate Net_SMTP object');
    }
    if (!$smtp->connect()) {
	return ('unable to connect to smtp server');
    }

    if (!$smtp->auth($username, $password)) {
	return ('unable to authenticate to smtp server');
    }
    
    list($from, $text_headers) = $mail->prepareHeaders($headers);
    if (!isset($from)) {
	return ('No from address given');
    }
        
    if (!($smtp->mailFrom($return_path))) {
	return ('unable to set sender to [' . $return_path . ']');
    }
        
    $recipients = $mail->parseRecipients($recipients);
    foreach($recipients as $recipient) {
	if (!$smtp->rcptTo($recipient)) { 
	    return ('unable to add recipient [' . $recipient . ']');
	}
    }
    
    if (!$smtp->data($text_headers . "\n" . $body)) {
	return ('unable to send data');
    }
        
    $smtp->disconnect();
    return true;
}

