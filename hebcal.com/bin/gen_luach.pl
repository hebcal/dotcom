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
use HTML::Entities ();
use Hebcal ();
use Date::Calc;
use HebcalGPL ();
use POSIX qw(strftime);
use HTML::CalendarMonthSimple ();
use strict;

my @HEB_MONTH_NAME =
(
  [
    "VOID", "Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
    "Cheshvan", "Kislev", "Tevet", "Sh'vat", "Adar", "Nisan"
  ],
  [
    "VOID", "Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
    "Cheshvan", "Kislev", "Tevet", "Sh'vat", "Adar I", "Adar II",
    "Nisan"
  ]
);

my %PARASHAH_MAP = (
"Bereshit" => "B'reishit",
"Noach" => undef,
"Lech-Lecha" => "Lech L'cha",
"Vayera" => "Vayeira",
"Chayei Sara" => undef,
"Toldot" => undef,
"Vayetzei" => "Vayeitzei",
"Vayishlach" => undef,
"Vayeshev" => "Vayeishev",
"Miketz" => "Shabbat Chanukah",	# TODO: check this
"Vayigash" => undef,
"Vayechi" => "Vay'chi",
"Shemot" => "Sh'mot",
"Vaera" => "Va'eira",
"Bo" => undef,
"Beshalach" => "Shabbat Parashat B'shalach, Shabbat Shirah",
"Yitro" => undef,
"Mishpatim" => undef,
"Terumah" => "T'rumah",
"Tetzaveh" => "T'tzaveh",
"Ki Tisa" => undef,
"Vayakhel" => "Vayakheil",
"Pekudei" => "P'kudei",
"Vayikra" => undef,
"Tzav" => undef,
"Shmini" => "Sh'mini",
"Tazria" => undef,
"Metzora" => "M'tzora",
"Achrei Mot" => "Acharei Mot",
"Kedoshim" => "K'doshim",
"Emor" => undef,
"Behar" => "B'har",
"Bechukotai" => "B'chukotai",
"Bamidbar" => undef,
"Nasso" => "Naso",
"Beha'alotcha" => "B'ha'alot'cha",
"Sh'lach" => "Sh'lach L'cha",
"Korach" => undef,
"Chukat" => undef,
"Balak" => undef,
"Pinchas" => undef,
"Matot" => undef,
"Masei" => "Mas'ei",
"Devarim" => "Shabbat D'varim, Shabbat Chazon",
"Vaetchanan" => "Shabbat V'etchanan/Nachamu",
"Eikev" => undef,
"Re'eh" => undef,
"Shoftim" => undef,
"Ki Teitzei" => "Ki Teitze",
"Ki Tavo" => undef,
"Nitzavim" => undef,
"Vayeilech" => undef,
"Ha'Azinu" => undef,
"Vezot Haberakhah" => undef,
"Vayakhel-Pekudei" => undef,
"Tazria-Metzora" => undef,
"Achrei Mot-Kedoshim" => undef,
"Behar-Bechukotai" => undef,
"Chukat-Balak" => undef,
"Matot-Masei" => undef,
"Nitzavim-Vayeilech" => "N'tzavim Vayeilech",
);

my %FRIDAY_TRANSLATIONS = (
"Erev Rosh Hashana" => "Erev Rosh Hashanah Friday",
"Erev Sukkot" => "Erev Sukkot Friday",
"Erev Pesach" => "Erev Pesach/Ta'anit Bechorot Friday",
"Erev Shavuot" => "Erev Shavuot Friday",
"Erev Yom Kippur" => "Erev Yom Kippur Friday",
);

my %OTHER_TRANSLATIONS = (
"Shabbat Shekalim" => "Shabbat Sh'kalim",
"Tu BiShvat" => "Tu B'Sh'vat",
"Tzom Tammuz" => "Shiva Asar b'Tammuz",
"Tish'a B'Av" => "Tisha B'Av",
"Erev Tish'a B'Av" => "Erev Tisha b'Av",
"Erev Rosh Hashana" => "Leil S'lichot Erev Rosh Hashanah",
"Rosh Hashana" => "Rosh Hashanah 1",
"Rosh Hashana II" => "Rosh Hashanah 2",
"Yom HaShoah" => "Yom HaShoah V'hag'vurah",
"Yom HaAtzma'ut" => "Yom Ha'atzm'ut",
"Lag B'Omer" => "Lag Ba'Omer",
"Erev Pesach" => "Erev Pesach/Ta’anit Bechorot",
"Shmini Atzeret" => "Sh'mini Atzeret/Simchat Torah",
"Sukkot I" => "Sukkot 1",
"Sukkot VII (Hoshana Raba)" => "Hoshana Raba",
"Pesach Sheni" => "Pesach Sheini",
);

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
my $dbfile = shift;
my $xml_datadir = shift;
my $outdir = shift;

if (! -d $xml_datadir) {
    die "$xml_datadir: $!\n";
}

my $xml_pages_file = "$xml_datadir/other/pages.xml";
if (! -f $xml_pages_file) {
    die "$xml_pages_file: $!\n";
}

if (! -d $outdir) {
    die "$outdir: $!\n";
}

print "Reading $festival_in...\n" if $opt_verbose;
my $fxml = XMLin($festival_in, KeyAttr => ['name', 'key', 'id'], ForceArray => 0);

my $HEB_YR;
if ($opt_year) {
    $HEB_YR = $opt_year;
} else {
    my($yy,$mm,$dd) = Date::Calc::Today();
    $HEB_YR = Hebcal::get_default_hebrew_year($yy,$mm,$dd);
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", "", "",
		    { RaiseError => 1, AutoCommit => 0 })
    or croak $DBI::errstr;
#my $sth = $dbh->prepare("SELECT num,reading FROM leyning WHERE dt = ? AND parashah = ?");
my $sth = $dbh->prepare("SELECT num,reading FROM leyning WHERE dt = ?");

my @html_cals;
my %html_cals;
my %day_content;
my @html_cal_ids;

generate_events();

$dbh->disconnect;
$dbh = undef;

generate_index();
generate_daily_pages();
exit(0);

sub generate_events {
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

    # build the calendar objects
    for (my @dt = ($start_year, $start_month, 1);
	 Date::Calc::Date_to_Days(@dt) <= $end_days;
	 @dt = Date::Calc::Add_Delta_YM(@dt, 0, 1)) {
	my $cal = new_html_cal($dt[0], $dt[1]);
	my $cal_id = sprintf("%04d-%02d", $dt[0], $dt[1]);
	push(@html_cals, $cal);
	push(@html_cal_ids, $cal_id);
	$html_cals{$cal_id} = $cal;
    }

    my %rosh_chodesh;
    my $rch_shabbat1 = find_item_content("Shabbat Rosh Chodesh I");
    my $rch_shabbat2 = find_item_content("Shabbat Rosh Chodesh II or One Day Rosh Chodesh");
    my $rch_weekday1 = find_item_content("Rosh Chodesh I Weekday");
    my $rch_weekday2 = find_item_content("Rosh Chodesh II or One Day Rosh Chodesh Weekday");

    foreach my $evt (@events) {
	my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];

	my($href,$hebrew,$hebcal_memo) = Hebcal::get_holiday_anchor($subj,0,undef);
	$subj =~ s/ \d{4}$//;	# Rosh Hashana hack
	$subj =~ s/Shavuot I/Shavuot/;

	my($year,$month,$day) = Hebcal::event_ymd($evt);
	my $dow = Date::Calc::Day_of_Week($year, $month, $day);

	my $luach_subj = translate_subject($subj,$dow);

	# TODO: add Hoshana Raba as a "Erev Sh'mini Atzeret/Simchat Torah"
	# also "Erev Shmini Atzeret" => "Erev Sh'mini Atzeret/Erev Simchat Torah Friday",

	my $xml_item = find_item($luach_subj);
	my $memo = "";
	if ($xml_item) {
	    $memo .= item_content($luach_subj, $xml_item);
	}

	my $torah_memo = torah_memo($subj, $year, $month, $day);
	$memo .= qq{\n<h3>($subj - Hebcal internal data)</h3><div class="well">$torah_memo</div>\n} if $torah_memo;

	if ($subj =~ /^Rosh Chodesh (.+)$/) {
	    my $rch_month = $1;
	    $rosh_chodesh{$rch_month} = [] unless defined $rosh_chodesh{$rch_month};
	    push(@{$rosh_chodesh{$rch_month}}, $evt);

	    ## TODO: this is not quite right - we need to pick the one or two-day version
	    if ($dow == 6) {
		$memo .= $rch_shabbat2;
	    } else {
		$memo .= $rch_weekday2;
	    }
	}

	add_event($year, $month, $day, $subj, $hebrew, $memo, $hebcal_memo, 1);
    }

    my $shabbat_machar_chodesh_title = "Machar Chodesh";
    my $shabbat_machar_chodesh_memo = find_item_content($shabbat_machar_chodesh_title);

    # figure out which Shabbatot are M'varchim haChodesh
    my $shabbat_mevarchim_title = "Shabbat M'varchim";
    my $shabbat_mevarchim_memo = find_item_content($shabbat_mevarchim_title);

    # Erev Rosh Chodesh
    my $erev_rch_weekday_memo = find_item_content("Erev Rosh Chodesh Weekday");
    my $erev_rch_friday_memo = find_item_content("Erev Rosh Chodesh Friday");

    for (my $abs = $start_abs; $abs <= $end_abs; $abs++) {
	my $greg = HebcalGPL::abs2greg($abs);
	my $dow = Date::Calc::Day_of_Week($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"});
	my $hebdate = HebcalGPL::abs2hebrew($abs);
	# Machar Chodesh
	if ($hebdate->{"dd"} >= 29 && $dow == 6) {
	    my $next_month = next_hebmonth_name($hebdate);
	    add_event($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"},
		      "$shabbat_machar_chodesh_title $next_month", undef,
		      $shabbat_machar_chodesh_memo,
		      undef, 0);
	}
	# M'varchim HaChodesh
	if ($dow == 6) {
	    if ($hebdate->{"dd"} >= 23 && $hebdate->{"dd"} <= 29 && $hebdate->{"mm"} != 6) {
		my $hebmonth = next_hebmonth_name($hebdate);
		my($year,$month,$day) = Hebcal::event_ymd($rosh_chodesh{$hebmonth}->[0]);
		my $dow = Hebcal::get_dow($year, $month, $day);
		my $when = "on <strong>" . $Hebcal::DoW_long[$dow] . "</strong>";
		if (defined $rosh_chodesh{$hebmonth}->[1]) {
		    ($year,$month,$day) = Hebcal::event_ymd($rosh_chodesh{$hebmonth}->[1]);
		    $dow = Hebcal::get_dow($year, $month, $day);
		    $when .= " and <strong>" . $Hebcal::DoW_long[$dow] . "</strong>";
		}
		my $memo = $shabbat_mevarchim_memo;
		$memo =~ s/new month of X\./new month of <strong>$hebmonth<\/strong>. Rosh Chodesh $hebmonth occurs $when in the coming week./;
		add_event($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"},
			  "Shabbat Mevarchim", undef, $memo,
			  "Shabbat which precedes Rosh Chodesh", 0);
	    }
	}
	# Erev Rosh Chodesh
	if ($hebdate->{"dd"} >= 29) {
	    my $next_month = next_hebmonth_name($hebdate);
	    add_event($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"},
		      "Erev Rosh Chodesh $next_month", undef,
		      $dow == 5 ? $erev_rch_friday_memo : $erev_rch_weekday_memo,
		      undef, 0);
	}
    }

    # Aseret Y'mei T'shuvah
    my $rh10days_title = "Aseret Y'mei T'shuva";
    my $rh10days_memo = find_item_content($rh10days_title);
    for (my $abs = $start_abs; $abs < $start_abs+10; $abs++) {
	my $greg = HebcalGPL::abs2greg($abs);
	add_event($greg->{"yy"}, $greg->{"mm"}, $greg->{"dd"}, $rh10days_title, undef, $rh10days_memo,
		  "Ten Days of Repentance beginning with Rosh Hashana and ending with Yom Kippur", 1);
    }
}

sub generate_index {
    my $outfile = "$outdir/index.html";
    open(OUT,">$outfile") || die "$outfile: $!";

    my $title = "Reform Luach $HEB_YR";
    print OUT html_header("/", $title);

    my $intro_content = find_item_content("Introduction");
    print OUT qq{<div class="lead">$intro_content</div>\n};

    foreach my $cal_id (@html_cal_ids) {
	add_daily_buttons($cal_id);
	my $cal = $html_cals{$cal_id};
	print OUT qq{<div id="cal-$cal_id" style="padding-top:12px">\n};
	print OUT $cal->as_HTML();
	print OUT qq{</div><!-- #cal-$cal_id -->\n};
    }

    print OUT html_footer();
    close(OUT);
}

sub html_footer {
    my $mtime = (defined $ENV{'SCRIPT_FILENAME'}) ?
	(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;
    my $hhmts = strftime("%d %B %Y", localtime($mtime));
    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime($mtime)) . "Z";

    my $html_footer =<<EOHTML;

<footer>
<hr>
<div id="inner-footer" class="clearfix">
<div class="pull-right"><time datetime="$dc_date">$hhmts</time></div>
<div class="pull-left"><p>Powered by <a href="http://www.hebcal.com/">Hebcal Jewish Calendar</a></p>
<p><small>Except where otherwise noted, content on this site is licensed under a <a rel="license"
href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative Commons Attribution 3.0 License</a>.</small></p>
</div><!-- .pull-left -->
</div><!-- #inner-footer -->
</footer>
</div><!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"></script>
<script src="//netdna.bootstrapcdn.com/bootstrap/3.0.0-rc1/js/bootstrap.min.js"></script>
</body></html>
EOHTML
;

    $html_footer;
}

sub generate_daily_pages {
    my $html_footer = html_footer();
    while (my($day_id,$content) = each(%day_content)) {
	my $outfile = "$outdir/$day_id";
	open(OUT,">$outfile") || die "$outfile: $!";
	my($yy,$mm,$dd) = split(/-/, $day_id);
	$mm =~ s/^0//;
	$dd =~ s/^0//;
	my $dow = $Hebcal::DoW_long[Hebcal::get_dow($yy, $mm, $dd)];
	my $when = sprintf("%s, %s %d, %d",
			   $dow, $Hebcal::MoY_long{$mm}, $dd, $yy);
	my $hdate = HebcalGPL::greg2hebrew($yy, $mm, $dd);

	my $heb_when = sprintf("%d%s of %s, %d",
			       $hdate->{"dd"},
			       HebcalGPL::numSuffix($hdate->{"dd"}),
			       $HEB_MONTH_NAME[HebcalGPL::LEAP_YR_HEB($hdate->{"yy"})][$hdate->{"mm"}],
			       $hdate->{"yy"});

	print OUT html_header("/$day_id", "$when - $heb_when | Reform Luach");
	print OUT qq{<div class="page-header"><h1>$when<br><small>$heb_when</small></h1></div>\n};
	foreach my $memo (@{$content}) {
	    print OUT "<div>\n", $memo, "</div>\n";
	}
	print OUT $html_footer;
	close(OUT);
    }

    my $about_content = find_item_content("About");
    my $outfile = "$outdir/about";
    open(OUT,">$outfile") || die "$outfile: $!";
    print OUT html_header("about", "About the Reform Luach");
    print OUT qq{<div class="page-header"><h1>About the Reform Luach</h1></div>\n};
    print OUT "<div>\n", $about_content, "</div>\n";
    print OUT $html_footer;
    close(OUT);
}


sub next_hebmonth_name {
    my($hebdate) = @_;
    my $hmonth = $hebdate->{"mm"} + 1;
    if ($hmonth > HebcalGPL::MONTHS_IN_HEB($hebdate->{"yy"})) {
	$hmonth = 1;
    }
    $HEB_MONTH_NAME[HebcalGPL::LEAP_YR_HEB($hebdate->{"yy"})][$hmonth];
}

sub translate_subject {
    my($subj,$dow) = @_;

    if ($dow == 5 && defined $FRIDAY_TRANSLATIONS{$subj}) {
	return $FRIDAY_TRANSLATIONS{$subj};
    }

    if ($subj =~ /^Parashat (.+)$/) {
	my $parashah = $PARASHAH_MAP{$1} || $1;
	if ($parashah =~ /^Shabbat/) {
	    return $parashah;
	}
	return "Shabbat $parashah";
    }

    if (defined $OTHER_TRANSLATIONS{$subj}) {
	return $OTHER_TRANSLATIONS{$subj};
    }

    $subj;
}

sub html_header {
    my($path,$title) = @_;
    my $s =<<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.0.0-rc1/css/bootstrap.min.css">
<link href='http://fonts.googleapis.com/css?family=Source+Sans+Pro:300,400,600,700' rel='stylesheet' type='text/css'>
<style type="text/css">
body{
 font-family: 'Source Sans Pro', sans-serif;
}
h1,h2,h3,h4,h5,h6,.h1,.h2,.h3,.h4,.h5,.h6 {
 font-family: 'Source Sans Pro', sans-serif;
 font-weight: 600;
}
.btn,.navbar-brand {
 font-weight: 600;
}
.lead,.jumbotron {
 font-weight: 300;
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

<div class="navbar">
 <div class="container">
  <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-responsive-collapse">
   <span class="icon-bar"></span>
   <span class="icon-bar"></span>
   <span class="icon-bar"></span>
  </button>
EOHTML
;
    if ($path eq "/") {
	$s .= qq{<span class="navbar-brand">Reform Luach</span>\n};
    } else {
	$s .= qq{<a class="navbar-brand" href="/">Reform Luach</a>\n};
    }

    my @month_menu_item = ( "#", "Calendar", "Calendar" );
    my $first = 1;
    foreach my $cal_id (@html_cal_ids) {
	if ($cal_id =~ /^(\d{4})-(\d{2})$/) {
	    my $year = $1;
	    my $mon = $2;
	    $mon =~ s/^0//;
	    my $mon_long = $Hebcal::MoY_long{$mon};
	    my $mon_short = $Hebcal::MoY_short[$mon-1];
	    my $title = $mon == 1 || $first ? "$mon_long $year" : $mon_long;
	    push(@month_menu_item, [ "./#cal-$cal_id", $title, "$mon_long $year" ]);
	    $first = 0;
	}
    }

    my @menu_items = ( [ "/", "Home", "Home" ],
		       [ "about", "About", "About" ],
		       \@month_menu_item,
		     );

    my $menu = Hebcal::html_menu_bootstrap($path,\@menu_items);

    $s .=<<EOHTML;
<div class="nav-collapse collapse navbar-responsive-collapse">
$menu
</div><!-- .nav-collapse -->
</div><!-- .container -->
</div><!-- .navbar -->

<div class="container">
EOHTML
;
    return $s;
}

sub get_slug {
    my($title) = @_;
    my $slug = lc($title);
    $slug =~ s/\'/-/g;
    $slug =~ s/\//-/g;
    $slug =~ s/\cM/ - /g;
    $slug =~ s/\(//g;
    $slug =~ s/\)//g;
    $slug =~ s/[^\w]/-/g;
    $slug =~ s/\s+/ /g;
    $slug =~ s/\s/-/g;
    $slug =~ s/-{2,}/-/g;
    $slug;
}

sub item_content {
    my($title,$item) = @_;
    my $slug = get_slug($title);
    return qq{<!-- CMS:$slug -->\n}
	. HTML::Entities::decode($item->{"content"})
	. qq{<!-- /CMS:$slug -->\n};
}

sub find_item_content {
    my($title) = @_;
    my $item = find_item($title);
    if ($item) {
	return item_content($title,$item);
    }
    undef;
}

sub find_item {
    my($title) = @_;

    my $slug = get_slug($title);
    my $result;
    my $file = "$xml_datadir/pages/$slug.xml";
    if (-s $file) {
	$result = XMLin($file, KeyAttr => ['name', 'key', 'id'], ForceArray => 0);
    } else {
	warn "unkown item $slug\n";
    }

    $result;
}

sub add_event ($$$$$$$) {
    my($year,$month,$day,$subj,$hebrew,$memo,$tooltip,$show_in_grid) = @_;
    my $cal_id = sprintf("%04d-%02d", $year, $month);
    my $cal = $html_cals{$cal_id};

    my $day_id = sprintf("%04d-%02d-%02d", $year, $month, $day);
    my $title = $tooltip ? qq{ title="$tooltip"} : "";
    my $html = qq{<div$title>$subj</div>};

    $day_content{$day_id} = [] unless defined $day_content{$day_id};
    push(@{$day_content{$day_id}}, $memo);

    if ($show_in_grid) {
	$cal->addcontent($day, $html);
    }
}

sub torah_memo {
    my($reason,$year,$month,$day) = @_;
    my $date_sql = Hebcal::date_format_sql($year, $month, $day);
    $reason =~ s/^Parashat\s+//;
#    my $rv = $sth->execute($date_sql,$reason) or die $dbh->errstr;
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

sub add_daily_buttons {
    my($cal_id) = @_;

    $cal_id =~ /^(\d{4})-(\d{2})$/;
    my $year = $1;
    my $month = $2;
    $month =~ s/^0//;

    my $cal = $html_cals{$cal_id};
    my $end_day = Date::Calc::Days_in_Month($year, $month);
    for (my $mday = 1; $mday <= $end_day ; $mday++) {
	my $day_id = sprintf("%04d-%02d-%02d", $year, $month, $mday);
	if (defined $day_content{$day_id}) {
	    my $s = $cal->getcontent($mday);
	    $cal->setcontent($mday, qq{<a href="$day_id">$s</a>});
	}
    }
}

sub new_html_cal {
    my($year,$month) = @_;

    my $cal = new HTML::CalendarMonthSimple("year" => $year,
					    "month" => $month);
    $cal->border(1);
    $cal->tableclass("table table-bordered");
    $cal->header(sprintf("<h2>%s %04d</h2>", $Hebcal::MoY_long{$month}, $year));

    $cal;
}


sub usage {
    $0 =~ s,.*/,,;  # basename
    my $usage = "usage: $0 [-hv] [-y <year>] festival.xml reform-luach.sqlite3 reform-luach-data-dir output-dir
    -h        Display usage information.
    -v        Verbose mode
    -y <year> Start with hebrew year <year> (default this year)
";
    die $usage;
}

# local variables:
# mode: cperl
# end:
