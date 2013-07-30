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
use Getopt::Long ();
use XML::Simple qw(:strict);
use DBI;
use Hebcal ();
use Date::Calc;
use HebcalGPL ();
use POSIX qw(strftime);
use HTML::CalendarMonthSimple ();
use strict;

my $opt_help;
my $opt_verbose = 0;
my $opt_year;

if (!Getopt::Long::GetOptions("help|h" => \$opt_help,
			      "year|y=i" => \$opt_year,
			      "verbose|v+" => \$opt_verbose)) {
    usage();
}

$opt_help && usage();
(@ARGV == 4) || usage();

my $festival_in = shift;
my $luach_in = shift;
my $dbfile = shift;
my $outdir = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "",
		    { RaiseError => 1, AutoCommit => 0 })
    or croak $DBI::errstr;

print "Reading $festival_in...\n" if $opt_verbose;
my $fxml = XMLin($festival_in, KeyAttr => ['name', 'key', 'id'], ForceArray => 0);

print "Reading $luach_in...\n" if $opt_verbose;
my $luach_xml = XMLin($luach_in,
		      KeyAttr => ['id'],
		      ForceArray => ["li", "section"]);

use Data::Dumper;
print Dumper($luach_xml), "\n";

my $HEB_YR;
if ($opt_year) {
    $HEB_YR = $opt_year;
} else {
    my($this_year,$this_mon,$this_day) = Date::Calc::Today();
    my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
    $HEB_YR = $hebdate->{"yy"};
    $HEB_YR++ if $hebdate->{"mm"} == 5; # Av
}

my $cmd = "./hebcal -s -i -H $HEB_YR";
my @events = Hebcal::invoke_hebcal($cmd, "", 0);
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
<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.0-rc1/css/bootstrap.min.css">
<link href='http://fonts.googleapis.com/css?family=Source+Sans+Pro:400,700' rel='stylesheet' type='text/css'>
<style type="text/css">
body{
 padding-top: 70px;
 font-family: 'Source Sans Pro', sans-serif;
}
h1,
h2,
h3,
h4,
h5,
h6,
.h1,
.h2,
.h3,
.h4,
.h5,
.h6 {
 font-family: 'Source Sans Pro', sans-serif;
}
.popover {
 max-width: 476px;
}
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

<div class="navbar navbar-fixed-top">
<span class="navbar-brand">Reform Luach</span>
<ul class="nav navbar-nav">
<li class="active"><a href="#">Home</a></li>
<li><a href="#">About</a></li>
</ul>
</div><!-- .navbar -->

<div class="container">
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

my $sth = $dbh->prepare("SELECT num,reading FROM leyning WHERE dt = ? AND parashah = ?");

my %rosh_chodesh;
foreach my $evt (@events) {
    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];

    my($href,$hebrew,$memo) = Hebcal::get_holiday_anchor($subj,0,undef);
    $subj =~ s/ \d{4}$//;

    if ($memo ne "") {
	$memo = "<div>$memo</div>";
    }

    my $xml_item;

    my($year,$month,$day) = Hebcal::event_ymd($evt);
    my $dow = Date::Calc::Day_of_Week($year, $month, $day);
    if ($dow == 6) {
	$xml_item = find_item("$subj (on Shabbat");
    }
    # try without "on Shabbat" if we didn't find it
    $xml_item = find_item($subj) unless defined $xml_item;

    if ($xml_item) {
	foreach my $section (@{$xml_item->{"section"}}) {
	    $memo .= "<strong>" . $section->{"name"}. qq{</strong><ul style="padding-left:11px">};
	    foreach my $li (@{$section->{"li"}}) {
		$memo .= "<li>$li</li>\n";
	    }
	    $memo .= "</ul>";
	}
    }

    my $torah_memo = torah_memo($subj, $year, $month, $day);
    $memo .= "<br>" . $torah_memo if $torah_memo;

    add_event($year, $month, $day, $subj, $hebrew, $memo);
    if ($subj =~ /^Rosh Chodesh (.+)$/) {
	my $rch_month = $1;
	$rosh_chodesh{$rch_month} = [] unless defined $rosh_chodesh{$rch_month};
	push(@{$rosh_chodesh{$rch_month}}, $evt);
    }
}

my @DAYS = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
my @heb_months = qw(VOID Nisan Iyyar Sivan Tamuz Av Elul Tishei Cheshvan Kislev Tevet Sh'vat);
push(@heb_months, "Adar I", "Adar II");

# figure out which Shabbatot are M'varchim haChodesh
for (my $abs = $start_abs; $abs <= $end_abs; $abs++) {
    my $greg = HebcalGPL::abs2greg($abs);
    my $dow = Date::Calc::Day_of_Week($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"});
    if ($dow == 6) {
	my $hebdate = HebcalGPL::abs2hebrew($abs);
	if ($hebdate->{"dd"} >= 23 && $hebdate->{"dd"} <= 29 && $hebdate->{"mm"} != 6) {
	    my $hmonth = $hebdate->{"mm"} + 1;
	    if ($hmonth > HebcalGPL::MONTHS_IN_HEB($hebdate->{"yy"})) {
		$hmonth = 1;
	    }
	    my $hebmonth = $heb_months[$hmonth];
	    my($year,$month,$day) = Hebcal::event_ymd($rosh_chodesh{$hebmonth}->[0]);
	    my $dow = Hebcal::get_dow($year, $month, $day);
	    my $memo = "Rosh Chodesh <strong>$hebmonth</strong> will be on <strong>" . $DAYS[$dow] . "</strong>";
	    if (defined $rosh_chodesh{$hebmonth}->[1]) {
		($year,$month,$day) = Hebcal::event_ymd($rosh_chodesh{$hebmonth}->[1]);
		$dow = Hebcal::get_dow($year, $month, $day);
		$memo .= " and <strong>" . $DAYS[$dow] . "</strong>";
	    }
	    $memo .= ".";
	    add_event($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"}, "Shabbat Mevarchim", undef, $memo);
	}
    }
}

# Aseret Y'mei T'shuvah
my $rh10days = find_item("Aseret Y'mei T'shuvah");
my $rh10days_memo = qq{<ul style="padding-left:11px">};
foreach my $li (@{$rh10days->{"section"}->[0]->{"li"}}) {
    $rh10days_memo .= "<li>$li</li>\n";
}
$rh10days_memo .= "</ul>";
for (my $abs = $start_abs; $abs < $start_abs+10; $abs++) {
    my $greg = HebcalGPL::abs2greg($abs);
    add_event($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"}, "Aseret Y'mei T'shuvah", undef, $rh10days_memo);
}

my $nav_pagination = qq{<ul class="pagination pagination-centered">\n};
foreach my $cal_id (@html_cal_ids) {
    if ($cal_id =~ /^(\d{4})-(\d{2})$/) {
	my $year = $1;
	my $mon = $2;
	$mon =~ s/^0//;
	my $mon_long = $Hebcal::MoY_long{$mon};
	my $mon_short = $Hebcal::MoY_short[$mon-1];
	$nav_pagination .= qq{<li><a title="$mon_long $year" href="#cal-$cal_id">$mon_short</a></li>\n};
    }
}
$nav_pagination .= qq{</ul><!-- .pagination -->\n};
print OUT $nav_pagination;

foreach my $cal_id (@html_cal_ids) {
    my $cal = $html_cals{$cal_id};
    print OUT qq{<div id="cal-$cal_id" style="padding-top:60px">\n};
    print OUT $cal->as_HTML();
    print OUT qq{</div><!-- #cal-$cal_id -->\n};
}

my $mtime = (defined $ENV{'SCRIPT_FILENAME'}) ?
    (stat($ENV{'SCRIPT_FILENAME'}))[9] : time;
my $hhmts = strftime("%d %B %Y", localtime($mtime));
my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime($mtime)) . "Z";
my $last_updated_text = qq{<p><time datetime="$dc_date">$hhmts</time></p>};

print OUT <<EOHTML;

<footer>
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
</div><!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
<script src="//netdna.bootstrapcdn.com/bootstrap/3.0.0-rc1/js/bootstrap.min.js"></script>
<script>
\$("a[data-toggle=popover]")
      .popover({html:true})
      .click(function(e) {
        e.preventDefault()
      })
</script>
</body></html>
EOHTML
;

close(OUT);

#$dbh->commit;
$dbh->disconnect;
$dbh = undef;

exit(0);

sub find_item {
    my($title) = @_;
    foreach my $item (@{$luach_xml->{"item"}}) {
	return $item if defined $item->{"title"} && $item->{"title"} eq $title;
    }
    undef;
}

sub add_event {
    my($year,$month,$day,$subj,$hebrew,$memo) = @_;
    my $cal_id = sprintf("%04d-%02d", $year, $month);
    my $cal = $html_cals{$cal_id};

    my $dow = Date::Calc::Day_of_Week($year, $month, $day);
    my $placement = ($dow == 5 || $dow == 6) ? "left" : "right";

    my $title = $hebrew ? "$subj / $hebrew" : $subj;
    my $memo_html = Hebcal::html_entify($memo);
    my $html = qq{<a href="#" class="popover-test" data-toggle="popover" data-placement="$placement" title="$title" data-content="$memo_html">$subj</a>};
    $cal->addcontent($day, "<br>\n")
	if $cal->getcontent($day) ne "";
    $cal->addcontent($day, $html);
}

sub torah_memo {
    my($reason,$year,$month,$day) = @_;
    my $date_sql = Hebcal::date_format_sql($year, $month, $day);
    $reason =~ s/^Parashat\s+//;
    my $rv = $sth->execute($date_sql,$reason) or die $dbh->errstr;
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
	$memo = "<strong>Torah Reading:</strong> $torah_reading";
	if ($special_maftir) {
	    $memo .= "<br><strong>Maftir:</strong> ";
	    $memo .= $special_maftir;
	}
	if ($haftarah_reading) {
	    $memo .= "<br><strong>Haftarah:</strong> ";
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


sub usage {
    $0 =~ s,.*/,,;  # basename
    my $usage = "usage: $0 [-h] [-y <year>] festival.xml reform-luach.xml luach.sqlite3 output-dir
    -h        Display usage information.
    -v        Verbose mode
    -y <year> Start with hebrew year <year> (default this year)
";
    die $usage;
}

# local variables:
# mode: cperl
# end:
