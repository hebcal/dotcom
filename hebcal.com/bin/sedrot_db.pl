#!/usr/local/bin/perl -w

########################################################################
# $Id$
#
# Copyright (c) 2003  Michael J. Radwin.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
########################################################################

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";
use lib "/pub/p/e/perl/lib/site_perl";

use Getopt::Std;
use XML::Simple;
use DB_File;
use strict;

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] aliyah.xml output.db
    -h        Display usage information.
";

my(%opts);
getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($infile) = shift;
my($outfile) = shift;

my $parshiot = XMLin($infile);

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
