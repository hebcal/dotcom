#!/usr/bin/perl -w

########################################################################
#
# Generates the festival pages for http://www.hebcal.com/holidays/
#
# Copyright (c) 2018 Michael J. Radwin.
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
use HebcalHtml ();
use HebcalConst;
use Date::Calc;
use RequestSignatureHelper;
use Config::Tiny;
use DBI;
use Carp;
use Log::Log4perl qw(:easy);
use strict;

my $eval_use_Image_Magick = 0;
my @DOW_TINY = qw(x M Tu W Th F Sa Su);

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

# Just log to STDERR
my $loglevel = $opts{"v"} ? $INFO : $WARN;
Log::Log4perl->easy_init($loglevel);

my($this_year,$this_mon,$this_day) = Date::Calc::Today();

my($festival_in) = shift;
my($outdir) = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

INFO("Reading $festival_in...");
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

my $HEB_YR;
if ($opts{'H'}) {
    $HEB_YR = $opts{'H'};
} else {
    my($yy,$mm,$dd) = Date::Calc::Today();
    $HEB_YR = Hebcal::get_default_hebrew_year($yy,$mm,$dd);
}

my $NUM_YEARS = 9;
my $NUM_YEARS_MAIN_INDEX = 5;
my $FIRST_GREG_YR = $HEB_YR - 3761;
my $meta_greg_yr1 = $FIRST_GREG_YR - 1;
my $meta_greg_yr2 = $meta_greg_yr1 + $NUM_YEARS + 1;

my @EVENTS_BY_HEBYEAR;
my @EVENTS_BY_GREGYEAR;
INFO("Observed holidays...");
holidays_observed();

my %seph2ashk = reverse %Hebcal::ashk2seph;

# Set up the amazon request signing helper
my $helper;
my $AWS_HOST;
my $ua;
my $Config = Config::Tiny->read($Hebcal::CONFIG_INI_PATH);
my $DO_AMAZON = 1;
if ($Config && $Config->{_}->{"hebcal.aws.product-api.host"}) {
    $AWS_HOST = $Config->{_}->{"hebcal.aws.product-api.host"};
    $helper = new RequestSignatureHelper (
    +RequestSignatureHelper::kAWSAccessKeyId => $Config->{_}->{"hebcal.aws.product-api.id"},
    +RequestSignatureHelper::kAWSSecretKey => $Config->{_}->{"hebcal.aws.product-api.secret"},
    +RequestSignatureHelper::kEndPoint => $AWS_HOST,
					 );
} else {
    $DO_AMAZON = 0;
}

# write_wordpress_export();

foreach my $f (@FESTIVALS)
{
    INFO("   $f");
    write_festival_page($fxml,$f);
}

my $pagead_300x250=<<EOHTML;
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
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

my $yomtov_html=<<EOHTML;
<p>Holidays begin at sundown on the evening before the date specified.</p>
<p>Dates in <strong>bold</strong> are <em>yom tov</em>, so they have similar
obligations and restrictions to Shabbat in the sense that normal "work"
is forbidden.</p>
EOHTML
;

INFO("Index page...");
write_index_page($fxml);

exit(0);

sub write_wordpress_export {
    my $fn = "$outdir/hebcal.wordpress.xml";
    open(OUT5, ">$fn.$$") || die "$fn.$$: $!\n";
    print OUT5 <<EOXML;
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0"
    xmlns:excerpt="http://wordpress.org/export/1.2/excerpt/"
    xmlns:content="http://purl.org/rss/1.0/modules/content/"
    xmlns:wfw="http://wellformedweb.org/CommentAPI/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:wp="http://wordpress.org/export/1.2/"
>
<channel>
    <title>Hebcal</title>
    <link>http://www.hebcal.com/home</link>
    <description>Jewish Calendar</description>
    <pubDate>Mon, 24 Mar 2014 18:39:07 +0000</pubDate>
    <language>en-US</language>
    <wp:wxr_version>1.2</wp:wxr_version>
    <wp:base_site_url>http://www.hebcal.com/home</wp:base_site_url>
    <wp:base_blog_url>http://www.hebcal.com/home</wp:base_blog_url>
    <wp:author><wp:author_id>1</wp:author_id>
    <wp:author_login>mradwin</wp:author_login>
    <wp:author_email>michael\@radwin.org</wp:author_email>
    <wp:author_display_name><![CDATA[mradwin]]></wp:author_display_name>
    <wp:author_first_name><![CDATA[]]></wp:author_first_name>
    <wp:author_last_name><![CDATA[]]></wp:author_last_name></wp:author>
EOXML
;

    my $post_id = 1000;
    foreach my $f (@FESTIVALS) {
        my $slug = Hebcal::make_anchor($f);
        my $about = get_var($fxml, $f, 'about');
        my $descr;
        if ($about) {
            $descr = trim($about->{'content'});
        }
        my $wikipedia_descr;
        my $wikipedia = get_var($fxml, $f, 'wikipedia', 1);
        if ($wikipedia) {
            $wikipedia_descr = trim($wikipedia->{'content'});
        }
        my $long_descr = $wikipedia_descr ? $wikipedia_descr : $descr;
        $post_id++;
        print OUT5 <<EOXML;
            <item>
                <title>$f</title>
        <link>/holidays/$slug</link>
        <pubDate>Mon, 24 Mar 2014 18:36:03 +0000</pubDate>
        <dc:creator><![CDATA[mradwin]]></dc:creator>
        <guid isPermaLink="false">http://www.hebcal.com/home/?page_id=$post_id</guid>
        <description></description>
        <content:encoded><![CDATA[$long_descr]]></content:encoded>
        <excerpt:encoded><![CDATA[]]></excerpt:encoded>
        <wp:post_id>$post_id</wp:post_id>
        <wp:post_date>2014-03-24 11:36:03</wp:post_date>
        <wp:post_date_gmt>2014-03-24 18:36:03</wp:post_date_gmt>
        <wp:comment_status>open</wp:comment_status>
        <wp:ping_status>open</wp:ping_status>
        <wp:post_name>$slug</wp:post_name>
        <wp:status>publish</wp:status>
        <wp:post_parent>112</wp:post_parent>
        <wp:menu_order>0</wp:menu_order>
        <wp:post_type>page</wp:post_type>
        <wp:post_password></wp:post_password>
        <wp:is_sticky>0</wp:is_sticky>
        <wp:postmeta>
            <wp:meta_key>_edit_last</wp:meta_key>
            <wp:meta_value><![CDATA[1]]></wp:meta_value>
        </wp:postmeta>
        <wp:postmeta>
            <wp:meta_key>_wp_page_template</wp:meta_key>
            <wp:meta_value><![CDATA[default]]></wp:meta_value>
        </wp:postmeta>
        <wp:postmeta>
            <wp:meta_key>_links_to</wp:meta_key>
            <wp:meta_value><![CDATA[/holidays/$slug]]></wp:meta_value>
        </wp:postmeta>
    </item>
EOXML
;
    }
    print OUT5 qq{</channel>\n</rss>\n};
    close(OUT5);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}

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
	WARN("ERROR: no $name for $f") unless $nowarn;
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
    my $html5time = sprintf("%04d-%02d-%02d", $gy, $gm, $gd);
    return "<time itemprop=\"startDate\" content=\"$html5time\" datetime=\"$html5time\" title=\"begins at sundown on "
        . format_single_day($gy0,$gm0,$gd0,0)
        . "\">" . format_single_day($gy,$gm,$gd,$show_year) . "</time>";
}

sub format_date_range {
    my($gy1,$gm1,$gd1,$gy2,$gm2,$gd2,$show_year) = @_;
    my $str = format_single_day_html($gy1,$gm1,$gd1,0) . "-";
    my $html5time = sprintf("%04d-%02d-%02d", $gy2, $gm2, $gd2);
    $str .= qq{<time datetime="$html5time">};
    if ($gm1 == $gm2) {
        $str .= $gd2;
    } else {
        $str .= format_single_day($gy2,$gm2,$gd2,0);
    }
    $str .= qq{</time>};
    return $show_year ? ($str . ", " . $gy2) : $str;
}

sub format_date_plus_delta {
    my($gy1,$gm1,$gd1,$delta,$show_year) = @_;
    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy1,$gm1,$gd1,$delta);
    return format_date_range($gy1,$gm1,$gd1,$gy2,$gm2,$gd2,$show_year);
}

sub short_day_of_week {
    my($gy1,$gm1,$gd1,$delta) = @_;
    my $dow = Date::Calc::Day_of_Week($gy1,$gm1,$gd1);
    my $s = $DOW_TINY[$dow];
    if ($delta) {
        my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy1,$gm1,$gd1,$delta);
        my $dow2 = Date::Calc::Day_of_Week($gy2,$gm2,$gd2);
        $s .= "&#8209;" . $DOW_TINY[$dow2];
    }
    return qq{ <small class="text-muted">$s</small>};
}

sub table_cell_observed {
    my($f,$evt,$show_year) = @_;
    my($gy,$gm,$gd) = Hebcal::event_ymd($evt);
    my $s = "";
    if ($f eq "Chanukah") {
	$s .= format_date_plus_delta($gy, $gm, $gd, 7, $show_year);
        $s .= short_day_of_week($gy, $gm, $gd, 7);
    } elsif ($f eq "Purim" || $f eq "Tish'a B'Av") {
	$s .= format_single_day_html($gy, $gm, $gd, $show_year);
        $s .= short_day_of_week($gy, $gm, $gd, 0);
    } elsif (begins_at_dawn($f) || $f eq "Leil Selichot") {
	$s .= format_single_day($gy, $gm, $gd, $show_year);
        $s .= short_day_of_week($gy, $gm, $gd, 0);
    } elsif ($evt->{yomtov} == 0) {
	$s .= format_single_day_html($gy, $gm, $gd, $show_year);
        $s .= short_day_of_week($gy, $gm, $gd, 0);
    } else {
	$s .= "<strong>"; # begin yomtov
	if ($f eq "Rosh Hashana" || $f eq "Shavuot") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
            $s .= short_day_of_week($gy, $gm, $gd, 1);
	} elsif ($f eq "Yom Kippur" || $f eq "Shmini Atzeret" || $f eq "Simchat Torah") {
	    $s .= format_single_day_html($gy, $gm, $gd, $show_year);
            $s .= short_day_of_week($gy, $gm, $gd, 0);
	} elsif ($f eq "Sukkot") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
            $s .= short_day_of_week($gy, $gm, $gd, 1);
	    $s .= "</strong><br>";
	    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 2);
	    $s .= format_date_plus_delta($gy2, $gm2, $gd2, 4, $show_year);
            $s .= short_day_of_week($gy2, $gm2, $gd2, 4);
	} elsif ($f eq "Pesach") {
	    $s .= format_date_plus_delta($gy, $gm, $gd, 1, $show_year);
            $s .= short_day_of_week($gy, $gm, $gd, 1);
	    $s .= "</strong><br>";
	    my($gy2,$gm2,$gd2) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 2);
	    $s .= format_date_plus_delta($gy2, $gm2, $gd2, 3, $show_year);
            $s .= short_day_of_week($gy2, $gm2, $gd2, 3);
	    $s .= "<br><strong>";
	    my($gy3,$gm3,$gd3) = Date::Calc::Add_Delta_Days($gy, $gm, $gd, 6);
	    $s .= format_date_plus_delta($gy3, $gm3, $gd3, 1, $show_year);
            $s .= short_day_of_week($gy3, $gm3, $gd3, 1);
	}
	$s .= "</strong>" unless $f eq "Sukkot";
    }
    return $s;
}

sub table_index {
    my($festivals,$table_id,@holidays) = @_;
    print OUT3 <<EOHTML;
<div class="table-responsive">
<table class="table table-condensed">
<col style="width:180px"><col><col style="background-color:#FFFFCC"><col><col><col><col>
<tbody>
EOHTML
;

    print OUT3 "<tr><th>Holiday</th>";
    foreach my $i (0 .. $NUM_YEARS_MAIN_INDEX) {
	my $yr = $HEB_YR + $i - 1;
	my $greg_yr1 = $yr - 3761;
	my $greg_yr2 = $greg_yr1 + 1;
	print OUT3 "<th><a href=\"$greg_yr1-$greg_yr2\">$yr<br>($greg_yr1&#8209;$greg_yr2)</a></th>";
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
	    if (defined $EVENTS_BY_HEBYEAR[$i]->{$f}) {
		my $evt = $EVENTS_BY_HEBYEAR[$i]->{$f};
		print OUT3 table_cell_observed($f, $evt, 0);
	    }
	    print OUT3 "</td>\n";
	}
	print OUT3 "</tr>\n";
    }

    print OUT3 <<EOHTML;
</tbody>
</table>
</div><!-- .table-responsive -->
EOHTML
;
}

sub table_row_one_year_only {
    my($fh,$festivals,$f,$evt,$show_year,$evt2) = @_;
    my $descr;
    my $about = get_var($festivals, $f, 'about');
    if ($about) {
        $descr = trim($about->{'content'});
    }
    die "no descr for $f" unless $descr;

    my $slug = Hebcal::make_anchor($f);
    my $short_descr = $descr;
    $short_descr =~ s/\..*//;

    print $fh qq{<tr itemscope itemtype="http://schema.org/Event"><td><a href="$slug"><span itemprop="name">$f</span></a></td>\n};
    print $fh "<td>";
    print $fh table_cell_observed($f, $evt, $show_year)
        if defined $evt;
    if (defined $evt2) {
        print $fh "<br>";
        print $fh table_cell_observed($f, $evt2, $show_year);
    }
    print $fh qq{</td>\n<td class="d-none d-sm-block">$short_descr</td>\n};
    print $fh "</tr>\n";
}

sub table_header_one_year_only {
    my($fh,$table_id,$show_year) = @_;
    my $col2width = $show_year ? 180 : 156;
    print $fh <<EOHTML;
<table class="table table-striped table-condensed">
<col style="width:180px"><col style="width:${col2width}px"><col class="d-none d-sm-block">
<tbody>
EOHTML
;

    print $fh "<tr><th>Holiday</th>";
    print $fh "<th>Dates</th>";
    print $fh qq{<th class="d-none d-sm-block">Description</th>};
    print $fh "</tr>\n";
}

sub table_footer_one_year_only {
    my($fh,$table_id) = @_;
    print $fh "</tbody>\n</table>\n";
}

sub rosh_hashana_ymd {
    my($year_type,$current_year) = @_;
    my $evt;
    if ($year_type eq "H") {
        my $i = $current_year - $HEB_YR + 1;
        $evt = $EVENTS_BY_HEBYEAR[$i]->{"Rosh Hashana"};
    } else {
        my $i = $current_year - $FIRST_GREG_YR;
        $evt = $EVENTS_BY_GREGYEAR[$i]->{"Rosh Hashana"}->[0];
    }
    return Hebcal::event_ymd($evt);
}

sub get_index_body_preamble {
    my($page_title,$do_multi_year,$year_type,$current_year,$div_class) = @_;

    my $when = "";
    my $rh_erev = "Sep 18";
    my $rh_range = "Sep 19-20";
    my $rh_end = "Sep 20";
    if ($current_year) {
        $when = $year_type eq "H" ?
            " for Hebrew Year $current_year" : " for $current_year";

        my($rh1y,$rh1m,$rh1d) = rosh_hashana_ymd($year_type,$current_year);
        my($rh2y,$rh2m,$rh2d) = Date::Calc::Add_Delta_Days($rh1y,$rh1m,$rh1d,1);
        my($rh0y,$rh0m,$rh0d) = Date::Calc::Add_Delta_Days($rh1y,$rh1m,$rh1d,-1);

        $rh_erev = format_single_day($rh0y, $rh0m, $rh0d, 0);
        $rh_range = format_date_plus_delta($rh1y, $rh1m, $rh1d, 1, 0);
        $rh_end = format_single_day($rh2y, $rh2m, $rh2d, 0);
    }
    my $str = <<EOHTML;
<div class="$div_class">
<h1>$page_title</h1>
<p class="lead d-print-none">Dates of major and minor Jewish holidays$when. Each
holiday page includes a brief overview of special observances and
customs, and any special Torah readings.</p>
<p>All holidays begin at sundown on the evening before the date
specified in the tables below. For example, if the dates for Rosh
Hashana were listed as <strong>$rh_range</strong>, then the holiday begins at
sundown on <strong>$rh_erev</strong> and ends at nightfall on <strong>$rh_end</strong>.</p>
EOHTML
;

    my $custom_link =
        $current_year ? "/hebcal/?v=0&amp;year=$current_year&amp;yt=$year_type" : "/hebcal/";
    my $pdf_heb_year = $current_year || $HEB_YR;

    $str .= <<EOHTML;
<div class="btn-toolbar d-print-none">
 <div class="btn-group mr-1" role="group">
  <a class="btn btn-secondary btn-sm download" title="PDF one page per month, in landscape" id="pdf-${pdf_heb_year}" href="hebcal-${pdf_heb_year}.pdf"><span class="glyphicons glyphicons-print"></span> Print</a>
 </div>
 <div class="btn-group mr-1" role="group">
  <a class="btn btn-secondary btn-sm" title="export to Outlook, iPhone, Google and more" href="/ical/"><span class="glyphicons glyphicons-download-alt"></span> Download</a>
 </div>
 <div class="btn-group mr-1" role="group">
  <a class="btn btn-secondary btn-sm" title="Candle lighting times for Shabbat and holidays, Ashkenazi transliterations, Israeli holiday schedule, etc." href="$custom_link"><span class="glyphicons glyphicons-pencil"></span> Customize</a>
 </div>
</div><!-- .btn-toolbar -->
EOHTML
;

    return $str;
}

sub get_heading_and_table_id {
    my($section) = @_;
    my $heading = $section->[1];
    my $table_id = lc($heading);
    $table_id =~ s/\s+/-/g;
    return ($heading,$table_id);
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

    my $modern = "Yom HaShoah,Yom HaZikaron,Yom HaAtzma'ut,Yom Yerushalayim,Yom HaAliyah,Sigd";
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
        my($heading,$table_id) = get_heading_and_table_id($section);
        push(@table_ids, $table_id);
    }

    my $page_title = "Jewish Holidays";
    print OUT3 HebcalHtml::header_bootstrap3(
        $page_title, "/holidays/", "ignored",  $meta);

    print OUT3 qq{<div class="row">\n};
    print OUT3 get_index_body_preamble($page_title, 1, undef, undef, "col-sm-8");
    print OUT3 <<EOHTML;
</div><!-- .col-sm-8 -->
<div class="col-sm-4 d-print-none">
<h5>Advertisement</h5>
$pagead_300x250
</div><!-- .col-sm-4 -->
</div><!-- .row -->
EOHTML
;
    print OUT3 qq{<div class="row">\n};
    print OUT3 qq{<div class="col-sm-12">\n};

    foreach my $section (@sections) {
        my($heading,$table_id) = get_heading_and_table_id($section);
        print OUT3 qq{<div id="$table_id">\n};
        print OUT3 "<h3>", $heading, "</h3>\n";
        print OUT3 $yomtov_html if $heading eq "Major holidays";
        table_index($festivals, $table_id, @{$section->[0]});
        print OUT3 qq{</div><!-- #$table_id -->\n};
    }

    print OUT3 qq{</div><!-- .col-sm-12 -->\n};
    print OUT3 qq{</div><!-- .row -->\n};
    print OUT3 HebcalHtml::footer_bootstrap3(undef, undef);

    close(OUT3);
    rename("$fn.$$", $fn) || die "$fn: $!\n";

    # SEO - one page per year
    foreach my $i (0 .. $NUM_YEARS) {
        write_hebrew_year_index_page($i,
             $festivals,
             \@sections);
        write_greg_year_index_page($i, $festivals, \@sections);
    }
}

sub pagination_greg_url {
    my($year) = @_;
    return "/hebcal/?year=$year&amp;v=1&amp;maj=on&amp;min=on&amp;nx=on&amp;mf=on&amp;ss=on&amp;mod=on";
}

sub pagination_greg {
    my($current_year) = @_;

    my $s = qq{<nav class="d-print-none"><ul class="pagination pagination-sm" style="margin: 12px 0 0 0">\n};

    my $prev_year = $FIRST_GREG_YR - 1;
    $s .= qq{<li class="page-item"><a class="page-link" title="$prev_year" aria-label="Previous" href="} . pagination_greg_url($prev_year) . qq{"><span aria-hidden="true">&laquo;</span></a></li>\n};

    foreach my $j (0 .. $NUM_YEARS) {
        my $other_yr = $FIRST_GREG_YR + $j;
        if ($current_year == $j) {
            $s .= qq{<li class="page-item active">};
        } else {
            $s .= qq{<li class="page-item">};
        }
        $s .= qq{<a class="page-link" href="$other_yr">$other_yr</a></li>\n};
    }

    my $next_year = $FIRST_GREG_YR + $NUM_YEARS + 1;
    $s .= qq{<li class="page-item"><a class="page-link" title="$next_year" aria-label="Next" href="} . pagination_greg_url($next_year) . qq{"><span aria-hidden="true">&raquo;</span></a></li>\n};

    $s .= qq{</ul></nav>\n};

    return $s;
}

sub write_greg_year_index_page {
    my($i,$festivals,$sections) = @_;

    my $greg_year = $FIRST_GREG_YR + $i;

    INFO("    $greg_year");
    my $fn = "$outdir/$greg_year";
    open(my $fh, ">$fn.$$") || die "$fn.$$: $!\n";

    my $page_title = "Jewish Holidays $greg_year";

    my $meta = <<EOHTML;
<meta name="description" content="Dates of major and minor Jewish holidays for $greg_year, observances and customs, holiday Torah readings.">
EOHTML
;

    print $fh HebcalHtml::header_bootstrap3($page_title,
                         "/holidays/$greg_year",
                         "single single-post",
                         $meta,
                         0);

    print $fh qq{<div class="row">\n};
    print $fh get_index_body_preamble($page_title, 0, "G", $greg_year, "col-sm-8");
    print $fh <<EOHTML;
</div><!-- .col-sm-8 -->
<div class="col-sm-4 d-print-none">
<h5>Advertisement</h5>
$pagead_300x250
</div><!-- .col-sm-4 -->
</div><!-- .row -->
EOHTML
;

    print $fh qq{<div class="row">\n};
    print $fh qq{<div class="col-sm-12">\n};

    print $fh pagination_greg($i);

    foreach my $section (@{$sections}) {
        my($heading,$table_id) = get_heading_and_table_id($section);
        print $fh qq{<div id="$table_id">\n};
        print $fh "<h3>", $heading, "</h3>\n";
        print $fh $yomtov_html if $heading eq "Major holidays";
        table_header_one_year_only($fh, $table_id, 0);
        my @events;
        my $asara_btevet2;
        foreach my $f (@{$section->[0]}) {
            my $evts = $EVENTS_BY_GREGYEAR[$i]->{$f};
            if (defined $evts) {
                push(@events, $evts->[0]);
                if ($f eq "Asara B'Tevet" && defined $evts->[1]) {
                    $asara_btevet2 = $evts->[1];
                }
            }
        }
        @events = sort { Hebcal::event_to_time($a) <=> Hebcal::event_to_time($b) } @events;
        foreach my $evt (@events) {
            my $f = $evt->{subj};
            my $evt2 = $f eq "Asara B'Tevet" ? $asara_btevet2 : undef;
            table_row_one_year_only($fh,$festivals,$f,$evt,0,$evt2);
        }
        table_footer_one_year_only($fh, $table_id);
        print $fh qq{</div><!-- #$table_id -->\n};
    }

    print $fh qq{</div><!-- .col-sm-12 -->\n};
    print $fh qq{</div><!-- .row -->\n};

    print $fh HebcalHtml::footer_bootstrap3(undef, undef);

    close($fh);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}

sub write_hebrew_year_index_page {
    my($i,$festivals,$sections) = @_;

    my $heb_year = $HEB_YR + $i - 1;
    my $greg_yr1 = $heb_year - 3761;
    my $greg_yr2 = $greg_yr1 + 1;

    INFO("    $heb_year");
    my $slug = "$greg_yr1-$greg_yr2";
    my $fn = "$outdir/$slug";
    open(my $fh, ">$fn.$$") || die "$fn.$$: $!\n";

    my $page_title = "Jewish Holidays $slug";

    my $meta = <<EOHTML;
<meta name="description" content="Dates of major and minor Jewish holidays for years $greg_yr1-$greg_yr2 (Hebrew year $heb_year), observances and customs, holiday Torah readings.">
EOHTML
;

    print $fh HebcalHtml::header_bootstrap3($page_title,
        "/holidays/$slug",
        "single single-post",
        $meta,
        0);

    print $fh qq{<div class="row">\n};
    print $fh get_index_body_preamble($page_title, 0, "H", $heb_year, "col-sm-8");
    print $fh <<EOHTML;
</div><!-- .col-sm-8 -->
<div class="col-sm-4 d-print-none">
<h5>Advertisement</h5>
$pagead_300x250
</div><!-- .col-sm-4 -->
</div><!-- .row -->
EOHTML
;
    print $fh qq{<div class="row">\n};
    print $fh qq{<div class="col-sm-12">\n};

    print $fh pagination_greg(-1);

    foreach my $section (@{$sections}) {
        my($heading,$table_id) = get_heading_and_table_id($section);
        print $fh qq{<div id="$table_id">\n};
        print $fh "<h3>", $heading, "</h3>\n";
        print $fh $yomtov_html if $heading eq "Major holidays";
        table_header_one_year_only($fh, $table_id, 1);
        foreach my $f (@{$section->[0]}) {
            table_row_one_year_only($fh,$festivals,$f,$EVENTS_BY_HEBYEAR[$i]->{$f},1);
        }
        table_footer_one_year_only($fh, $table_id);
        print $fh qq{</div><!-- #$table_id -->\n};
    }

    print $fh qq{</div><!-- .col-sm-12 -->\n};
    print $fh qq{</div><!-- .row -->\n};
    print $fh HebcalHtml::footer_bootstrap3(undef, undef);

    close($fh);
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
        my $anum = $aliyah->{'num'};
        if ($anum eq 'M') {
	    $maftir = sprintf("%s %s - %s",
			      $aliyah->{'book'},
			      $aliyah->{'begin'},
			      $aliyah->{'end'});
        } elsif ($anum =~ /^\d+$/) {
            if ($anum >= 7 || ($book && $aliyah->{'book'} eq $book)) {
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
	print OUT2 qq{<a class="outbound" href="$torah_href"\ntitle="English translation from JPS Tanakh">}
	    if ($torah_href);
	print OUT2 $torah;
	print OUT2 qq{</a>}
	    if ($torah_href);
	print OUT2 qq{</h4>\n};

	if (! $torah_href) {
	    WARN("$f: missing Torah href");
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
	print OUT2 qq{<a class="outbound" href="$haft_href"\ntitle="English translation from JPS Tanakh">}
	    if ($haft_href);
	print OUT2 $haft;
	print OUT2 qq{</a>}
	    if ($haft_href);
	print OUT2 qq{</h4>\n};

	if (! $haft_href) {
	    WARN("$f: missing Haft href");
	}
    }
}

sub day_event_observed {
    my($f,$evt) = @_;
    my($gy,$gm,$gd) = Hebcal::event_ymd($evt);
    if (!begins_at_dawn($f) && $f ne "Leil Selichot") {
	($gy,$gm,$gd) = Date::Calc::Add_Delta_Days($gy,$gm,$gd,-1);
    }
    my $dow = Hebcal::get_dow($gy,$gm,$gd);
    return ($gy,$gm,$gd,$dow);
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

sub get_nav_inner {
    my($festivals,$f,$observed) = @_;

    my @subfest_nav;
    foreach my $part (@{$SUBFESTIVALS{$f}}) {
	if ($festivals->{'festival'}->{$part}->{'kriyah'}) {
	    my $part2;
	    if ($part =~ /^$f(.*)/i) {
		$part2 = "reading$1";
	    } else {
		$part2 = $part;
	    }

	    my $slug = Hebcal::make_anchor($part2);
	    $slug =~ s/\.html$//;
	    push(@subfest_nav, [$slug, $part]);
	}
    }

    if (scalar(@subfest_nav) == 0) {
	return undef;
    } elsif (scalar(@subfest_nav) == 1) {
	@subfest_nav = ( [ $subfest_nav[0]->[0], "Torah Reading" ] );
    }

    my @nav_inner;
    push(@nav_inner, ["dates", "Dates"]) if scalar(@{$observed});
    push(@nav_inner, ["books", "Books"]) if $DO_AMAZON && $festivals->{"festival"}->{$SUBFESTIVALS{$f}->[0]}->{"books"}->{"book"};
    push(@nav_inner, @subfest_nav);
    push(@nav_inner, ["ref", "References"]);

    return \@nav_inner;
}

sub breadcrumb {
    my($f) = @_;
    my $type = $HebcalConst::HOLIDAY_TYPE{$f};
    my $nav_parent;
    if ($type eq "roshchodesh") {
        $nav_parent = "Rosh Chodesh";
    } elsif ($type eq "shabbat") {
        $nav_parent = "Special Shabbatot";
    } elsif ($type eq "fast") {
        $nav_parent = "Minor fasts";
    } else {
        $nav_parent = ucfirst($type) . " holidays";
    }
    my $nav_anchor = Hebcal::make_anchor($nav_parent);
    my $html =<<EOHTML
<div class="d-print-none">
<div class="d-none d-sm-block">
<nav>
<ol class="breadcrumb">
  <li class="breadcrumb-item"><a href="/holidays/">Holidays</a></li>
  <li class="breadcrumb-item"><a href="/holidays/#$nav_anchor">$nav_parent</a></li>
  <li class="breadcrumb-item active">$f</li>
</ol>
</nav>
</div><!-- .d-none d-sm-block -->
</div><!-- .d-print-none -->
EOHTML
;
    return $html;
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
    WARN("$f: missing About description") unless $descr;

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
    my $next_observed_meta = ". ";
    my $next_observed_para = "";
    if ($next_observed) {
        $next_observed_meta = ", $next_observed. ";
        $next_observed_para = qq{<p class="lead">$f $next_observed.</p>};
    }

    my $meta = <<EOHTML;
<meta name="description" content="Jewish holiday of $f$next_observed_meta$descr. Holiday Torah readings, dates observed.">
EOHTML
;

    print OUT2 HebcalHtml::header_bootstrap3(
	 $page_title, "/holidays/$slug", "ignored", $meta, 0, 1);

    my $wikipedia_descr;
    my $wikipedia = get_var($festivals, $f, 'wikipedia', 1);
    if ($wikipedia) {
	$wikipedia_descr = trim($wikipedia->{'content'});
    }
    my $long_descr = $wikipedia_descr ? $wikipedia_descr : $descr;
    $long_descr =~ s/(\p{script=Hebrew}[\p{script=Hebrew}\s]+\p{script=Hebrew})/<span lang="he" dir="rtl">$1<\/span>/g;

    my $pager = breadcrumb($f);

    print OUT2 <<EOHTML;
<div class="row">
<div class="col-sm-10">
$pager
<h1>$f / <span lang="he" dir="rtl">$hebrew</span></h1>
<p class="lead">$long_descr.</p>
$next_observed_para
EOHTML
;

    print OUT2 read_more_from($f,$about,$wikipedia);

    my $observed = observed_event_list($f);
    my $nav_inner = get_nav_inner($festivals, $f, $observed);
    if ($nav_inner) {
	print OUT2 qq{<nav class="d-print-none"><ul class="pagination">\n};
	foreach my $inner (@{$nav_inner}) {
	    my($slug,$part) = @{$inner};
	    print OUT2 qq{\t<li class="page-item"><a class="page-link" href="#$slug">$part</a></li>\n};
	}
	print OUT2 qq{</ul></nav><!-- .pagination -->\n};
    }

    if (scalar(@{$observed})) {
	my $rise_or_set = begins_when($f);

	print OUT2 <<EOHTML;
<h3 id="dates">List of Dates</h3>
$f begins on:
<ul>
EOHTML
	;
	my $displayed_upcoming = 0;
	foreach my $evt (@{$observed}) {
            my($year,$month,$day) = Hebcal::event_ymd($evt);
            my $hebdate = HebcalGPL::greg2hebrew($year,$month,$day);
	    my $greg2heb = Hebcal::format_hebrew_date($hebdate);
	    my($gy,$gm,$gd,$dow) = day_event_observed($f,$evt);
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
        my $args = "";
        foreach my $opt (qw(s maj min mod mf ss nx)) {
            $args .= join("", "&amp;", $opt, "=on");
        }
	    printf OUT2 "<li><a%s href=\"/hebcal/?v=1&amp;year=%d&amp;month=%d" .
		$args . "&amp;set=off\"$style>" .
		"<time datetime=\"%s\">%s, %02d %s %04d</time></a> $rise_or_set (%s)\n",
		$nofollow,
		$gy, $gm,
		$html5time, $Hebcal::DoW[$dow],
		$gd, $Hebcal::MoY_long{$gm}, $gy, $greg2heb;
	}
	print OUT2 <<EOHTML;
</ul>
EOHTML
    ;
    }

    amazon_recommended_books($festivals,$f) if $DO_AMAZON;

    if (@{$SUBFESTIVALS{$f}} == 1)
    {
	my $part = $SUBFESTIVALS{$f}->[0];
	if ($festivals->{'festival'}->{$part}->{'kriyah'}) {
	    print OUT2 qq{\n<h3 id="reading">Torah Reading</h3>\n};
	    write_festival_part($festivals, $part);
	}
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
href="https://www.amazon.com/o/ASIN/0062720082/hebcal-20">The
Jewish Holidays: A Guide &amp; Commentary</a></em>
<dd>Rabbi Michael Strassfeld
};

    if (defined $festivals->{'festival'}->{$f}->{'kriyah'}->{'aliyah'}) {
	print OUT2 qq{<dt><em><a class="outbound"
href="https://www.sefaria.org/texts/Tanakh">Sefaria Tanach</a></em>
<dd>Sefaria.org
<dt><em><a class="amzn" id="jps-tanakh-1"
title="Tanakh: The Holy Scriptures, The New JPS Translation According to the Traditional Hebrew Text"
href="https://www.amazon.com/o/ASIN/0827602529/hebcal-20">Tanakh:
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
</div><!-- .col-sm-10 -->
<div class="col-sm-2 d-print-none">
<h5>Advertisement</h5>
<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- skyscraper text only -->
<ins class="adsbygoogle"
     style="display:inline-block;width:160px;height:600px"
     data-ad-client="ca-pub-7687563417622459"
     data-ad-slot="7666032223"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .col-sm-2 -->
</div><!-- .row -->
EOHTML
;
    print OUT2 HebcalHtml::footer_bootstrap3(undef, undef);

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
    if ($about_href && $about_href =~ /^https?:\/\/([^\/]+)/i) {
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
    $html = qq{\n<p class="d-print-none"><em>Read more from };
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

sub print_aliyah
{
    my($aliyah) = @_;

    my($book,$verses) = Hebcal::get_book_and_verses($aliyah, undef);
    my $url = Hebcal::get_sefaria_url($book,$verses);

    my $title = "Hebrew-English text and commentary from Sefaria.org";
    my $info = qq{<a class="outbound" title="$title"\nhref="$url">$book $verses</a>};

    my($label) = ($aliyah->{'num'} eq 'M') ? 'maf' : $aliyah->{'num'};
    print OUT2 qq{$label: $info};

    if ($aliyah->{'numverses'}) {
	print OUT2 "\n<small>(",
	$aliyah->{'numverses'}, "&nbsp;p'sukim)</small>";
    }

    print OUT2 qq{<br>\n};
}

sub holidays_observed {
    foreach my $i (0 .. $NUM_YEARS) {
	my $yr = $HEB_YR + $i - 1;
	my $cmd = "./hebcal";
	$cmd .= " -i" if $opts{"i"};
	$cmd .= " -H $yr";
        my @events = Hebcal::invoke_hebcal_v2($cmd, "", 0);
        $EVENTS_BY_HEBYEAR[$i] = build_event_begin_hash(\@events, 0);

	my $yr2 = $FIRST_GREG_YR + $i;
	my $cmd2 = "./hebcal";
	$cmd2 .= " -i" if $opts{"i"};
	$cmd2 .= " $yr2";
        my @events2 = Hebcal::invoke_hebcal_v2($cmd2, "", 0);
        $EVENTS_BY_GREGYEAR[$i] = build_event_begin_hash(\@events2, 1);
    }
}

sub filter_events {
    my($events) = @_;
    my $dest = [];
    my %seen;
    foreach my $evt (@{$events}) {
        my $subj = $evt->{subj};
        next if $subj =~ /^Erev /;

        # Since Chanukah doesn't have an Erev, skip a day
        # Also, avoid the case where "Chanukah" ends in January
        if ($subj =~ /^Chanukah:/) {
           next unless $subj eq "Chanukah: 2 Candles";
           $subj = "Chanukah";
        }

        my $subj_copy = Hebcal::get_holiday_basename($subj);

        next if defined $seen{$subj_copy};
        $evt->{subj} = $subj_copy;
        push(@{$dest}, $evt);
        $seen{$subj_copy} = 1 unless $subj_copy eq "Asara B'Tevet";
    }
    $dest;
}

sub build_event_begin_hash {
    my($events,$multi) = @_;
    my $filtered = filter_events($events);
    my $dest = {};
    foreach my $evt (@{$filtered}) {
        my $subj = $evt->{subj};
        if ($multi) {
            $dest->{$subj} = [] unless defined $dest->{$subj};
            push(@{$dest->{$subj}}, $evt);
        } else {
            $dest->{$subj} = $evt;
        }
    }
    $dest;
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

sub observed_event_list {
    my($f) = @_;

    my @result;
    foreach my $i (0 .. $NUM_YEARS) {
	my $evt = $EVENTS_BY_HEBYEAR[$i]->{$f};
	push(@result, $evt) if defined $evt;
    }

    return \@result;
}

sub get_next_observed_str {
    my($f) = @_;

    my $next_observed = "";
    my $observed = observed_event_list($f);
    foreach my $evt (@{$observed}) {
	my $time = Hebcal::event_to_time($evt);
	if ($time >= $NOW) {
	    my($gy,$gm,$gd,$dow) = day_event_observed($f, $evt);
	    my $rise_or_set = begins_when($f);
	    $next_observed = sprintf "begins %s on %s, %02d %s %04d", $rise_or_set,
		$Hebcal::DoW[$dow], $gd, $Hebcal::MoY_long{$gm}, $gy;
	    last;
	}
    }

    $next_observed;
}

sub aws_bookinfo {
    my($asin) = @_;

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
        return undef;
    }

    if (defined $rxml->{"Items"}->{"Item"}->{"ASIN"}
        && $rxml->{"Items"}->{"Item"}->{"ASIN"} eq $asin) {
        my $attrs = $rxml->{"Items"}->{"Item"}->{"ItemAttributes"};
        my $bktitle = $attrs->{"Title"};
        my $author;
        if (ref($attrs->{"Author"}) eq "ARRAY") {
            $author = $attrs->{"Author"}->[0];
        } elsif (defined $attrs->{"Author"}) {
            $author = $attrs->{"Author"};
        }
        return ($bktitle,$author);
    } else {
        print STDERR "*** can't get Items/Item/ASIN from XML from ", $response->content, "\n";
        return undef;
    }
}

sub amazon_recommended_book {
    my($book,$anchor,$thumbnail_width) = @_;
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
        ($bktitle,$author) = aws_bookinfo($asin);
    }
    else {
        $author = trim($author) if $author;
        $bktitle = trim($bktitle);
        $bktitle =~ s/\n/ /g;
        $bktitle =~ s/\s+/ /g;
    }

    my $shorttitle = $bktitle;
    $shorttitle =~ s/\s*:.+//;
    my $link = "https://www.amazon.com/o/ASIN/$asin/hebcal-20";

    my $byauthor = $author ? qq{<br>by $author} : "";
    my $html = <<EOHTML
<div class="col-$thumbnail_width">
<div class="thumbnail">
<a class="amzn" id="$anchor-$asin-1" title="$bktitle" href="$link"><img src="/i/$img"
alt="$bktitle" width="$width" height="$height" style="border:none"></a>
<div class="caption">
<a class="amzn" id="$anchor-$asin-2" title="$bktitle" href="$link">$shorttitle</a>
$byauthor
</div><!-- .caption -->
</div><!-- .thumbnail -->
</div><!-- .col-$thumbnail_width -->
EOHTML
;
    return $html;
}

sub amazon_recommended_books {
    my($festivals,$f) = @_;

    my $subf = $SUBFESTIVALS{$f}->[0];
    my $books = $festivals->{"festival"}->{$subf}->{"books"}->{"book"};
    return 0 unless $books;

    if (ref($books) eq 'HASH') {
	$books = [ $books ];
    }

    my $anchor = Hebcal::make_anchor($f);
    $anchor =~ s/\.html$//;

    print OUT2 qq{<h3 id="books">Recommended Books</h3>\n<div class="row">\n};
    my $num_books = scalar @{$books};
    my $thumbnail_width = $num_books <= 3 ? 4 : 3;
    foreach my $book (@{$books}) {
        my $html = amazon_recommended_book($book,$anchor,$thumbnail_width);
        print OUT2 $html;
    }

    print OUT2 qq{</div><!-- .row -->\n};
}
