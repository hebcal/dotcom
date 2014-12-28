#!/usr/bin/perl -w

########################################################################
#
# Generates the festival pages for http://www.hebcal.com/holidays/
#
# Copyright (c) 2014  Michael J. Radwin.
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

use utf8;
use open ":utf8";
use Getopt::Std ();
use Hebcal ();
use Carp;
use Log::Log4perl qw(:easy);
use strict;

$0 =~ s,.*/,,;  # basename
my $usage = "usage: $0 [-hv] output-dir
  -h                Display usage information
  -v                Verbose mode
";

my %opts;
Getopt::Std::getopts('hv', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 1) || die "$usage";

# Just log to STDERR
my $loglevel = $opts{"v"} ? $INFO : $WARN;
Log::Log4perl->easy_init($loglevel);

my $outdir = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

my %countries;
foreach my $continent (sort keys %Hebcal::CONTINENTS) {
    $countries{$continent} = [];
}

my $dbh = Hebcal::zipcode_open_db($Hebcal::GEONAME_SQLITE_FILE);
$dbh->{sqlite_unicode} = 1;
my $sql = qq{SELECT Continent, Country FROM country ORDER BY Continent, Country};
my $sth = $dbh->prepare($sql) or die $dbh->errstr;
$sth->execute() or die $dbh->errstr;
while (my($continent,$country) = $sth->fetchrow_array) {
    push(@{$countries{$continent}}, $country);
}
$sth->finish;
Hebcal::zipcode_close_db($dbh);
undef($dbh);


my $fn = "$outdir/index.html";
INFO($fn);
open(my $fh, ">$fn.$$") || die "$fn.$$: $!\n";

my $page_title = "Shabbat Candle Lighting Times";
print $fh Hebcal::html_header_bootstrap3($page_title,
    "/shabbat/browse", "ignored");

print $fh <<EOHTML;
<div class="row">
<div class="col-sm-12">
<div class="page-header">
<h1>$page_title</h1>
</div>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<div class="row">
EOHTML
;

foreach my $continent (sort keys %Hebcal::CONTINENTS) {
    my $name = $Hebcal::CONTINENTS{$continent};
    print $fh <<EOHTML;
<div class="col-sm-4">
<h3>$name</h3>
<ul>
EOHTML
;
    foreach my $country (@{$countries{$continent}}) {
        my $anchor = Hebcal::make_anchor($country);
        print $fh qq{<li><a href="$anchor">$country</a></li>\n};
    }
    print $fh "</ul>\n</div><!-- .col-sm-4 -->\n";
}

print $fh qq{</div><!-- .row -->\n};

print $fh Hebcal::html_footer_bootstrap3(undef, undef);

close($fh);
rename("$fn.$$", $fn) || die "$fn: $!\n";
