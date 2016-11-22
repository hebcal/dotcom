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

    list($from, $text_headers) = hebcal_prepareHeaders($headers);
    if (!isset($from)) {
	return ('No from address given');
    }

    if (!($smtp->mailFrom($return_path))) {
	return ('unable to set sender to [' . $return_path . ']');
    }

    $recipients = hebcal_parseRecipients($recipients);
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

function hebcal_prepareHeaders($headers)
{
    $lines = array();
    $from = null;

    foreach ($headers as $key => $value) {
        if (strcasecmp($key, 'From') === 0) {
            include_once 'Mail/RFC822.php';
            $parser = new Mail_RFC822();
            $addresses = $parser->parseAddressList($value, 'localhost', false);
            if (is_a($addresses, 'PEAR_Error')) {
                return $addresses;
            }

            $from = $addresses[0]->mailbox . '@' . $addresses[0]->host;

            // Reject envelope From: addresses with spaces.
            if (strstr($from, ' ')) {
                return false;
            }

            $lines[] = $key . ': ' . $value;
        } elseif (strcasecmp($key, 'Received') === 0) {
            $received = array();
            if (is_array($value)) {
                foreach ($value as $line) {
                    $received[] = $key . ': ' . $line;
                }
            }
            else {
                $received[] = $key . ': ' . $value;
            }
            // Put Received: headers at the top.  Spam detectors often
            // flag messages with Received: headers after the Subject:
            // as spam.
            $lines = array_merge($received, $lines);
        } else {
            // If $value is an array (i.e., a list of addresses), convert
            // it to a comma-delimited string of its elements (addresses).
            if (is_array($value)) {
                $value = implode(', ', $value);
            }
            $lines[] = $key . ': ' . $value;
        }
    }

    return array($from, join("\r\n", $lines));
}


function hebcal_parseRecipients($recipients)
{
    include_once 'Mail/RFC822.php';

    // if we're passed an array, assume addresses are valid and
    // implode them before parsing.
    if (is_array($recipients)) {
        $recipients = implode(', ', $recipients);
    }

    // Parse recipients, leaving out all personal info. This is
    // for smtp recipients, etc. All relevant personal information
    // should already be in the headers.
    $Mail_RFC822 = new Mail_RFC822();
    $addresses = $Mail_RFC822->parseAddressList($recipients, 'localhost', false);

    // If parseAddressList() returned a PEAR_Error object, just return it.
    if (is_a($addresses, 'PEAR_Error')) {
        return $addresses;
    }

    $recipients = array();
    if (is_array($addresses)) {
        foreach ($addresses as $ob) {
            $recipients[] = $ob->mailbox . '@' . $ob->host;
        }
    }

    return $recipients;
}
