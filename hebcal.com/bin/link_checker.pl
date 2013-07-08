#!/usr/bin/perl -w

########################################################################
#
# $Id$
#
# Copyright (c) 2006  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

use Getopt::Std ();
use LWP::UserAgent;
use strict;

$0 =~ s,.*/,,;  # basename
my($usage) = "usage: $0 [-h] file [...]
    -h        Display usage information.
    -v        Verbose mode.
    -p pat    Only check URLs that patch pattern <pat>
";

my %opts;
Getopt::Std::getopts("hp:v", \%opts) || die $usage;
$opts{"h"} && die $usage;
@ARGV  || die $usage;

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
	    if ($opts{"p"}) {
		next unless $_ =~ $opts{"p"};
	    }
	    print "Testing $url\n" if $opts{"v"};
	    my $req = HTTP::Request->new("GET", $url);
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



