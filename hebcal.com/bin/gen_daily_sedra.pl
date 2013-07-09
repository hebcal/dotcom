#!/usr/bin/perl -w

########################################################################
#
# Copyright (c) 2013  Michael J. Radwin.
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

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use Hebcal ();
use Date::Calc ();
use Getopt::Std ();

$0 =~ s,.*/,,;  # basename

my($usage) = "usage: $0 [-h] start-year end-year
    -h        Display usage information.
";

my(%opts);
Getopt::Std::getopts('h', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my $start_year = shift;
my $end_year = shift;

($start_year >= 1000) || die "$usage";
($end_year <= 9999) || die "$usage";

for (my $syear = $start_year; $syear <= $end_year; $syear++) {
    my $century = substr($syear, 0, 2);
    my $dir = "../converter/sedra/$century";
    unless (-d $dir) {
	system("/bin/mkdir", "-p", $dir) == 0 or die "mkdir $dir failed";
    }
    my @events = Hebcal::invoke_hebcal("./hebcal -o -S $syear", "", 0);

    my $outfile = "$dir/$syear.inc";
    open(OUT,">$outfile") || die;
    print OUT "<?php\n\$sedra = array(\n";

    my $prev_isodate = "";
    my @subjects = ();
    for (my $i = 0; $i < @events; $i++) {
	my $year = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	my $month = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my $day = $events[$i]->[$Hebcal::EVT_IDX_MDAY];
	my $isodate = sprintf("%04d%02d%02d", $year, $month, $day);

	if ($prev_isodate ne $isodate) {
	    if ($prev_isodate) {
		write_subjects($prev_isodate, \@subjects);
	    }
	    $prev_isodate = $isodate;
	    @subjects = ();
	}

	push(@subjects, $events[$i]->[$Hebcal::EVT_IDX_SUBJ]);
    }

    write_subjects($prev_isodate, \@subjects);
    print OUT ");\n?>\n";
    close(OUT);
}

sub write_subjects {
    my($iso,$e) = @_;

    print OUT "$iso => ";
    if (scalar(@{$e}) == 1) {
	print OUT "\"", $e->[0], "\",\n";
    } else {
	print OUT "array(\"", join('","', @{$e}), "\"),\n";
    }
}
