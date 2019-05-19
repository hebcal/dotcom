#!/usr/bin/perl -w

########################################################################
#
# Generates pages for http://www.hebcal.com/shabbat/browse/
#
# Copyright (c) 2019  Michael J. Radwin.
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
use Hebcal ();
use HebcalHtml ();
use Date::Calc ();
use Carp;
use Log::Log4perl qw(:easy);
use strict;

my $opt_indexonly = 0;
my $opt_help;
my $opt_verbose = 0;
my @opt_country;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "indexonly" => \$opt_indexonly,
     "country=s" => \@opt_country,
     "verbose|v+" => \$opt_verbose)) {
    usage();
}

$opt_help && usage();
(@ARGV == 1) || usage();

my $loglevel;
if ($opt_verbose == 0) {
    $loglevel = $WARN;
} elsif ($opt_verbose == 1) {
    $loglevel = $INFO;
} else {
    $loglevel = $DEBUG;
}
Log::Log4perl->easy_init($loglevel);

my $outdir = shift;

if (! -d $outdir) {
    die "$outdir: $!\n";
}

DEBUG("Opening $Hebcal::GEONAME_SQLITE_FILE");
my $dbh = Hebcal::zipcode_open_db($Hebcal::GEONAME_SQLITE_FILE);
$dbh->{sqlite_unicode} = 1;

my $countries = get_countries();

my($fri_year,$fri_month,$fri_day) = Hebcal::upcoming_dow(5); # friday
my $shabbat_formatted = Date::Calc::Date_to_Text_Long($fri_year,$fri_month,$fri_day);
my $parsha = get_parashat_hashavua();
if ($parsha) {
    $shabbat_formatted .= " - " . $parsha;
}

my $written_countries = {};
foreach my $continent (keys %Hebcal::CONTINENTS) {
    $written_countries->{$continent} = [];
}
foreach my $continent (keys %Hebcal::CONTINENTS) {
    foreach my $iso_country (@{$countries->{$continent}}) {
        my $iso = $iso_country->[0];
        my $country = $iso_country->[1];
        my $anchor = Hebcal::make_anchor($country);
        my $ok;
        if ($opt_indexonly) {
            $ok = 1;
        } else {
            $ok = write_country_page($iso,$anchor,$country);
        }
        if ($ok) {
            push(@{$written_countries->{$continent}}, [$iso, $country]);
        }
    }
}

if (scalar(@opt_country) == 0) {
    write_index_page($written_countries);
}

Hebcal::zipcode_close_db($dbh);
undef($dbh);
exit(0);

sub usage {
    my $usage = "usage: $0 [-hv] output-dir
  --help        Display usage information
  --verbose     Verbose mode
  --indexonly   Only generate index
  --country=ISO Only generate for ISO country code
";
    die "$usage\n";
}

sub get_countries {
    my %countries;
    foreach my $continent (keys %Hebcal::CONTINENTS) {
        $countries{$continent} = [];
    }
    my $sql = qq{SELECT Continent, ISO, Country FROM country};
    if (@opt_country) {
        my $s = uc(join("','", @opt_country));
        $sql .= qq{ WHERE ISO IN ('$s')};
    }
    $sql .= qq{ ORDER BY Continent, Country};
    DEBUG($sql);
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute() or die $dbh->errstr;
    while (my($continent,$iso,$country) = $sth->fetchrow_array) {
        next if $country eq "";
        push(@{$countries{$continent}}, [$iso, $country]);
    }
    $sth->finish;
    return \%countries;
}

sub write_country_admin1_page {
    my($filename,$iso,$country,$admin1,$title_date,$shabbat_formatted,$results) = @_;

    INFO("$country - $admin1");

    my $fn = "$outdir/$filename";
    open(my $fh, ">$fn.$$") || die "$fn.$$: $!\n";

    my $page_title = "$admin1, $country Shabbat Times - $title_date";
    print $fh HebcalHtml::header_bootstrap3($page_title,
        "/shabbat/browse/$filename", "ignored");

    print $fh <<EOHTML;
<div class="row">
<div class="col-sm-12">
<h2>$admin1, $country<br><span class="h4 small text-muted">Shabbat Candle Lighting Times</span></h2>
<p class="lead">$shabbat_formatted</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<div class="row">
<div class="col-sm-12">
<ul class="list-unstyled">
EOHTML
    ;

    foreach my $res (@{$results}) {
        write_candle_lighting($fh,$res,$iso,0);
    }

    print $fh <<EOHTML;
</ul>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
EOHTML
    ;

    print $fh HebcalHtml::footer_bootstrap3(undef, undef);

    close($fh);
    rename("$fn.$$", $fn) || die "$fn: $!\n";

}

sub write_country_page {
    my($iso,$anchor,$country) = @_;

    my $sql = qq{SELECT g.geonameid, g.name, g.asciiname, a.name, g.latitude, g.longitude, g.timezone
FROM geoname g
LEFT JOIN admin1 a on g.country||'.'||g.admin1 = a.key
WHERE g.country = ?
ORDER BY g.asciiname};
    DEBUG($sql);
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute($iso) or die $dbh->errstr;

    my @results;
    my %admin1;
    while (my($geonameid,$name,$asciiname,$admin1,$latitude,$longitude,$tzid) = $sth->fetchrow_array) {
        $admin1 ||= '';
        push(@results, [$geonameid,$name,$asciiname,$admin1,$latitude,$longitude,$tzid]);
        $admin1{$admin1} = [] unless defined $admin1{$admin1};
        push(@{$admin1{$admin1}}, [$geonameid,$name,$asciiname,$admin1,$latitude,$longitude,$tzid]);
    }
    $sth->finish;

    my $num_results = scalar(@results);
    my $count_distinct_admin1 = scalar(keys(%admin1));

    INFO("$country - $num_results, $count_distinct_admin1 admin1 regions");

    return 0 if $num_results == 0;

    my $fn = "$outdir/$anchor";
    open(my $fh, ">$fn.$$") || die "$fn.$$: $!\n";

    my $title_date = $shabbat_formatted;
    $title_date =~ s/^Friday, //;

    my $page_title = "$country Shabbat Times - $title_date";
    print $fh HebcalHtml::header_bootstrap3($page_title,
        "/shabbat/browse/$anchor", "ignored");

    print $fh <<EOHTML;
<div class="row">
<div class="col-sm-12">
<h2>$country<br><span class="h4 small text-muted">Shabbat Candle Lighting Times</span></h2>
<p class="lead">$shabbat_formatted</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<div class="row">
EOHTML
    ;

    if ($#results < 30 || $count_distinct_admin1 == 1) {
        print $fh qq{<div class="col-sm-12">\n};
        print $fh qq{<ul class="list-unstyled">\n};
        my $show_admin1 = $count_distinct_admin1 > 1 ? 1 : 0;
        foreach my $res (@results) {
            write_candle_lighting($fh,$res,$iso,$show_admin1);
        }
        print $fh qq{</ul>\n};
        print $fh qq{</div><!-- .col-sm-12 -->\n};
    } elsif ($#results > 499) {
        my $sql = qq{SELECT key,name,asciiname FROM admin1 WHERE key LIKE '$iso.%' ORDER BY key};
        DEBUG($sql);
        my $sth = $dbh->prepare($sql) or die $dbh->errstr;
        $sth->execute() or die $dbh->errstr;
        my %a1s;
        while (my($key,$name,$asciiname) = $sth->fetchrow_array) {
            my $anchor2 = Hebcal::make_anchor($asciiname);
            $a1s{$key} = [$name, $asciiname, $anchor2];
        }
        $sth->finish;

        # write index
        print $fh qq{<div class="col-sm-12">\n};
        print $fh qq{<ul class="list-unstyled">\n};
        foreach my $key (sort keys %a1s) {
            my($name,$asciiname,$anchor2) = @{$a1s{$key}};
            print $fh qq{<li><a href="$anchor-$anchor2">$name</a></li>\n};
        }
        print $fh qq{</ul>\n};
        print $fh qq{</div><!-- .col-sm-12 -->\n};

        # write each page
        foreach my $key (sort keys %a1s) {
            my($name,$asciiname,$anchor2) = @{$a1s{$key}};
            write_country_admin1_page("$anchor-$anchor2",
                $iso,$country,$name,$title_date,$shabbat_formatted,
                $admin1{$name});
        }
    } else {
        foreach my $admin1 (sort keys %admin1) {
            my $anchor = Hebcal::make_anchor($admin1);
            print $fh qq{<div class="col-sm-3" id="$anchor"><h3>$admin1</h3>\n};
            print $fh qq{<ul class="list-unstyled">\n};
            foreach my $res (@{$admin1{$admin1}}) {
                write_candle_lighting($fh,$res,$iso,0);
            }
            print $fh qq{</ul>\n};
            print $fh qq{</div><!-- #$anchor -->\n};
        }
    }

    print $fh qq{</div><!-- .row -->\n};

    print $fh HebcalHtml::footer_bootstrap3(undef, undef);

    close($fh);
    rename("$fn.$$", $fn) || die "$fn: $!\n";

    return $num_results;
}

sub get_parashat_hashavua {
    my($syear,$smonth,$sday) = Hebcal::upcoming_dow(6); # saturday
    DEBUG("Shabbat is $syear-$smonth-$sday");

    my $cmd = "$Hebcal::HEBCAL_BIN -s -h -x $syear";
    DEBUG("Invoking $cmd");

    my @events = Hebcal::invoke_hebcal_v2($cmd, "", 0, $smonth);
    my $parsha;
    foreach my $evt (@events) {
        if ($evt->{mday} == $sday) {
            $parsha = $evt->{subj};
            last;
        }
    }

    return $parsha;
}

sub write_candle_lighting {
    my($fh,$info,$iso,$show_admin1) = @_;
    my($geonameid,$name,$asciiname,$admin1,$latitude,$longitude,$tzid) = @{$info};
    my $hour_min = get_candle_lighting($latitude,$longitude,$tzid,$iso,$asciiname,$admin1);
    if ($hour_min) {
        my $comma_admin1 = $show_admin1 && $admin1 && index($admin1, $name) != 0 ? "<small>, $admin1</small>" : "";
        print $fh qq{<li><a href="/shabbat/?geonameid=$geonameid">$name</a>$comma_admin1 $hour_min</li>\n};
    } else {
        INFO("No candle-lighting on $shabbat_formatted for $asciiname, $iso");
    }
}

sub get_candle_lighting {
    my($latitude,$longitude,$tzid,$country,$asciiname,$admin1) = @_;
    my $cmd = $Hebcal::HEBCAL_BIN;
    $cmd .= Hebcal::cmd_latlong($latitude,$longitude,$tzid);
    if ($country eq "IL") {
        $cmd .= " -i";
        $cmd .= " -b 40" if $admin1 && index($admin1, "Jerusalem") == 0;
    }
    $cmd .= " -m 50 -c -s $fri_year";
    DEBUG("$asciiname, $admin1, $country - $cmd");
    my @events = Hebcal::invoke_hebcal_v2($cmd, "", 0, $fri_month);
    foreach my $evt (@events) {
        next unless $evt->{subj} eq "Candle lighting";
        my($gy,$gm,$gd) = Hebcal::event_ymd($evt);
        if ($gm == $fri_month && $gd == $fri_day) {
            return Hebcal::format_evt_time($evt, "pm");
        }
    }
    return undef;
}

sub write_index_page {
    my($countries) = @_;

    my $fn = "$outdir/index.html";
    INFO($fn);
    open(my $fh, ">$fn.$$") || die "$fn.$$: $!\n";

    my $page_title = "Shabbat Candle Lighting Times";
    my $xtra_head = qq{<link rel="stylesheet" type="text/css" href="/i/hyspace-typeahead.css">};

    print $fh HebcalHtml::header_bootstrap3($page_title,
        "/shabbat/browse/", "ignored", $xtra_head);

    print $fh <<EOHTML;
<div class="row">
<div class="col-sm-12">
<h1>$page_title</h1>
<p class="lead">Candle-lighting and Havdalah times. Weekly Torah portion.</p>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
<div class="row">
<div class="col-sm-10 col-sm-offset-1">
<form action="/shabbat/" method="get" role="form" id="shabbat-form">
  <input type="hidden" name="geo" id="geo" value="geoname">
  <input type="hidden" name="geonameid" id="geonameid">
  <input type="hidden" name="zip" id="zip">
  <label class="sr-only" for="city-typeahead">City</label>
  <div class="city-typeahead" style="margin-bottom:12px">
    <input type="text" id="city-typeahead" class="form-control input-lg typeahead" placeholder="Search for city or ZIP code">
  </div>
</form>
</div><!-- .col-sm-10 -->
</div><!-- .row -->
<div class="row">
EOHTML
    ;

    foreach my $continent (qw(EU NA SA OC AS AF AN)) {
        my $name = $Hebcal::CONTINENTS{$continent};
        print $fh <<EOHTML;
<div class="col-sm-4">
<h3>$name</h3>
<ul class="bullet-list-inline">
EOHTML
    ;
        foreach my $iso_country (@{$countries->{$continent}}) {
            my $iso = $iso_country->[0];
            my $country = $iso_country->[1];
            my $anchor = Hebcal::make_anchor($country);
            print $fh qq{<li><a href="$anchor">$country</a></li>\n};
        }
        print $fh "</ul>\n</div><!-- .col-sm-4 -->\n";
    }

    print $fh qq{</div><!-- .row -->\n};

    my $xtra_html=<<JSCRIPT_END;
<script src="$Hebcal::JS_TYPEAHEAD_BUNDLE_URL"></script>
<script src="$Hebcal::JS_APP_URL"></script>
<script>
window['hebcal'].createCityTypeahead(true);
</script>
JSCRIPT_END
        ;

    print $fh HebcalHtml::footer_bootstrap3(undef, undef, undef, $xtra_html);

    close($fh);
    rename("$fn.$$", $fn) || die "$fn: $!\n";
}