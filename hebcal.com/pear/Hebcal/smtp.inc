<?php

// $Id$
// $Source: /Users/mradwin/hebcal-copy/hebcal.com/pear/Hebcal/RCS/smtp.inc,v $

function email_address_valid($str)
{
    require_once('Mail/RFC822.php');

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
    require_once('Mail.php');
    require_once('Net/SMTP.php');

    if (!($mail = new Mail())) {
	return ('unable to instantiate Mail object');
    }
    if (!($smtp = new Net_SMTP())) {
	return ('unable to instantiate Net_SMTP object');
    }
    if (!$smtp->connect()) {
	return ('unable to connect to smtp server');
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

