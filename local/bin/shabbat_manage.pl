#!/usr/local/bin/perl -w

use lib "/home/mradwin/local/lib/perl5/site_perl";

use strict;
use DB_File;
use Fcntl qw(:DEFAULT :flock);
use Hebcal;
use Net::SMTP;
use MIME::Base64;
use Mail::Internet;

my $message = new Mail::Internet \*STDIN;
my $header = $message->head();

my $to = $header->get('To');

unless (defined $to) {
    die "$0: no To: header!";
}

my $from = $header->get('From');

if ($to =~ /shabbat-subscribe\+([^\@]+)\@/) {
    my $encoded = $1;
    system "echo 'enc = $encoded' >> /home/mradwin/logfile";
} elsif ($to =~ /shabbat-unsubscribe\@/) {
    system "echo 'from = $from' >> /home/mradwin/logfile";
}
