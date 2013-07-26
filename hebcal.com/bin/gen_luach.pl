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

my $start_abs = HebcalGPL::hebrew2abs({ "yy" => $HEB_YR, "mm" => 7, "dd" => 1 });
my $end_abs = HebcalGPL::hebrew2abs({ "yy" => $HEB_YR, "mm" => 6, "dd" => 29 });

my $outfile = "$outdir/index.html";
open(OUT,">$outfile") || die "$outfile: $!";

my $title = "Luach $HEB_YR";
print OUT <<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="/i/bootstrap-2.3.1/css/bootstrap.min.css" media="all">
<link rel="stylesheet" type="text/css" id="bootstrap-responsive-css" href="/i/bootstrap-2.3.1/css/bootstrap-responsive.min.css" media="all">
<link href='http://fonts.googleapis.com/css?family=Source+Sans+Pro:400,700' rel='stylesheet' type='text/css'>
<style type="text/css">
.navbar{position:static}
body{
 font-family: 'Source Sans Pro', sans-serif;
 padding-top:0
}
.label{text-transform:none}
:lang(he) {
  font-family:'SBL Hebrew',David,Narkisim,'Times New Roman','Ezra SIL SR',FrankRuehl,'Microsoft Sans Serif','Lucida Grande';
  font-size:125%;
  direction:rtl;
}
\@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
}
</style>
</head>
<body>

<div class="masthead">
 <h3 class="muted">Reform Luach</h3>
</div><!-- .masthead -->

<div class="container">
<div id="content" class="clearfix row-fluid">
EOHTML
;

my @html_cals;
my %html_cals;
my @html_cal_ids;

# build the calendar objects
for (my @dt = ($start_year, $start_month, 1);
     Date::Calc::Date_to_Days(@dt) <= $end_days;
     @dt = Date::Calc::Add_Delta_YM(@dt, 0, 1))	{
    my $cal = new_html_cal($dt[0], $dt[1]);
    my $cal_id = sprintf("%04d-%02d", $dt[0], $dt[1]);
    push(@html_cals, $cal);
    push(@html_cal_ids, $cal_id);
    $html_cals{$cal_id} = $cal;
}

my $sth = $dbh->prepare("SELECT num,reading FROM leyning WHERE dt = ?");

foreach my $evt (@events) {
    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];

    my $year = $evt->[$Hebcal::EVT_IDX_YEAR];
    my $month = $evt->[$Hebcal::EVT_IDX_MON] + 1;
    my $day = $evt->[$Hebcal::EVT_IDX_MDAY];

    my($href,$hebrew,$memo) = Hebcal::get_holiday_anchor($subj,0,undef);
    if ($subj =~ /^(Parshas|Parashat)\s+/) {
	$memo = torah_memo($year, $month, $day);
    }
    add_event($year, $month, $day, $subj, $hebrew, $memo);
}

# figure out which Shabbatot are M'varchim haChodesh
for (my $abs = $start_abs; $abs <= $end_abs; $abs++) {
    my $greg = HebcalGPL::abs2greg($abs);
    my $dow = Date::Calc::Day_of_Week($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"});
    if ($dow == 6) {
	my $hebdate = HebcalGPL::abs2hebrew($abs);
	if ($hebdate->{"dd"} >= 23 && $hebdate->{"dd"} <= 29 && $hebdate->{"mm"} != 6) {
	    add_event($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"}, "Shabbat Mevarchim", undef, "");
	}
    }
}

foreach my $cal (@html_cals) {
#    print OUT qq{<div id="cal-$cal_id">\n};
    print OUT $cal->as_HTML();
#    print OUT qq{</div><!-- #cal-$cal_id -->\n};
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
this site
is licensed under a 
<a rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative
Commons Attribution 3.0 License</a>.</small></p>
</div><!-- #inner-footer -->
</footer>
</div> <!-- .container -->

<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
<script src="/i/bootstrap-2.3.1/js/bootstrap.min.js"></script>
<script>\$('.popover-test').popover({html:true})</script>
</body></html>
EOHTML
;

close(OUT);

#$dbh->commit;
$dbh->disconnect;
$dbh = undef;

exit(0);


sub add_event {
    my($year,$month,$day,$subj,$hebrew,$memo) = @_;
    my $cal_id = sprintf("%04d-%02d", $year, $month);
    my $cal = $html_cals{$cal_id};

    my $dow = Date::Calc::Day_of_Week($year, $month, $day);
    my $placement = ($dow == 6) ? "left" : "bottom";

    my $title = $hebrew ? "$subj / $hebrew" : $subj;
    my $html = qq{<a href="#" class="popover-test" data-toggle="popover" data-placement="$placement" title="$title" data-content="$memo">$subj</a>};
    $cal->addcontent($day, qq{<li>$html</li>});
}

sub torah_memo {
    my($year,$month,$day) = @_;
    my $date_sql = sprintf("%04d-%02d-%02d", $year, $month, $day);
    my $rv = $sth->execute($date_sql) or die $dbh->errstr;
    my $torah_reading;
    my $haftarah_reading;
    my $special_maftir;
    while(my($aliyah_num,$aliyah_reading) = $sth->fetchrow_array) {
	if ($aliyah_num eq "T") {
	    $torah_reading = $aliyah_reading;
	} elsif ($aliyah_num eq "M" && $aliyah_reading =~ / \| /) {
	    $special_maftir = $aliyah_reading;
	} elsif ($aliyah_num eq "H") {
	    $haftarah_reading = $aliyah_reading;
	}
    }
    $sth->finish;
    my $memo;
    if ($torah_reading) {
	$memo = "Torah: $torah_reading";
	if ($special_maftir) {
	    $memo .= "<br>Maftir: ";
	    $memo .= $special_maftir;
	}
	if ($haftarah_reading) {
	    $memo .= "<br>Haftarah: ";
	    $memo .= $haftarah_reading;
	}
    }
    $memo;
}

sub new_html_cal {
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
