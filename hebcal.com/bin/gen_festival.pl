#!/usr/bin/perl -w

########################################################################
#
# Generates the festival pages for http://www.hebcal.com/holidays/
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
use LWP::UserAgent;
use HTTP::Request;
use POSIX qw(strftime);
use Digest::SHA qw(hmac_sha256_base64);
use Hebcal ();
use Date::Calc;
use RequestSignatureHelper;
use Config::Tiny;
use DBI;
use Carp;
use strict;

my $eval_use_Image_Magick = 0;

$0 =~ s,.*/,,;  # basename
my($usage) = "usage: $0 [-hvi] [-H <year>] festival.xml output-dir
  -h                Display usage information
  -v                Verbose mode
  -i                Use Israeli sedra scheme
  -H <year>         Start with hebrew year <year> (default this year)
";

my(%opts);
Getopt::Std::getopts('hvH:i', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

print "Reading $festival_in...\n" if $opts{"v"};
my $fxml = XML::Simple::XMLin($festival_in);

my $NOW = time();

my @FESTIVALS;
my %SUBFESTIVALS;
foreach my $node (@{$fxml->{'groups'}->{'group'}})
{
    my $f;
    if (ref($node) eq 'HASH') {
	$f = $node->{'content'};
	$f =~ s/^\s+//;
	$f =~ s/\s+$//;
	if (defined $node->{'li'}) {
	    $SUBFESTIVALS{$f} = $node->{'li'};
	} else {
	    $SUBFESTIVALS{$f} = [ $f ];
	}
    } else {
	$f = $node;
	$f =~ s/^\s+//;
	$f =~ s/\s+$//;
	$SUBFESTIVALS{$f} = [ $f ];
    }

    push(@FESTIVALS, $f);
}

my(%PREV,%NEXT);
{
    my $f2;
    foreach my $f (@FESTIVALS)
    {
	$PREV{$f} = $f2;
	$f2 = $f;
    }

    $f2 = undef;
    foreach my $f (reverse @FESTIVALS)
    {
	$NEXT{$f} = $f2;
	$f2 = $f;
    }
}

my $HEB_YR;
if ($opts{'H'}) {
    $HEB_YR = $opts{'H'};
} else {
    my($yy,$mm,$dd) = Date::Calc::Today();
    $HEB_YR = Hebcal::get_default_hebrew_year($yy,$mm,$dd);
}

my %GREG2HEB;
my $NUM_YEARS = 9;
my $NUM_YEARS_MAIN_INDEX = 5;
my $meta_greg_yr1 = $HEB_YR - 3761 - 1;
my $meta_greg_yr2 = $meta_greg_yr1 + $NUM_YEARS + 1;
print "Gregorian-to-Hebrew date map...\n" if $opts{"v"};
foreach my $i (0 .. $NUM_YEARS) {
    my $yr = $HEB_YR + $i - 1;
    my @events = Hebcal::invoke_hebcal("./hebcal -d -x -h -H $yr", '', 0);

    for (my $i = 0; $i < @events; $i++) {
	my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	if ($subj =~ /^\d+\w+ of [^,]+, \d+$/) {
	    my $isotime = sprintf("%04d%02d%02d",
				  $events[$i]->[$Hebcal::EVT_IDX_YEAR],
				  $events[$i]->[$Hebcal::EVT_IDX_MON] + 1,
				  $events[$i]->[$Hebcal::EVT_IDX_MDAY]);
	    $GREG2HEB{$isotime} = $subj;
	}
    }
}

my %OBSERVED;
print "Observed holidays...\n" if $opts{"v"};
holidays_observed(\%OBSERVED);

my %seph2ashk = reverse %Hebcal::ashk2seph;

# Set up the amazon request signing helper
my $helper;
my $AWS_HOST;
my $ua;
my $Config = Config::Tiny->read($Hebcal::CONFIG_INI_PATH);
my $DO_AMAZON = 1;
if ($Config) {
    $AWS_HOST = $Config->{_}->{"hebcal.aws.product-api.host"};
    $helper = new RequestSignatureHelper (
    +RequestSignatureHelper::kAWSAccessKeyId => $Config->{_}->{"hebcal.aws.product-api.id"},
    +RequestSignatureHelper::kAWSSecretKey => $Config->{_}->{"hebcal.aws.product-api.secret"},
    +RequestSignatureHelper::kEndPoint => $AWS_HOST,
					 );
} else {
    $DO_AMAZON = 0;
}

foreach my $f (@FESTIVALS)
{
    print "   $f...\n" if $opts{"v"};
    write_festival_page($fxml,$f);
}

my $pagead_300x250=<<EOHTML;
<script async src="http://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- 300x250, created 10/14/10 -->
<ins class="adsbygoogle"
 style="display:inline-block;width:300px;height:250px"
 data-ad-client="ca-pub-7687563417622459"
 data-ad-slot="1140358973"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
EOHTML
;

print "Index page...\n" if $opts{"v"};
write_index_page($fxml);

exit(0);

sub trim
{
    my($value) = @_;

    if ($value) {
	local($/) = undef;
	$value =~ s/^\s+//;
	$value =~ s/\s+$//;
	$value =~ s/\n/ /g;
	$value =~ s/\s+/ /g;
	$value =~ s/\.$//; 	# remove trailing period
    }

    $value;
}

sub get_var
{
    my($festivals,$f,$name,$nowarn) = @_;

    my $subf = $SUBFESTIVALS{$f}->[0];
    my $value = $festivals->{'festival'}->{$subf}->{$name};

    if (! defined $value) {
	warn "ERROR: no $name for $f" unless $nowarn;
    }

    if (ref($value) eq 'SCALAR') {
	$value = trim($value);
    }

    $value;
}

sub format_single_day {
    my($gy,$gm,$gd,$show_year) = @_;
    my $str = $Hebcal::MoY_short[$gm - 1] . " " . $gd;
    return $show_year ? ($str . ", " . $gy) : $str;
}

sub format_single_day_html {
    my($gy,$gm,$gd,$show_year) = @_;
    my($gy0,$gm0,$gd0) = Date::Calc::Add_Delta_Days($gy,$gm,$gd,-1);
    return "<span title=\"begins at sundown on " . format_single_day($gy0,$gm0,$gd0,0)
	. "\">" . format_single_day($gy,$gm,$gd,$show_year) . "</span>";
}

sub format_date_range {
    my($gy1,$gm1,$gd1,$gy2,$gm2,$gd2,$show_year) = @_;
    my $str = format_single_day_html($gy1,$gm1,$gd1,0) . "-";
    if ($gm1 == $gm2) {
	$str .= $gd2;
    } else {
	$str .= format_single_day($gy2,$gm2,$gd2,0);
    }
    return $show_year ? ($str . ", " . $gy2) : $str;
}

sub format_date_plus_delta {
    my($gy1,$gm1,$gd1,$delta,$show_year) = @_;
    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy1,$gm1,$gd1,$delta);
    return format_date_range($gy1,$gm1,$gd1,$gy2,$gm2,$gd2,$show_year);
}

sub table_cell_observed {
    my($f,$evt,$show_year) = @_;
    my($gy,$gm,$gd) = Hebcal::event_ymd($evt);
    my $s = "";
    if ($f eq "Chanukah") {
	$s .= format_date_plus_delta($gy, $gm, $gd, 7, $show_year);
    } elsif ($f eq "Purim" || $f eq "Tish'a B'Av") {
	$s .= format_single_day_html($gy, $gm, $gd, $show_year);
    } elsif (begins_at_dawn($f) || $f eq "Leil Selichot") {
	$s .= format_single_day($gy, $gm, $gd, $show_year);
    } elsif ($evt->[$Hebcal::EVT_IDX_YOMTOV] == 0) {
	$s .= format_single_day_html($gy, $gm, $gd, $show_year);
    } else {
	$s .= "<strong>"; # begin yomtov
	if ($f eq "Rosh Hashana" || $f eq "Shavuot") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
	} elsif ($f eq "Yom Kippur" || $f eq "Shmini Atzeret" || $f eq "Simchat Torah") {
	    $s .= format_single_day_html($gy, $gm, $gd, $show_year);
	} elsif ($f eq "Sukkot") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
	    $s .= "</strong><br>";
	    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 2);
	    $s .= format_date_plus_delta($gy2, $gm2, $gd2, 4, $show_year);
	} elsif ($f eq "Pesach") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
	    $s .= "</strong><br>";
	    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 2);
	    $s .= format_date_plus_delta($gy2, $gm2, $gd2, 3, $show_year);
	    $s .= "<br><strong>";
	    my($gy3,$gm3,$gd3) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 6);
	    $s .= format_date_plus_delta($gy3, $gm3, $gd3, 1, $show_year);
	}
	$s .= "</strong>" unless $f eq "Sukkot";
    }
    return $s;
}

sub table_index {
    my($festivals,$table_id,@holidays) = @_;
    print OUT3 <<EOHTML;
<table class="table" id="$table_id">
<col style="width:180px"><col><col style="background-color:#FFFFCC"><col><col><col><col>
<tbody>
EOHTML
;

    print OUT3 "<tr><th>Holiday</th>";
    foreach my $i (0 .. $NUM_YEARS_MAIN_INDEX) {
	my $yr = $HEB_YR + $i - 1;
	my $greg_yr1 = $yr - 3761;
	my $greg_yr2 = $greg_yr1 + 1;
	print OUT3 "<th><a href=\"$greg_yr1-$greg_yr2\">$yr<br>($greg_yr1-$greg_yr2)</a></th>";
    }
    print OUT3 "</tr>\n";

    foreach my $f (@holidays) {
	my $descr;
	my $about = get_var($festivals, $f, 'about');
	if ($about) {
	    $descr = trim($about->{'content'});
	}
	die "no descr for $f" unless $descr;

	my $short_descr = $descr;
	$short_descr =~ s/\..*//;
	my $slug = Hebcal::make_anchor($f);

	print OUT3 qq{<tr><td><a href="$slug" title="$short_descr">$f</a></td>\n};
	foreach my $i (0 .. $NUM_YEARS_MAIN_INDEX) {
	    print OUT3 "<td class=\"date-obs\">";
	    if (defined $OBSERVED{$f} && defined $OBSERVED{$f}->[$i]) {
		my $evt = $OBSERVED{$f}->[$i];
		print OUT3 table_cell_observed($f, $evt, 0);
	    }
	    print OUT3 "</td>\n";
	}
	print OUT3 "</tr>\n";
    }

    print OUT3 <<EOHTML;
</tbody>
</table>
EOHTML
;
}

sub table_one_year_only {
    my($festivals,$table_id,$i,@holidays) = @_;
    print OUT4 <<EOHTML;
<table class="table table-striped" id="$table_id">
<col style="width:180px"><col style="width:180px"><col>
<tbody>
EOHTML
;

    print OUT4 "<tr><th>Holiday</th>";
    my $yr = $HEB_YR + $i - 1;
    print OUT4 "<th>Hebrew Year $yr</th>";
    print OUT4 "<th>Description</th>";
    print OUT4 "</tr>\n";

    foreach my $f (@holidays) {
	my $descr;
	my $about = get_var($festivals, $f, 'about');
	if ($about) {
	    $descr = trim($about->{'content'});
	}
	die "no descr for $f" unless $descr;

	my $slug = Hebcal::make_anchor($f);
	my $short_descr = $descr;
	$short_descr =~ s/\..*//;

	print OUT4 qq{<tr><td><a href="$slug">$f</a></td>\n};
	print OUT4 "<td>";
	if (defined $OBSERVED{$f} && defined $OBSERVED{$f}->[$i]) {
	  my $evt = $OBSERVED{$f}->[$i];
	  print OUT4 table_cell_observed($f, $evt, 1);
	}
	print OUT4 "</td>\n<td>$short_descr</td>\n";
	print OUT4 "</tr>\n";
    }

    print OUT4 <<EOHTML;
</tbody>
</table>
EOHTML
;
}

sub get_index_body_preamble {
    my($page_title,$do_multi_year,$heb_year,$div_class) = @_;

    my $str = <<EOHTML;
<div class="$div_class">
<div class="page-header">
<h1>$page_title</h1>
</div>
<p>All holidays begin at sundown on the evening before the date
specified in the tables below. For example, if the dates for Rosh
Hashana were listed as <strong>Sep 19-20</strong>, then the holiday begins at
sundown on <strong>Sep 18</strong> and ends at sundown on <strong>Sep 20</strong>.
Dates in <strong>bold</strong> are <em>yom tov</em>, so they have similar
obligations and restrictions to Shabbat in the sense that normal "work"
is forbidden.</p>
EOHTML
;

    if ($do_multi_year) {
      $str .= <<EOHTML;
<p>The tables of holidays below include the current year and 4 years
into the future for the Diaspora.</p>
EOHTML
;
    }

    my $custom_link =
	$heb_year ? "/hebcal/?v=0&amp;year=$heb_year&amp;yt=H" : "/hebcal/";
    my $pdf_heb_year = $heb_year || $HEB_YR;

    $str .= <<EOHTML;
<div class="btn-toolbar">
<a class="btn btn-small" title="for desktop, mobile and web calendars" href="/ical/"><i class="icon-download-alt"></i> Download</a>
<a class="btn btn-small download" title="PDF one page per month, in landscape" id="pdf-${pdf_heb_year}" href="hebcal-${pdf_heb_year}.pdf"><i class="icon-print"></i> Print PDF</a>
<a class="btn btn-small" title="Hebcal Custom Calendar" href="$custom_link"><i class="icon-pencil"></i> Customize your calendar</a>
</div><!-- .btn-toolbar -->
EOHTML
;

    return $str;
}

sub write_index_page
{
    my($festivals) = @_;

    my $fn = "$outdir/index.html";
    open(OUT3, ">$fn.$$") || die "$fn.$$: $!\n";

    my $meta = <<EOHTML;
<meta name="description" content="Dates of major and minor Jewish holidays for years $meta_greg_yr1-$meta_greg_yr2. Links to pages describing observance and customs, holiday Torah readings.">
EOHTML
;

    my $major = "Rosh Hashana,Yom Kippur,Sukkot,Shmini Atzeret,Simchat Torah,Chanukah,Purim,Pesach,Shavuot,Tish'a B'Av";
    my @major = split(/,/, $major);

    my $modern = "Yom HaShoah,Yom HaZikaron,Yom HaAtzma'ut,Yom Yerushalayim";
    my @modern = split(/,/, $modern);

    my $public_fasts = "Tzom Gedaliah,Asara B'Tevet,Ta'anit Esther,Ta'anit Bechorot,Tzom Tammuz";
    my @public_fasts = split(/,/, $public_fasts);

    my %everything_else = map { $_ => 1 } @major, @modern, @public_fasts;

    my @minor;
    my @special_shabbat;
    my @rosh_chodesh;
    foreach my $f (@FESTIVALS) {
	if ($f =~ /^Rosh Chodesh/) {
	    push(@rosh_chodesh, $f);
	} elsif ($f =~ /^Shabbat /) {
	    push(@special_shabbat, $f);
	} elsif (! defined $everything_else{$f}) {
	    push(@minor, $f);
	}
    }

    my @sections = (
       [ \@major,		"Major holidays" ],
       [ \@minor,		"Minor holidays" ],
       [ \@public_fasts,	"Minor fasts" ],
       [ \@modern,		"Modern holidays" ],
       [ \@special_shabbat,	"Special Shabbatot" ],
       [ \@rosh_chodesh,	"Rosh Chodesh" ],
    );


    my @table_ids;
    foreach my $section (@sections) {
      my $table_id = lc($section->[1]);
      $table_id =~ s/\s+/-/g;
      push(@table_ids, "hebcal-$table_id");
    }

    my $td_sep = " tr td,\n#";
    my $xtra_head = qq{<style type="text/css">\n};
    $xtra_head .= "#" . join($td_sep, @table_ids) . $td_sep;
    $xtra_head .= join(" tr th,\n#", @table_ids);
    $xtra_head .= " tr th {\n  padding: 4px;\n}\n";

    $xtra_head .= "#" . join(" td.date-obs,\n#", @table_ids);
    $xtra_head .= " td.date-obs {\n  font-size: 12px;\n  line-height:16px;\n}\n";
    $xtra_head .= "</style>\n";


    my $page_title = "Jewish Holidays";
    print OUT3 Hebcal::html_header_bootstrap(
	$page_title, "/holidays/", "ignored",  $meta . $xtra_head);

    print OUT3 qq{<div class="row-fluid">\n};
    print OUT3 get_index_body_preamble($page_title, 1, undef, "span8");
    print OUT3 <<EOHTML;
</div><!-- .span8 -->
<div class="span4">
<h5>Advertisement</h5>
$pagead_300x250
</div><!-- .span4 -->
</div><!-- .row-fluid -->
EOHTML
;
    print OUT3 qq{<div class="row-fluid">\n};
    print OUT3 qq{<div class="span12">\n};

    foreach my $section (@sections) {
      my $heading = $section->[1];
      print OUT3 "<h3>", $heading, "</h3>\n";
      my $table_id = lc($heading);
      $table_id =~ s/\s+/-/g;
      table_index($festivals, "hebcal-$table_id", @{$section->[0]});
    }

    print OUT3 qq{</div><!-- .span12 -->\n};
    print OUT3 qq{</div><!-- .row-fluid -->\n};
    print OUT3 Hebcal::html_footer_bootstrap(undef, undef);

    close(OUT3);
    rename("$fn.$$", $fn) || die "$fn: $!\n";

    # SEO - one page per year
    foreach my $i (0 .. $NUM_YEARS) {
	write_hebrew_year_index_page($i,
				     $festivals,
				     \@sections,
				     $xtra_head);
    }
}

sub write_hebrew_year_index_page {
    my($i,$festivals,$sections,$xtra_head) = @_;

    my $heb_year = $HEB_YR + $i - 1;
    my $greg_yr1 = $heb_year - 3761;
    my $greg_yr2 = $greg_yr1 + 1;

    my $slug = "$greg_yr1-$greg_yr2";
    my $fn = "$outdir/$slug";
    open(OUT4, ">$fn.$$") || die "$fn.$$: $!\n";

    my $page_title = "Jewish Holidays $slug";

    my $meta = <<EOHTML;
<meta name="description" content="Dates of major and minor Jewish holidays for years $greg_yr1-$greg_yr2 (Hebrew year $heb_year), observances and customs, holiday Torah readings.">
EOHTML
;

    print OUT4 Hebcal::html_header_bootstrap($page_title,
					     "/holidays/$slug",
					     "single single-post",
					     $meta . $xtra_head,
					     0);

    print OUT4 qq{<div class="row-fluid">\n};
    print OUT4 get_index_body_preamble($page_title, 0, $heb_year, "span8");
    print OUT4 <<EOHTML;
</div><!-- .span8 -->
<div class="span4">
<h5>Advertisement</h5>
$pagead_300x250
</div><!-- .span4 -->
</div><!-- .row-fluid -->
EOHTML
;
    print OUT4 qq{<div class="row-fluid">\n};
    print OUT4 qq{<div class="span12">\n};
    print OUT4 qq{<div class="pagination pagination-small"><ul>\n};
    foreach my $j (0 .. $NUM_YEARS) {
	my $other_yr = $HEB_YR + $j - 1;
	my $other_greg_yr1 = $other_yr - 3761;
	my $other_greg_yr2 = $other_greg_yr1 + 1;
	my $other_slug = "$other_greg_yr1-$other_greg_yr2";

	if ($i == $j) {
	    print OUT4 qq{<li class="active">};
	} else {
	    print OUT4 qq{<li>};
	}
	print OUT4 qq{<a title="Hebrew Year $other_yr" href="$other_slug">$other_slug</a></li>\n};
    }
    print OUT4 qq{</ul></div>\n};

    foreach my $section (@{$sections}) {
	my $heading = $section->[1];
	print OUT4 "<h3>", $heading, "</h3>\n";
	my $table_id = lc($heading);
	$table_id =~ s/\s+/-/g;
	table_one_year_only($festivals, "hebcal-$table_id", $i, @{$section->[0]});
    }

    print OUT4 qq{</div><!-- .span12 -->\n};
    print OUT4 qq{</div><!-- .row-fluid -->\n};
    print OUT4 Hebcal::html_footer_bootstrap(undef, undef);

    close(OUT4);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}

sub get_torah_and_maftir {
    my($aliyot) = @_;
    if (ref($aliyot) eq 'HASH') {
	$aliyot = [ $aliyot ];
    }

    my($torah,$maftir,$book,$begin,$end);
    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}}
			    @{$aliyot}) {
	if ($aliyah->{'num'} eq 'M') {
	    $maftir = sprintf("%s %s - %s",
			      $aliyah->{'book'},
			      $aliyah->{'begin'},
			      $aliyah->{'end'});
	}

	if ($aliyah->{'num'} =~ /^\d+$/) {
	    if (($book && $aliyah->{'book'} eq $book) ||
		($aliyah->{'num'} eq '8')) {
		$end = $aliyah->{'end'};
	    }
	    $book = $aliyah->{'book'} unless $book;
	    $begin = $aliyah->{'begin'} unless $begin;
	}
    }

    if ($book) {
	$torah = "$book $begin - $end";
    }

    ($torah,$maftir);
}


sub write_festival_part
{
    my($festivals,$f) = @_;

    my $slug = Hebcal::make_anchor($f);

    my $torah;
    my $maftir;
    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'verse'}) {
	    $torah = $festivals->{'festival'}->{$f}->{'kriyah'}->{'verse'};
	} else {
	    my $aliyot = $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	    ($torah,$maftir) = get_torah_and_maftir($aliyot);
	    if ($torah && $maftir) {
		$torah .= " &amp; $maftir";
	    } elsif ($maftir) {
		$torah = "$maftir (special maftir)";
	    }
	}
    }

    if ($torah) {
	my $torah_href = $festivals->{'festival'}->{$f}->{'kriyah'}->{'torah'}->{'href'};

	print OUT2 qq{\n<h4 id="$slug-torah" style="margin-bottom:8px">Torah Portion: };
	print OUT2 qq{<a class="outbound" href="$torah_href"\ntitle="Translation from JPS Tanakh">}
	    if ($torah_href);
	print OUT2 $torah;
	print OUT2 qq{</a>}
	    if ($torah_href);
	print OUT2 qq{</h4>\n};

	if (! $torah_href) {
	    warn "$f: missing Torah href\n";
	}

	if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	    print OUT2 "<p>";
	    my $aliyot = $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	    if (ref($aliyot) eq 'HASH') {
		$aliyot = [ $aliyot ];
	    }

	    foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}} @{$aliyot}) {
		print_aliyah($aliyah);
	    }
	    print OUT2 "</p>\n";
	}

    }

    my $haft = $festivals->{'festival'}->{$f}->{'kriyah'}->{'haft'}->{'reading'};
    if ($haft) {
	my $haft_href = $festivals->{'festival'}->{$f}->{'kriyah'}->{'haft'}->{'href'};

	print OUT2 qq{\n<h4 id="$slug-haft">Haftarah: };
	print OUT2 qq{<a class="outbound" href="$haft_href"\ntitle="Translation from JPS Tanakh">}
	    if ($haft_href);
	print OUT2 $haft;
	print OUT2 qq{</a>}
	    if ($haft_href);
	print OUT2 qq{</h4>\n};

	if (! $haft_href) {
	    warn "$f: missing Haft href\n";
	}
    }
}

sub day_event_observed {
    my($f,$evt) = @_;
    my($gy,$gm,$gd) = Hebcal::event_ymd($evt);
    if (!begins_at_dawn($f) && $f ne "Leil Selichot") {
	($gy,$gm,$gd) = Date::Calc::Add_Delta_Days($gy,$gm,$gd,-1);
    }
    return ($gy,$gm,$gd);
}

sub begins_when {
    my($f) = @_;
    if ($f eq "Leil Selichot") {
	return "after nightfall";
    } elsif (begins_at_dawn($f)) {
	return "at dawn";
    } else {
	return "at sundown";
    }
}

sub begins_at_dawn {
    my($f) = @_;
    return ($f =~ /^(Tzom|Asara|Ta\'anit) /) ? 1 : 0;
}

sub write_festival_page
{
    my($festivals,$f) = @_;

    my $slug = Hebcal::make_anchor($f);

    my $descr;
    my $about = get_var($festivals, $f, 'about');
    if ($about) {
	$descr = trim($about->{'content'});
    }
    warn "$f: missing About description\n" unless $descr;

    my $fn = "$outdir/$slug";
    open(OUT2, ">$fn.$$") || die "$fn.$$: $!\n";

    my $short_descr = $descr;
    $short_descr =~ s/\..*//;

    my $page_title = "$f - $short_descr";

    my $keyword = $f;
    $keyword .= ",$seph2ashk{$f}" if defined $seph2ashk{$f};

    my $hebrew = get_var($festivals, $f, 'hebrew');
    if ($hebrew) {
	$hebrew = Hebcal::hebrew_strip_nikkud($hebrew);
	$page_title .= " - $hebrew";
    } else {
	$hebrew = "";
    }

    my $next_observed = get_next_observed_str($f);

    my $meta = <<EOHTML;
<meta name="description" content="Jewish holiday of $f$next_observed$descr. Holiday Torah readings, dates observed.">
EOHTML
;

    print OUT2 Hebcal::html_header_bootstrap(
	 $page_title, "/holidays/$slug", "ignored", $meta, 0, 1);

    my $wikipedia_descr;
    my $wikipedia = get_var($festivals, $f, 'wikipedia', 1);
    if ($wikipedia) {
	$wikipedia_descr = trim($wikipedia->{'content'});
    }
    my $long_descr = $wikipedia_descr ? $wikipedia_descr : $descr;
    $long_descr =~ s/(\p{script=Hebrew}[\p{script=Hebrew}\s]+\p{script=Hebrew})/<span lang="he" dir="rtl">$1<\/span>/g;

    my $pager = qq{<ul class="pager hidden-phone">\n};
    my $prev = $PREV{$f};
    if ($prev) {
	my $prev_slug = Hebcal::make_anchor($prev);
	$pager .= qq{<li class="previous"><a title="Previous Holiday" href="$prev_slug" rel="prev">&larr; $prev</a></li>\n};
    }
    my $next = $NEXT{$f};
    if ($next) {
	my $next_slug = Hebcal::make_anchor($next);
	$pager .= qq{<li class="next"><a title="Next Holiday" href="$next_slug" rel="next">$next &rarr;</a></li>\n};
    }
    $pager .= qq{</ul>\n};

    print OUT2 <<EOHTML;
<div class="span10">
$pager
<div class="page-header">
<h1>$f / <span lang="he" dir="rtl">$hebrew</span></h1>
</div>
<p class="lead">$long_descr.</p>
EOHTML
;

    print OUT2 read_more_from($f,$about,$wikipedia);

    if (defined $OBSERVED{$f})
    {
	my $rise_or_set = begins_when($f);

	print OUT2 <<EOHTML;
<h3 id="dates">List of Dates</h3>
$f begins in the Diaspora on:
<ul>
EOHTML
	;
	my $displayed_upcoming = 0;
	foreach my $evt (@{$OBSERVED{$f}}) {
	    next unless defined $evt;
	    my $isotime = sprintf("%04d%02d%02d",
				  $evt->[$Hebcal::EVT_IDX_YEAR],
				  $evt->[$Hebcal::EVT_IDX_MON] + 1,
				  $evt->[$Hebcal::EVT_IDX_MDAY]);
	    my($gy,$gm,$gd) = day_event_observed($f,$evt);
	    my $dow = Hebcal::get_dow($gy,$gm,$gd);
	    my $style = "";
	    if (!$displayed_upcoming) {
	      my $time = Hebcal::event_to_time($evt);
	      if ($time >= $NOW) {
		$style = qq{ style="background-color:#FFFFCC"};
		$displayed_upcoming = 1;
	      }
	    }
	    my $nofollow = $gy > $this_year + 2 ? qq{ rel="nofollow"} : "";
	    my $html5time = sprintf("%04d-%02d-%02d", $gy, $gm, $gd);
	    printf OUT2 "<li><a%s href=\"/hebcal/?v=1&amp;year=%d&amp;month=%d" .
		"&amp;nx=on&amp;mf=on&amp;ss=on&amp;nh=on&amp;D=on&amp;vis=on&amp;set=off\"$style>" .
		"<time datetime=\"%s\">%s, %02d %s %04d</time></a> $rise_or_set (%s)\n",
		$nofollow,
		$gy, $gm,
		$html5time, $Hebcal::DoW[$dow],
		$gd, $Hebcal::MoY_long{$gm}, $gy, $GREG2HEB{$isotime};
	}
	print OUT2 <<EOHTML;
</ul>
EOHTML
    ;
    }

    amazon_recommended_books($festivals,$f) if $DO_AMAZON;

    if (@{$SUBFESTIVALS{$f}} == 1)
    {
	write_festival_part($festivals, $SUBFESTIVALS{$f}->[0]);
    }
    else
    {
	foreach my $part (@{$SUBFESTIVALS{$f}})
	{
	    my $part2;
	    if ($part =~ /^$f(.*)/i) {
		$part2 = "reading$1";
	    } else {
		$part2 = $part;
	    }

	    my $slug = Hebcal::make_anchor($part2);
	    $slug =~ s/\.html$//;

	    print OUT2 qq{\n<h3 id="$slug">$part};
	    my $part_hebrew = $festivals->{'festival'}->{$part}->{'hebrew'};
	    if ($part_hebrew)
	    {
		$part_hebrew = Hebcal::hebrew_strip_nikkud($part_hebrew);
		print OUT2 qq{\n- <span lang="he" dir="rtl">$part_hebrew</span>};
	    }
	    print OUT2 qq{</h3>\n};

	    my $part_about = $festivals->{'festival'}->{$part}->{'about'};
	    if ($part_about) {
		my $part_descr = trim($part_about->{'content'});
		if ($part_descr && $part_descr ne $descr) {
		    print OUT2 qq{<p>$part_descr.\n};
		}
	    }

	    write_festival_part($festivals,$part);
	    print OUT2 qq{<!-- $slug -->\n};
	}
    }

    print OUT2 qq{
<h3 id="ref">References</h3>
<dl>
<dt><em><a class="amzn" id="strassfeld-2"
href="http://www.amazon.com/o/ASIN/0062720082/hebcal-20">The
Jewish Holidays: A Guide &amp; Commentary</a></em>
<dd>Rabbi Michael Strassfeld
};

    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	print OUT2 qq{<dt><em><a class="outbound"
href="http://www.mechon-mamre.org/p/pt/pt0.htm">Hebrew - English Bible</a></em>
<dd>Mechon Mamre
<dt><em><a class="amzn" id="jps-tanakh-1"
title="Tanakh: The Holy Scriptures, The New JPS Translation According to the Traditional Hebrew Text" 
href="http://www.amazon.com/o/ASIN/0827602529/hebcal-20">Tanakh:
The Holy Scriptures</a></em>
<dd>Jewish Publication Society
};
    }

    if (defined $wikipedia_descr) {
	my $wikipedia_href = $wikipedia->{'href'};
	my $wiki_title = $wikipedia_href;
	$wiki_title =~ s/\#.+$//;
	$wiki_title =~ s/^.+\///;
	$wiki_title =~ s/_/ /g;

	print OUT2 qq{<dt><a class="outbound"
href="$wikipedia_href">"$wiki_title"
in <em>Wikipedia: The Free Encyclopedia</em></a>
<dd>Wikimedia Foundation Inc.
};
    }

    print OUT2 "</dl>\n";

    print OUT2 <<EOHTML;
$pager
</div><!-- .span10 -->
<div class="span2">
<h5>Advertisement</h5>
<script async src="http://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- skyscraper text only -->
<ins class="adsbygoogle"
     style="display:inline-block;width:160px;height:600px"
     data-ad-client="ca-pub-7687563417622459"
     data-ad-slot="7666032223"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .span2 -->
EOHTML
;
    print OUT2 Hebcal::html_footer_bootstrap(undef, undef);

    close(OUT2);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}

sub read_more_hyperlink {
  my($f,$href,$title) = @_;
  return qq{<a class="outbound" title="More about $f from $title" href="$href">$title &rarr;</a>};
}

sub read_more_from {
  my($f,$about,$wikipedia) = @_;
  my $html = "";
  my $about_href;
  my $wikipedia_href;
  my $primary_source = "";
  if ($about) {
    $about_href = $about->{'href'};
    if ($about_href && $about_href =~ /^http:\/\/([^\/]+)/i) {
      my $more = $1;
      $more =~ s/^www\.//i;
      if ($more eq 'hebcal.com') {
	$primary_source = 'Hebcal';
      } elsif ($more eq 'jewfaq.org') {
	$primary_source = "Judaism 101";
      } elsif ($more eq "en.wikipedia.org") {
	$primary_source = "Wikipedia";
      } else {
	$primary_source = $more;
      }
    } else {
      $about_href = undef;
    }
  }
  if ($wikipedia) {
    $wikipedia_href = $wikipedia->{'href'};
  }
  if ($about_href || $wikipedia_href) {
    $html = qq{\n<p><em>Read more from };
    if ($about_href) {
      $html .= read_more_hyperlink($f,$about_href, $primary_source);
      $html .= " or " if ($wikipedia_href && $primary_source ne "Wikipedia");
    }
    if ($wikipedia_href && $primary_source ne "Wikipedia") {
	$html .= read_more_hyperlink($f,$wikipedia_href, "Wikipedia");
    }
    $html .= qq{</em></p>\n};
  }
  return $html;
}

sub format_aliyah_info {
    my($aliyah) = @_;

    my($c1,$v1) = ($aliyah->{'begin'} =~ /^([^:]+):([^:]+)$/);
    my($c2,$v2) = ($aliyah->{'end'}   =~ /^([^:]+):([^:]+)$/);
    my $info = $aliyah->{'book'} . " ";
    if ($c1 eq $c2) {
	$info .= "$c1:$v1-$v2";
    } else {
	$info .= "$c1:$v1-$c2:$v2";
    }
    $info;
}

sub print_aliyah
{
    my($aliyah) = @_;

    my($c1,$v1) = ($aliyah->{'begin'} =~ /^([^:]+):([^:]+)$/);
#    my $url = Hebcal::get_mechon_mamre_url($aliyah->{'book'}, $c1, $v1);
#    my $title = "Hebrew-English bible text";
    my $url = Hebcal::get_bible_ort_org_url($aliyah->{'book'}, $c1, $v1, $aliyah->{'parsha'});
    $url =~ s/&/&amp;/g;
    my $title = "Hebrew-English bible text from ORT";
    my $info = qq{<a class="outbound" title="$title"\nhref="$url">}
	. format_aliyah_info($aliyah)
	. qq{</a>};

    my($label) = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    print OUT2 qq{$label: $info};

    if ($aliyah->{'numverses'}) {
	print OUT2 "\n<small>(",
	$aliyah->{'numverses'}, "&nbsp;p'sukim)</small>";
    }

    print OUT2 qq{<br>\n};
}

sub holidays_observed
{
    my($current) = @_;

    foreach my $i (0 .. $NUM_YEARS)
    {
	my $yr = $HEB_YR + $i - 1;
	my $cmd = "./hebcal";
	$cmd .= " -i" if $opts{"i"};
	$cmd .= " -H $yr";
	my @events = Hebcal::invoke_hebcal($cmd, "", 0);
	foreach my $evt (@events) {
	    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
	    next if $subj =~ /^Erev /;

	    # Since Chanukah doesn't have an Erev, skip a day
	    next if $subj =~ /^Chanukah: 1 Candle$/;

	    my $subj_copy = $subj;
	    $subj_copy =~ s/ \d{4}$//;
	    $subj_copy =~ s/ \(CH\'\'M\)$//;
	    $subj_copy =~ s/ \(Hoshana Raba\)$//;
	    if ($subj ne "Rosh Chodesh Adar II") {
		$subj_copy =~ s/ [IV]+$//;
	    }
	    $subj_copy =~ s/: \d Candles?$//;
	    $subj_copy =~ s/: 8th Day$//;

	    $current->{$subj_copy}->[$i] = $evt
		unless (defined $current->{$subj_copy} &&
			defined $current->{$subj_copy}->[$i]);
	}
    }
}

sub findError {
    my $xml = shift;
    
    return undef unless ref($xml) eq 'HASH';

    if (exists $xml->{Error}) { return $xml->{Error}; };

    for (keys %$xml) {
	my $error = findError($xml->{$_});
	return $error if defined $error;
    }

    return undef;
}

sub get_next_observed_str {
    my($f) = @_;

    my $next_observed = ". ";
    if (defined $OBSERVED{$f}) {
	my $rise_or_set = begins_when($f);
	foreach my $evt (@{$OBSERVED{$f}}) {
	    next unless defined $evt;
	    my($gy,$gm,$gd) = day_event_observed($f, $evt);
	    my $time = Hebcal::event_to_time($evt);
	    if ($time >= $NOW) {
		my $dow = Hebcal::get_dow($gy, $gm, $gd);
		$next_observed = sprintf ", begins %s on %s, %02d %s %04d. ", $rise_or_set,
		    $Hebcal::DoW[$dow], $gd, $Hebcal::MoY_long{$gm}, $gy;
		last;
	    }
	}
    }

    $next_observed;
}

sub amazon_recommended_books {
    my($festivals,$f) = @_;

    my $subf = $SUBFESTIVALS{$f}->[0];
    my $books = $festivals->{"festival"}->{$subf}->{"books"}->{"book"};
    return 0 unless $books;

    if (ref($books) eq 'HASH') {
	$books = [ $books ];
    }

    my $slug = Hebcal::make_anchor($f);
    my $slug2 = $slug;
    $slug2 =~ s/\.html$//;

    print OUT2 qq{<h3 id="books">Recommended Books</h3>\n<table style="padding:6px"><tr>\n};
    foreach my $book (@{$books}) {
	my $asin = $book->{"ASIN"};
	my $img;
	my $filename;
	foreach my $type (qw(T M)) {
	    $img = "$asin.01.${type}ZZZZZZZ.jpg";
	    $filename = $outdir . "/../i/" . $img;
	    if (! -e $filename) {
		$ua = LWP::UserAgent->new unless $ua;
		$ua->timeout(10);
		$ua->mirror("http://images.amazon.com/images/P/$img",
			    $filename);
	    }
	}

	unless ($eval_use_Image_Magick) {
	    eval("use Image::Magick");
	    $eval_use_Image_Magick = 1;
	}

	my $image = new Image::Magick;
	$image->Read($filename);
	my($width,$height) = $image->Get("width", "height");

	my $bktitle = $book->{"content"};
	my $author = $book->{"author"};

	if (!$bktitle) {
	    $ua = LWP::UserAgent->new unless $ua;
	    $ua->timeout(10);
	    my %params = (
			  "Service" => "AWSECommerceService",
			  "Operation" => "ItemLookup",
			  "ItemId" => $asin,
			  "ResponseGroup" => "ItemAttributes",
			  "Version" => "2009-01-06",
			  "Timestamp" => strftime("%Y-%m-%dT%TZ", gmtime()),
			  "AssociateTag" => "hebcal-20",
			 );
	    my $signedRequest = $helper->sign(\%params);
	    my $queryString = $helper->canonicalize($signedRequest);
	    my $url = "http://" . $AWS_HOST . "/onca/xml?" . $queryString;
	    my $request = HTTP::Request->new("GET", $url);
	    my $response = $ua->request($request);
	    my $rxml = XML::Simple::XMLin($response->content);
	    if (!$response->is_success()) {
		my $error = findError($rxml);
		if (defined $error) {
		    print STDERR "Error: " . $error->{Code} . ": " . $error->{Message} . "\n";
		} else {
		    print STDERR "Unknown Error!\n";
		}
	    }

	    if (defined $rxml->{"Items"}->{"Item"}->{"ASIN"}
		&& $rxml->{"Items"}->{"Item"}->{"ASIN"} eq $asin) {
		my $attrs = $rxml->{"Items"}->{"Item"}->{"ItemAttributes"};
		$bktitle = $attrs->{"Title"};
		if (ref($attrs->{"Author"}) eq "ARRAY") {
		    $author = $attrs->{"Author"}->[0];
		} elsif (defined $attrs->{"Author"}) {
		    $author = $attrs->{"Author"};
		}
	    }
	    else {
		print STDERR "*** can't get Items/Item/ASIN from XML from ", $response->content, "\n";
	    }
	}
	else {
	    $author = trim($author) if $author;
	    $bktitle = trim($bktitle);
	    $bktitle =~ s/\n/ /g;
	    $bktitle =~ s/\s+/ /g;
	}

	my $shorttitle = $bktitle;
	$shorttitle =~ s/\s*:.+//;
	my $link = "http://www.amazon.com/o/ASIN/$asin/hebcal-20";
	print OUT2 qq{<td style="width:200px; text-align:center; vertical-align:top"><a class="amzn" id="$slug2-$asin-1" title="$bktitle" href="$link"><img src="/i/$img"\nalt="$bktitle"\nwidth="$width" height="$height" style="border:none; padding:4px"></a><br><a class="amzn" id="$slug2-$asin-2" title="$bktitle" href="$link">$shorttitle</a>};
	print OUT2 qq{<br>by $author} if $author;
	print OUT2 qq{</td>\n};
    }

    print OUT2 qq{</tr></table>\n};
}
