#!/usr/local/bin/perl -w

use strict;
use LWP::UserAgent;
use Image::Magick;

#my @asins = qw(0789314495 0883634082 0883634090 0764935178 0764934562 1594901988);
#my @asins = qw(0789314053 0789314495 0883634082 0883634090);
my @asins = qw(0789319411 0764947753 0764947702 0764947613 1602372659);
my $outdir = "/home/hebcal/web/hebcal.com/i";
my $ua;

foreach my $asin (@asins) {
    my $img = "$asin.01.TZZZZZZZ.jpg";
    my $filename = "$outdir/$img";
    if (! -e $filename) {
	$ua = LWP::UserAgent->new unless $ua;
	$ua->mirror("http://images.amazon.com/images/P/$img",
		    $filename);
    }

    my $image = new Image::Magick;
    $image->Read($filename);
    my($width,$height) = $image->Get("width", "height");
    print "\"$asin\", $width, $height);\n";
}
