#!/usr/local/bin/perl -w

########################################################################
#
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

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use Getopt::Std;
use Config::IniFiles;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] holidays.ini
    -h        Display usage information.
";

my(%opts);
&getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 1) || die "$usage";

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($infile) = shift;

my($holidays) = new Config::IniFiles(-file => $infile);
$holidays || die "$infile: $!\n";

print "<festivals>\n";
foreach my $h ($holidays->Sections())
{
    print qq{ <festival id="$h"};
    print qq{\nanchor="}, $holidays->val($h, 'anchor'), qq{"};
    print qq{\nhebrew="}, $holidays->val($h, 'hebrew'), qq{"};
    print qq{\ndescr="}, $holidays->val($h, 'descr'), qq{"}
    if defined $holidays->val($h, 'descr');
    print qq{\nyomtov="}, $holidays->val($h, 'yomtov'), qq{">\n};
    if (defined $holidays->val($h, 'href')) {
	print qq{  <link rel="about" href="}, $holidays->val($h, 'href'),
	qq{" />\n}; 
    }
    print qq{ </festival>\n};
}
print "</festivals>\n";
