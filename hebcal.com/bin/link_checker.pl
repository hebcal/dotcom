#!/usr/local/bin/perl -w

use LWP::UserAgent;
use strict;

my $ua = LWP::UserAgent->new(keep_alive => 1, timeout => 30);
$| = 1;

my %checked;
foreach my $f (@ARGV) {
    open(F,$f) || die "$f: $!\n";
    while(<F>) {
	if (/href=\"(http[^\"]+)\"/) {
	    my $url = $1;
	    next if $url =~ /(www\.bible\.ort\.org|amazon\.com|hebcal\.com)/;
	    next if $checked{$url};
	    my $req = HTTP::Request->new('GET', $url);
	    my $res = $ua->request($req);

	    # Check the outcome of the response
	    if (!$res->is_success) {
		print $url, "\n";
		print "\t", $res->status_line, "\n";
	    }

	    $checked{$url} = 1;
	}
    }
    close(F);
}



