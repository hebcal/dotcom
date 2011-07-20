#!/usr/local/bin/perl -w

########################################################################
#
# Generates the festival pages for http://www.hebcal.com/holidays/
#
# $Id$
#
# Copyright (c) 2011  Michael J. Radwin.
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
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
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
use Image::Magick;
use URI::Escape qw(uri_escape_utf8);
use POSIX qw(strftime);
use Digest::SHA qw(hmac_sha256_base64);
use Hebcal ();
use Date::Calc;
use HebcalGPL ();
use RequestSignatureHelper;
use strict;

use constant myAWSId    => '15X7F0YJNN5FCYC7CGR2';
use constant myAWSSecret    => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
use constant myEndPoint    => 'ecs.amazonaws.com';

$0 =~ s,.*/,,;  # basename
my($usage) = "usage: $0 [-hy] [-H <year>] [f f.csv] festival.xml output-dir
    -h        Display usage information.
    -v        Verbose mode
    -H <year> Start with hebrew year <year> (default this year)
    -f f.csv  Dump full kriyah readings to comma separated values
";

my(%opts);
Getopt::Std::getopts('hf:vH:', \%opts) || die "$usage\n";
$opts{'h'} && die "$usage\n";
(@ARGV == 2) || die "$usage";

my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

print "Reading $festival_in...\n" if $opts{"v"};
my $fxml = XML::Simple::XMLin($festival_in);

if ($opts{'f'}) {
    my $fn = $opts{"f"};
    open(CSV, ">$fn.$$") || die "$fn.$$: $!\n";
    print CSV qq{"Date","Parashah","Aliyah","Reading","Verses"\015\012};
}

my $REVISION = '$Revision$'; #'
my $mtime_festival = (stat($festival_in))[9];
my $mtime_script = (stat($0))[9];
my $MTIME = $mtime_script > $mtime_festival ? $mtime_script : $mtime_festival;
my $MTIME_FORMATTED = strftime("%d %B %Y", localtime($MTIME));
my $html_footer = html_footer();

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
    my($this_year,$this_mon,$this_day) = Date::Calc::Today();
    my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
    $HEB_YR = $hebdate->{"yy"};
#    $HEB_YR++ if $hebdate->{"mm"} == 6; # Elul
}

my %GREG2HEB;
my $NUM_YEARS = 5;
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

# Set up the helper
my $helper = new RequestSignatureHelper (
    +RequestSignatureHelper::kAWSAccessKeyId => myAWSId,
    +RequestSignatureHelper::kAWSSecretKey => myAWSSecret,
    +RequestSignatureHelper::kEndPoint => myEndPoint,
					 );


my $ua;
foreach my $f (@FESTIVALS)
{
    print "   $f...\n" if $opts{"v"};
    write_festival_page($fxml,$f);
    write_csv($fxml,$f) if $opts{'f'};
}

if ($opts{'f'}) {
    close(CSV);
    rename("$opts{'f'}.$$", $opts{'f'}) || die "$opts{'f'}: $!\n";
}

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
    }

    $value;
}

sub get_var
{
    my($festivals,$f,$name) = @_;

    my $subf = $SUBFESTIVALS{$f}->[0];
    my $value = $festivals->{'festival'}->{$subf}->{$name};

    if (! defined $value) {
	warn "ERROR: no $name for $f";
    }

    if (ref($value) eq 'SCALAR') {
	$value = trim($value);
    }

    $value;
}

sub write_csv
{
    my($festivals,$f) = @_;

    print CSV "$f\n";

    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	my $aliyot = $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	if (ref($aliyot) eq 'HASH') {
	    $aliyot = [ $aliyot ];
	}

	foreach my $aliyah (sort {$a->{'num'} cmp $b->{'num'}} @{$aliyot}) {
	    printf CSV "Torah Service - Aliyah %s,%s %s - %s\n",
	    $aliyah->{'num'},
	    $aliyah->{'book'},
	    $aliyah->{'begin'},
	    $aliyah->{'end'};
	}
    }

    my $haft = $festivals->{'festival'}->{$f}->{'kriyah'}->{'haft'}->{'reading'};
    if (defined $haft) {
	print CSV "Torah Service - Haftarah,$haft\n",
    }

    print CSV "\n";
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
    my($gy,$gm,$gd) = ($evt->[$Hebcal::EVT_IDX_YEAR],
		       $evt->[$Hebcal::EVT_IDX_MON] + 1,
		       $evt->[$Hebcal::EVT_IDX_MDAY]);
    my $s = "";
    if ($f eq "Chanukah") {
	$s .= format_date_plus_delta($gy, $gm, $gd, 7, $show_year);
    } elsif ($f eq "Purim" || $f eq "Tish'a B'Av") {
	$s .= format_single_day_html($gy, $gm, $gd, $show_year);
    } elsif (begins_at_dawn($f)) {
	$s .= format_single_day($gy, $gm, $gd, $show_year);
    } elsif ($evt->[$Hebcal::EVT_IDX_YOMTOV] == 0) {
	$s .= format_single_day_html($gy, $gm, $gd, $show_year);
    } else {
	$s .= "<b>"; # begin yomtov
	if ($f eq "Rosh Hashana" || $f eq "Shavuot") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
	} elsif ($f eq "Yom Kippur" || $f eq "Shmini Atzeret" || $f eq "Simchat Torah") {
	    $s .= format_single_day_html($gy, $gm, $gd, $show_year);
	} elsif ($f eq "Sukkot") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
	    $s .= "</b><br>";
	    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 2);
	    $s .= format_date_plus_delta($gy2, $gm2, $gd2, 4, $show_year);
	} elsif ($f eq "Pesach") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
	    $s .= "</b><br>";
	    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 2);
	    $s .= format_date_plus_delta($gy2, $gm2, $gd2, 3, $show_year);
	    $s .= "<br><b>";
	    my($gy3,$gm3,$gd3) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 6);
	    $s .= format_date_plus_delta($gy3, $gm3, $gd3, 1, $show_year);
	}
	$s .= "</b>" unless $f eq "Sukkot";
    }
    return $s;
}

sub table_index {
    my($festivals,$table_id,@holidays) = @_;
    print OUT3 <<EOHTML;
<table id="$table_id">
<col style="width:180px"><col><col style="background-color:#FFFFCC"><col><col><col><col>
<tbody>
EOHTML
;

    print OUT3 "<tr><th>Holiday</th>";
    foreach my $i (0 .. $NUM_YEARS) {
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
	foreach my $i (0 .. $NUM_YEARS) {
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
<table id="$table_id">
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
    my($page_title,$do_multi_year) = @_;

    my $str = <<EOHTML;
<div id="container" class="single-attachment">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">$page_title</h1>
<div class="entry-meta">
<span class="meta-prep">Last updated on</span> <span class="entry-date">$MTIME_FORMATTED</span>
</div><!-- .entry-meta -->
<div class="entry-content">
<p>All holidays begin at sundown on the evening before the date
specified in the tables below. For example, if the dates for Rosh
Hashana were listed as <b>Sep 19-20</b>, then the holiday begins at
sundown on <b>Sep 18</b> and ends at sundown on <b>Sep 20</b>.
Dates in <b>bold</b> are <em>yom tov</em>, so they have similar
obligations and restrictions to Shabbat in the sense that normal "work"
is forbidden.</p>
<p>
EOHTML
;

    if ($do_multi_year) {
      $str .= <<EOHTML;
The tables of holidays below include the current year and 4 years
into the future for the Diaspora.
EOHTML
;
    }

    $str .= <<EOHTML;
<a href="/ical/">Download</a> to your favorite desktop, mobile or
web-based calendar, or <a href="/hebcal/">make a custom calendar</a>
to select a different year or for advanced options such as
candle-lighting times and Torah readings.</p>
EOHTML
;

    return $str;
}

sub write_index_page
{
    my($festivals) = @_;

    my $fn = "$outdir/index.html";
    open(OUT3, ">$fn.$$") || die "$fn.$$: $!\n";

    my $xtra_head = <<EOHTML;
<style type="text/css">
#hebcal-major-holidays tr td, #hebcal-major-holidays tr th,
#hebcal-minor-holidays tr td, #hebcal-minor-holidays tr th,
#hebcal-rosh-chodesh tr td, #hebcal-rosh-chodesh tr th {
  padding: 4px;
}
#hebcal-major-holidays td.date-obs,
#hebcal-minor-holidays td.date-obs,
#hebcal-rosh-chodesh td.date-obs {
  font-size: 12px;
  line-height:16px;
}
</style>
EOHTML
;

    my $page_title = "Jewish Holidays";
    print OUT3 Hebcal::html_header($page_title,
				   "/holidays/",
				   "single single-post",
				   $xtra_head);

    print OUT3 get_index_body_preamble($page_title, 1);

    my $major = "Rosh Hashana,Yom Kippur,Sukkot,Shmini Atzeret,Simchat Torah,Chanukah,Purim,Pesach,Shavuot,Tish'a B'Av";
    my @major = split(/,/, $major);
    print OUT3 "<h3>Major holidays</h3>\n";
    table_index($festivals, "hebcal-major-holidays", @major);

    my %major = map { $_ => 1 } @major;
    my @minor;
    my @rosh_chodesh;
    foreach my $f (@FESTIVALS) {
	if ($f =~ /^Rosh Chodesh/) {
	    push(@rosh_chodesh, $f);
	} elsif (! defined $major{$f}) {
	    push(@minor, $f);
	}
    }

    print OUT3 "<h3>Minor holidays, special Shabbatot, public fasts</h3>\n";
    table_index($festivals, "hebcal-minor-holidays", @minor);

    print OUT3 "<h3>Rosh Chodesh</h3>\n";
    table_index($festivals, "hebcal-rosh-chodesh", @rosh_chodesh);


    my $body_divs_end = <<EOHTML;
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOHTML
;

    print OUT3 $body_divs_end;
    print OUT3 Hebcal::html_footer_new(undef, $REVISION);

    close(OUT3);
    rename("$fn.$$", $fn) || die "$fn: $!\n";

    # SEO - one page per year
    foreach my $i (0 .. $NUM_YEARS) {
	my $heb_year = $HEB_YR + $i - 1;
	my $greg_yr1 = $heb_year - 3761;
	my $greg_yr2 = $greg_yr1 + 1;

	my $slug = "$greg_yr1-$greg_yr2";
	$fn = "$outdir/$slug";
	open(OUT4, ">$fn.$$") || die "$fn.$$: $!\n";

	$page_title = "Jewish Holidays $slug";

	print OUT4 Hebcal::html_header($page_title,
				       "/holidays/$slug",
				       "single single-post",
				       $xtra_head);

	print OUT4 get_index_body_preamble($page_title, 0);

	print OUT4 "<p>";
	foreach my $j (0 .. $NUM_YEARS) {
	    my $other_yr = $HEB_YR + $j - 1;
	    my $other_greg_yr1 = $other_yr - 3761;
	    my $other_greg_yr2 = $other_greg_yr1 + 1;
	    my $other_slug = "$other_greg_yr1-$other_greg_yr2";

	    print OUT4 qq{<a title="Hebrew Year $other_yr" href="$other_slug">} unless $i == $j;
	    print OUT4 $other_slug;
	    print OUT4 "</a>" unless $i == $j;
	    print OUT4 " |\n" unless $j == $NUM_YEARS;
	}
	print OUT4 "</p>\n";

	print OUT4 "<h3>Major holidays</h3>\n";
	table_one_year_only($festivals, "hebcal-major-holidays", $i, @major);

	print OUT4 "<h3>Minor holidays, special Shabbatot, public fasts</h3>\n";
	table_one_year_only($festivals, "hebcal-minor-holidays", $i, @minor);

	print OUT4 "<h3>Rosh Chodesh</h3>\n";
	table_one_year_only($festivals, "hebcal-rosh-chodesh", $i, @rosh_chodesh);

	print OUT4 $body_divs_end;
	print OUT4 Hebcal::html_footer_new(undef, $REVISION);

	close(OUT4);
	rename("$fn.$$", $fn) || die "$fn: $!\n";
    }
}

sub write_festival_part
{
    my($festivals,$f) = @_;

    my $slug = Hebcal::make_anchor($f);
    $slug =~ s/\.html$//;

    my $torah;
    my $maftir;
    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	my $aliyot = $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'};
	if (ref($aliyot) eq 'HASH') {
	    $aliyot = [ $aliyot ];
	}

	my $book;
	my $begin;
	my $end;
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
	    if ($maftir) {
		$torah .= " &amp; $maftir";
	    }
	} elsif ($maftir) {
	    $torah = "$maftir (special maftir)";
	}
    }

    if ($torah) {
	my $torah_href = $festivals->{'festival'}->{$f}->{'kriyah'}->{'torah'}->{'href'};

	print OUT2 qq{\n<h3 id="$slug-torah">Torah Portion: };
	print OUT2 qq{<a class="outbound" href="$torah_href"\ntitle="Translation from JPS Tanakh">}
	    if ($torah_href);
	print OUT2 $torah;
	print OUT2 qq{</a>}
	    if ($torah_href);
	print OUT2 qq{</h3>\n};

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

	print OUT2 qq{\n<h3 id="$slug-haft">Haftarah: };
	print OUT2 qq{<a class="outbound" href="$haft_href"\ntitle="Translation from JPS Tanakh">}
	    if ($haft_href);
	print OUT2 $haft;
	print OUT2 qq{</a>}
	    if ($haft_href);
	print OUT2 qq{</h3>\n};

	if (! $haft_href) {
	    warn "$f: missing Haft href\n";
	}
    }
}

sub begins_at_dawn {
    my($f) = @_;
    return ($f =~ /^(Tzom|Asara|Ta\'anit) /) ? 1 : 0;
}

sub write_festival_page
{
    my($festivals,$f) = @_;

    my($slug) = Hebcal::make_anchor($f);

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

    print OUT2 Hebcal::html_header($page_title,
				   "/holidays/$slug",
				   "single single-post",
				   "",
				   1);

    my $prev = $PREV{$f};
    my($prev_link) = '';
    my($prev_slug);
    if ($prev)
    {
	$prev_slug = Hebcal::make_anchor($prev);
	my $title = "Previous Holiday";
	$prev_link = <<EOHTML
<div class="nav-previous"><a href="$prev_slug" rel="prev"><span class="meta-nav">&larr;</span> $prev</a></div>
EOHTML
;
    }

    my $next = $NEXT{$f};
    my($next_link) = '';
    my($next_slug);
    if ($next)
    {
	$next_slug = Hebcal::make_anchor($next);
	my $title = "Next Holiday";
	$next_link = <<EOHTML
<div class="nav-next"><a href="$next_slug" rel="next">$next <span class="meta-nav">&rarr;</span></a></div>
EOHTML
;
    }

    my($strassfeld_link) =
	"http://www.amazon.com/o/ASIN/0062720082/hebcal-20";

    print OUT2 <<EOHTML;
<div id="container" class="single-attachment">
<div id="content" role="main">
<div id="nav-above" class="navigation">
$prev_link
$next_link
</div><!-- #nav-above -->
<div class="page type-page hentry">
<h1 class="entry-title">$f / <span
dir="rtl" class="hebrew" lang="he">$hebrew</span></h1>
<div class="entry-meta">
<span class="meta-prep meta-prep-author">Last updated on</span> <span class="entry-date">$MTIME_FORMATTED</span>
</div><!-- .entry-meta -->
<div class="entry-content">
<p>$descr.
EOHTML
;

    if ($about) {
	my $about_href = $about->{'href'};
	if ($about_href) {
	    my $more = '';
	    if ($about_href =~ /^http:\/\/([^\/]+)/i) {
		$more = $1;
		$more =~ s/^www\.//i;
		if ($more eq 'hebcal.com') {
		    $more = '';
		} elsif ($more eq 'jewfaq.org') {
		    $more = " from Judaism 101";
		} elsif ($more eq "en.wikipedia.org") {
		    $more = " from Wikipedia";
		} else {
		    $more = " from $more";
		}
	    }
	    print OUT2 <<EOHTML;
[<a class="outbound" title="Detailed information about holiday"
href="$about_href">more${more}...</a>]</p>
EOHTML
;
	} else {
#    	    warn "$f: missing About href\n";
	}
    }

    if (defined $OBSERVED{$f})
    {
	my $rise_or_set = begins_at_dawn($f) ? "dawn" : "sundown";

	print OUT2 <<EOHTML;
<h3 id="dates">List of Dates</h3>
$f begins at $rise_or_set in the Diaspora on:
<ul>
EOHTML
	;
	foreach my $evt (@{$OBSERVED{$f}}) {
	    next unless defined $evt;
	    my $isotime = sprintf("%04d%02d%02d",
				  $evt->[$Hebcal::EVT_IDX_YEAR],
				  $evt->[$Hebcal::EVT_IDX_MON] + 1,
				  $evt->[$Hebcal::EVT_IDX_MDAY]);
	    my($gy,$gm,$gd);
	    if ($f =~ /^(Tzom|Asara|Ta\'anit) /) {
		($gy,$gm,$gd) =
		    ($evt->[$Hebcal::EVT_IDX_YEAR],
		     $evt->[$Hebcal::EVT_IDX_MON] + 1,
		     $evt->[$Hebcal::EVT_IDX_MDAY]);
	    } else {
		($gy,$gm,$gd) = Date::Calc::Add_Delta_Days
		    ($evt->[$Hebcal::EVT_IDX_YEAR],
		     $evt->[$Hebcal::EVT_IDX_MON] + 1,
		     $evt->[$Hebcal::EVT_IDX_MDAY],
		     -1);
	    }
	    my $dow = Hebcal::get_dow($gy,$gm,$gd);
	    printf OUT2 "<li><a href=\"/hebcal/?v=1;year=%d;month=%d" .
		";nx=on;mf=on;ss=on;nh=on;vis=on;set=off;tag=hol.obs\">%s, %02d %s %04d</a> (%s)\n",
		$gy, $gm,
		$Hebcal::DoW[$dow],
		$gd, $Hebcal::MoY_long{$gm}, $gy, $GREG2HEB{$isotime};
	}
	print OUT2 <<EOHTML;
</ul>
EOHTML
    ;
    }

    if (1)
    {
	my $subf = $SUBFESTIVALS{$f}->[0];
	my $books = $festivals->{"festival"}->{$subf}->{"books"}->{"book"};
	if ($books) {
	    if (ref($books) eq 'HASH') {
		$books = [ $books ];
	    }

	    print OUT2 qq{<h3 id="books">Recommended Books</h3>\n<table border="0" cellpadding="6"><tr>\n};
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

		my $image = new Image::Magick;
		$image->Read($filename);
		my($width,$height) = $image->Get("width", "height");

		my $bktitle = $book->{"content"};
		my $author = $book->{"author"};

		if (!$bktitle)
		{
		    $ua = LWP::UserAgent->new unless $ua;
		    $ua->timeout(10);
		    my %params = (
				  "Service" => "AWSECommerceService",
				  "Operation" => "ItemLookup",
				  "ItemId" => $asin,
				  "ResponseGroup" => "ItemAttributes",
				  "Version" => "2009-01-06",
				  "Timestamp" => strftime("%Y-%m-%dT%TZ", gmtime()),
				  );
		    my $signedRequest = $helper->sign(\%params);
		    my $queryString = $helper->canonicalize($signedRequest);
		    my $url = "http://" . myEndPoint . "/onca/xml?" . $queryString;
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
			&& $rxml->{"Items"}->{"Item"}->{"ASIN"} eq $asin)
		    {
			my $attrs = $rxml->{"Items"}->{"Item"}->{"ItemAttributes"};
			$bktitle = $attrs->{"Title"};
			if (ref($attrs->{"Author"}) eq "ARRAY") {
			    $author = $attrs->{"Author"}->[0];
			} elsif (defined $attrs->{"Author"}) {
			    $author = $attrs->{"Author"};
			}
		    }
		}
		else
		{
		    $author = trim($author) if $author;
		    $bktitle = trim($bktitle);
		    $bktitle =~ s/\n/ /g;
		    $bktitle =~ s/\s+/ /g;
		}

		my $slug2 = $slug;
		$slug2 =~ s/\.html$//;

		my $shorttitle = $bktitle;
		$shorttitle =~ s/\s*:.+//;
		my $link = "http://www.amazon.com/o/ASIN/$asin/hebcal-20";
		print OUT2 qq{<td width="200" align="center" valign="top"><a class="amzn" id="$slug2-$asin-1" title="$bktitle" href="$link"><img src="/i/$img"\nalt="$bktitle"\nwidth="$width" height="$height" border="0" hspace="4" vspace="4"></a><br><a class="amzn" id="$slug2-$asin-2" title="$bktitle" href="$link">$shorttitle</a>};
		print OUT2 qq{<br>by $author} if $author;
		print OUT2 qq{</td>\n};
	    }

	    print OUT2 qq{</tr></table>\n};
	}
    }


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

	    print OUT2 qq{\n<h2 id="$slug">$part};
	    my $part_hebrew = $festivals->{'festival'}->{$part}->{'hebrew'};
	    if ($part_hebrew)
	    {
		$part_hebrew = Hebcal::hebrew_strip_nikkud($part_hebrew);
		print OUT2 qq{\n- <span dir="rtl" class="hebrew"\nlang="he">$part_hebrew</span>};
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
href="$strassfeld_link">The
Jewish Holidays: A Guide &amp; Commentary</a></em>
<dd>Rabbi Michael Strassfeld
<dt><em><a class="amzn" id="jps-tanakh-1"
title="Tanakh: The Holy Scriptures, The New JPS Translation According to the Traditional Hebrew Text" 
href="http://www.amazon.com/o/ASIN/0827602529/hebcal-20">Tanakh:
The Holy Scriptures</a></em>
<dd>Jewish Publication Society
};

    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	print OUT2 qq{<dt><em><a class="outbound"
href="http://www.mechon-mamre.org/p/pt/pt0.htm">Hebrew - English Bible</a></em>
<dd>Mechon Mamre
};
    }

    print OUT2 "</dl>\n";

    if ($prev_link || $next_link)
    {
	print OUT2 <<EOHTML;
<div id="nav-below" class="navigation">
$prev_link
$next_link
</div><!-- #nav-below -->
EOHTML
;
    }

    print OUT2 <<EOHTML;
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
EOHTML
;
    print OUT2 $html_footer;

    close(OUT2);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}

sub print_aliyah
{
    my($aliyah) = @_;

    my($c1,$v1) = ($aliyah->{'begin'} =~ /^([^:]+):([^:]+)$/);
    my($c2,$v2) = ($aliyah->{'end'}   =~ /^([^:]+):([^:]+)$/);
    my($info) = $aliyah->{'book'} . " ";
    if ($c1 eq $c2) {
	$info .= "$c1:$v1-$v2";
    } else {
	$info .= "$c1:$v1-$c2:$v2";
    }

#    my $url = Hebcal::get_mechon_mamre_url($aliyah->{'book'}, $c1, $v1);
#    my $title = "Hebrew-English bible text";
    my $url = Hebcal::get_bible_ort_org_url($aliyah->{'book'}, $c1, $v1, $aliyah->{'parsha'});
    $url =~ s/&/&amp;/g;
    my $title = "Hebrew-English bible text from ORT";
    $info = qq{<a class="outbound" title="$title"\nhref="$url">$info</a>};

    my($label) = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    print OUT2 qq{$label: $info};

    if ($aliyah->{'numverses'}) {
	print OUT2 "\n<small>(",
	$aliyah->{'numverses'}, "&nbsp;p'sukim)</small>";
    }

    print OUT2 qq{<br>\n};
}

sub html_footer
{
    my $str = Hebcal::html_footer_new(undef, $REVISION, 1);

# remove the AMZN link enhancer for now if we're not going to get associate fees
# <script type="text/javascript" src="http://www.assoc-amazon.com/s/link-enhancer?tag=hebcal-20&o=1"></script>

    $str .= <<EOHTML;
</body>
</html>
EOHTML
;

    return $str;
}

sub holidays_observed
{
    my($current) = @_;

    my @years;
    foreach my $i (0 .. $NUM_YEARS)
    {
	my $yr = $HEB_YR + $i - 1;
	my @ev = Hebcal::invoke_hebcal("./hebcal -H $yr", '', 0);
	$years[$i] = \@ev;
    }

    for (my $yr = 0; $yr <= $NUM_YEARS; $yr++)
    {
	my @events = @{$years[$yr]};
	for (my $i = 0; $i < @events; $i++)
	{
	    my $subj = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	    next if $subj =~ /^Erev /;

	    # Since Chanukah doesn't have an Erev, skip a day
	    next if $subj =~ /^Chanukah: 1 Candle$/;

	    my $subj_copy = $subj;
	    $subj_copy =~ s/ \d{4}$//;
	    $subj_copy =~ s/ \(CH\'\'M\)$//;
	    $subj_copy =~ s/ \(Hoshana Raba\)$//;
	    $subj_copy =~ s/ [IV]+$//;
	    $subj_copy =~ s/: \d Candles?$//;
	    $subj_copy =~ s/: 8th Day$//;

	    $current->{$subj_copy}->[$yr] = $events[$i]
		unless (defined $current->{$subj_copy} &&
			defined $current->{$subj_copy}->[$yr]);
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
