#!/usr/local/bin/perl -w

use Hebcal;
use POSIX;
use strict;

my $line = `./bin/hebcal -S -t -x -h | grep Parashat`;
chomp($line);

if ($line =~ m,^\d+/\d+/\d+\s+(.+)\s*$,) {
    my $parsha = $1;
    my $href = &Hebcal::get_holiday_anchor($parsha);
    if ($href) {
	my($now) = time();
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($now);
	my($saturday) = ($wday == 6) ?
	    $now + (60 * 60 * 24) : $now + ((6 - $wday) * 60 * 60 * 24);
	my($stime) = strftime("%B %d, %Y", localtime($saturday));

	open(OUT,">current2.inc") || die;
	print OUT <<EOHTML;
<br><br><span class="sm-grey">&gt;</span>
<b><a href="$href">$parsha</a></b>
<br>$stime
EOHTML
    ;
    }
}

