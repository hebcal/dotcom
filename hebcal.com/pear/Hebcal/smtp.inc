<?php

require "Mail.php";
require "Mail/RFC822.php";
require "Net/SMTP.php";

function email_address_valid($str)
{
    $mailRFC822 = new Mail_RFC822($str, '', false, true, null);
    $addr = $mailRFC822->parseAddressList();
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

    $host = "localhost";
    $port = 25;
    if (!($smtp = new Net_SMTP($host, $port))) {
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

    if (!$smtp->data($text_headers . "\r\n" . $body)) {
	return ('unable to send data');
    }

    $smtp->disconnect();
    return true;
}

