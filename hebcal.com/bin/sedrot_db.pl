#!/usr/local/bin/perl -w

########################################################################
# $Id$
#
# Copyright (c) 2005  Michael J. Radwin.
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

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use Getopt::Std ();
use XML::Simple ();
use DB_File;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] aliyah.xml output.db
    -h        Display usage information.
";

my(%opts);
Getopt::Std::getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($infile) = shift;
my($outfile) = shift;

my $parshiot = XML::Simple::XMLin($infile);

my(%DB);
tie(%DB, 'DB_File', $outfile, O_RDWR|O_CREAT, 0644, $DB_HASH)
    or die;

foreach my $h (keys %{$parshiot->{'parsha'}})
{
    next if $parshiot->{'parsha'}->{$h}->{'combined'};
    $DB{$h} = 1;
    $DB{"$h:hebrew"}    = $parshiot->{'parsha'}->{$h}->{'hebrew'};
    $DB{"$h:verse"}     = $parshiot->{'parsha'}->{$h}->{'verse'};
    $DB{"$h:haft_ashk"} = $parshiot->{'parsha'}->{$h}->{'haftara'};
    if ($parshiot->{'parsha'}->{$h}->{'sephardic'}) {
	$DB{"$h:haft_seph"} = $parshiot->{'parsha'}->{$h}->{'sephardic'};
    }

    my $links = $parshiot->{'parsha'}->{$h}->{'links'}->{'link'};
    foreach my $l (@{$links})
    {
	if ($l->{'rel'} && $l->{'href'})
	{
	    $DB{$h . ":" . $l->{'rel'}} = $l->{'href'};
	}
    }
}

untie(%DB);

exit(0);
