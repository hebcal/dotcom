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

use lib "/pub/p/e/perl/lib/site_perl";

use Getopt::Std;
use XML::Simple;
use DB_File;
use Fcntl qw(:DEFAULT :flock);
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
my($db) = tie(%DB, 'DB_File', $outfile, O_RDWR|O_CREAT, 0644);
defined($db) || die "Can't tie $outfile: $!\n";
my($fd) = $db->fd;
open(DB_FH, "+<&=$fd") || die "dup $!";
unless (flock (DB_FH, LOCK_EX)) { die "flock: $!" }

my(@all_inorder) =
    ("Bereshit",
     "Noach",
     "Lech-Lecha",
     "Vayera",
     "Chayei Sara",
     "Toldot",
     "Vayetzei",
     "Vayishlach",
     "Vayeshev",
     "Miketz",
     "Vayigash",
     "Vayechi",
     "Shemot",
     "Vaera",
     "Bo",
     "Beshalach",
     "Yitro",
     "Mishpatim",
     "Terumah",
     "Tetzaveh",
     "Ki Tisa",
     "Vayakhel",
     "Pekudei",
     "Vayikra",
     "Tzav",
     "Shmini",
     "Tazria",
     "Metzora",
     "Achrei Mot",
     "Kedoshim",
     "Emor",
     "Behar",
     "Bechukotai",
     "Bamidbar",
     "Nasso",
     "Beha'alotcha",
     "Sh'lach",
     "Korach",
     "Chukat",
     "Balak",
     "Pinchas",
     "Matot",
     "Masei",
     "Devarim",
     "Vaetchanan",
     "Eikev",
     "Re'eh",
     "Shoftim",
     "Ki Teitzei",
     "Ki Tavo",
     "Nitzavim",
     "Vayeilech",
     "Ha'Azinu",
     "Vezot Haberakhah");

foreach my $h (@all_inorder)
{
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

flock(DB_FH, LOCK_UN);
undef $db;
undef $fd;
untie(%DB);
close(DB_FH);

exit(0);
