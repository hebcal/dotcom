#!/usr/local/bin/perl -w

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";
use Hebcal;
use POSIX;
use strict;

my $line = `/pub/m/r/mradwin/hebcal.com/bin/hebcal -S -t -x -h | grep Parashat`;
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
	my($stime) = strftime("%d %B %Y", localtime($saturday));

	open(OUT,">/pub/m/r/mradwin/hebcal.com/current.inc") || die;
	$parsha =~ s/ /\n/;
	print OUT "<br><br><span class=\"sm-grey\">&gt;</span>\n";
	print OUT "<b><a href=\"$href\">$parsha</a></b><br>$stime";
	close(OUT);
    }
}

my $inc = '/pub/m/r/mradwin/hebcal.com/today.inc';
open(OUT,">$inc") || die;
print OUT `/pub/m/r/mradwin/hebcal.com/bin/hebcal -T -x -h`;
close(OUT);

$inc = '/pub/m/r/mradwin/hebcal.com/holiday.inc';
open(OUT,">$inc") || die;
close(OUT);

$line = `/pub/m/r/mradwin/hebcal.com/bin/hebcal -x`;
chomp($line);

if ($line =~ m,^\d+/\d+/\d+\s+(.+)\s*$,) {
    my $holiday = $1;
    my $href = &Hebcal::get_holiday_anchor($holiday);
    if ($href) {
	my($stime) = strftime("%d %B %Y", localtime(time()));

	open(OUT,">$inc") || die;
	$holiday =~ s/ /\n/;
	print OUT "<span class=\"sm-grey\">&gt;</span>\n";
	print OUT "<b><a href=\"$href\">$holiday</a></b><br>$stime<br>\n";
	close(OUT);
    }
}


