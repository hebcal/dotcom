<?php

// $Id$
// $URL$

$incpath = get_include_path();
set_include_path("$incpath:/home/hebcal/web/hebcal.com/pear");

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

    return $addr[0]->mailbox . '@' . $addr[0]->host;
}


function smtp_send($return_path, $recipients, $headers, $body)
{
    if (!($mail = new Mail())) {
	return ('unable to instantiate Mail object');
    }
    $host = "ssl://mail.hebcal.com";
    $port = 465;
    $username = "hebcal@hebcal.com";
    $passfile = file("./hebcal-email-pass.cgi");
    $password = trim($passfile[0]);
    $smtp = Mail::factory("smtp",
			  array("host" => $host,
				"port" => $port,
				"auth" => true,
				"username" => $username,
				"password" => $password));
    if (!$smtp) {
	return ('unable to instantiate Net_SMTP object');
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

