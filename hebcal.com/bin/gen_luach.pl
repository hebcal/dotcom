#!/usr/bin/perl -w

########################################################################
#
# Generates the reform luach
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

use utf8;
use open ":utf8";
use Getopt::Std ();
use XML::Simple ();
use DBI;
use Hebcal ();
use Date::Calc;
use HebcalGPL ();
use POSIX qw(strftime);
use HTML::CalendarMonthSimple ();
use strict;

$0 =~ s,.*/,,;  # basename
my $usage = "usage: $0 [-h] [-y <year>] festival.xml luach.sqlite3 output-dir
    -h        Display usage information.
    -v        Verbose mode
    -y <year> Start with hebrew year <year> (default this year)
";

my %opts;
Getopt::Std::getopts('hy:', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 3) || die "$usage";

my $festival_in = shift;
my $dbfile = shift;
my $outdir = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "",
		    { RaiseError => 1, AutoCommit => 0 })
    or croak $DBI::errstr;

print "Reading $festival_in...\n" if $opts{"v"};
my $fxml = XML::Simple::XMLin($festival_in);

my $HEB_YR;
if ($opts{'y'}) {
    $HEB_YR = $opts{'y'};
} else {
    my($this_year,$this_mon,$this_day) = Date::Calc::Today();
    my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
    $HEB_YR = $hebdate->{"yy"};
    $HEB_YR++ if $hebdate->{"mm"} == 6; # Elul
}

my @events = Hebcal::invoke_hebcal("./hebcal -s -H $HEB_YR", '', 0);
my $numEntries = scalar(@events);

my $start_month = $events[0]->[$Hebcal::EVT_IDX_MON] + 1;
my $start_year = $events[0]->[$Hebcal::EVT_IDX_YEAR];
my $end_month = $events[$numEntries - 1]->[$Hebcal::EVT_IDX_MON] + 1;
my $end_year = $events[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];
my $end_days = Date::Calc::Date_to_Days($end_year, $end_month, 1);


my $outfile = "$outdir/index.html";
open(OUT,">$outfile") || die "$outfile: $!";

my $title = "Luach $HEB_YR";
print OUT <<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="css/bootstrap.min.css" media="all">
</head>
<body>

<div class="masthead">
 <h3 class="muted">Reform Luach</h3>
</div><!-- .masthead -->

<div class="container">
<div id="content" class="clearfix row-fluid">
EOHTML
;

#my @html_cals;
#my %html_cals;
#my @html_cal_ids;


for (my @dt = ($start_year, $start_month, 1);
     Date::Calc::Date_to_Days(@dt) <= $end_days;
     @dt = Date::Calc::Add_Delta_YM(@dt, 0, 1))	{
    my $cal = new_html_cal($dt[0], $dt[1]);
    my $cal_id = sprintf("%04d-%02d", $dt[0], $dt[1]);
#    push(@html_cals, $cal);
#    push(@html_cal_ids, $cal_id);
#    $html_cals{$cal_id} = $cal;
    print OUT qq{<div id="cal-$cal_id">\n}, $cal->as_HTML(), 
	qq{</div><!-- #cal-$cal_id -->\n};
}


my $mtime = (defined $ENV{'SCRIPT_FILENAME'}) ?
    (stat($ENV{'SCRIPT_FILENAME'}))[9] : time;
my $hhmts = strftime("%d %B %Y", localtime($mtime));
my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime($mtime)) . "Z";
my $last_updated_text = qq{<p><time datetime="$dc_date">$hhmts</time></p>};

print OUT <<EOHTML;
</div><!-- #content -->

<footer role="contentinfo">
<hr>
<div id="inner-footer" class="clearfix">
$last_updated_text
<p><small>Except where otherwise noted, content on
<span xmlns:cc="http://creativecommons.org/ns#" property="cc:attributionName">this site</span>
is licensed under a 
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative
Commons Attribution 3.0 License</a>.</small></p>
</div><!-- #inner-footer -->
</footer>
</div> <!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
<script src="js/bootstrap.min.js"></script>
</body></html>
EOHTML
;

close(OUT);

$dbh->commit;
$dbh->disconnect;
$dbh = undef;

exit(0);


sub new_html_cal
{
    my($year,$month) = @_;

    my $cal = new HTML::CalendarMonthSimple("year" => $year,
					    "month" => $month);
    $cal->border(1);
    $cal->tableclass("table table-bordered");
    $cal->header(sprintf("<h2>%s %04d</h2>", $Hebcal::MoY_long{$month}, $year));

    my $end_day = Date::Calc::Days_in_Month($year, $month);
    for (my $mday = 1; $mday <= $end_day ; $mday++)
    {
	$cal->setcontent($mday, "&nbsp;");
    }

    $cal;
}


# local variables:
# mode: cperl
# end:
