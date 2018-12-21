#!/usr/bin/perl -w

########################################################################
# Refrigerator candle-lighting times.  1 page for entire year.
#
# Copyright (c) 2018  Michael J. Radwin.
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

use strict;
use CGI qw(-no_xhtml);
use Encode qw(decode_utf8);
use CGI::Carp qw(fatalsToBrowser);
use Hebcal ();
use HebcalConst;
use Date::Calc;
use URI::Escape;
use POSIX ();
use Benchmark qw(:hireswallclock :all);

my $t0 = Benchmark->new;

# process form params
my($q) = new CGI;
my($script_name) = $q->script_name();
$script_name =~ s,/index.cgi$,/,;

foreach my $key ($q->param()) {
    my $val = $q->param($key);
    if (defined $val) {
        my $orig = $val;
        if ($key eq "city" || $key eq "city-typeahead") {
            $val = decode_utf8($val);
        } elsif ($key eq "tzid") {
            $val =~ s/[^\/\w\.\s-]//g; # allow forward-slash in tzid
        } else {
            # sanitize input to prevent people from trying to hack the site.
            # remove anthing other than word chars, white space, or hyphens.
            $val =~ s/[^\w\.\s-]//g;
        }
        $val =~ s/^\s+//g;              # nuke leading
        $val =~ s/\s+$//g;              # and trailing whitespace
        $q->param($key, $val) if $val ne $orig;
    }
}

my($evts,undef,$city_descr,$short_city,$cmd_pretty) = process_args($q);

my $hebrew_year = 0;
my $numEntries2 = scalar(@{$evts});
for (my $i = 0; $i < $numEntries2; $i++)
{
    if ($evts->[$i]->{subj} =~ /^Rosh Hashana (\d{4})$/)
    {
        $hebrew_year = $1;
        last;
    }
}

my $title = "Refrigerator Shabbos Times for $city_descr - $hebrew_year | Hebcal";

print $q->header(-type => "text/html",
                 -charset => "UTF-8");

my $font_family = "Open Sans";
my $font_list = "Open+Sans:300,600|Open+Sans+Condensed:300";
my $lang = $q->param("lg") || "s";
$lang = "he" if $lang eq "h";
if ($lang eq "he") {
    $font_family = "Alef";
    $font_list .= "|Alef|Alef:700";
}

my $header = <<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<link href='/i/normalize-8.0.1.min.css' rel='stylesheet' type='text/css'>
<link href='//fonts.googleapis.com/css?family=$font_list' rel='stylesheet' type='text/css'>
<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  ga('create', 'UA-967247-1', 'auto');
  ga('set', 'anonymizeIp', true);
  ga('send', 'pageview');
</script>
<style>
body {
  font-family: '$font_family', sans-serif;
}
h3 {
  font-weight: 600;
  margin:24px 0 0;
}
table {
  border-spacing: 0;
  border-collapse: collapse;
}
#fridge-table td {
  padding: 0px 4px;
}
#fridge-table td.leftpad {
  padding: 0 0 0 12px;
}
.text-right {
  text-align: right;
}
.yomtov { font-weight:600 }
.narrow { font-family: 'Open Sans Condensed', sans-serif }
\@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
 .goto {display:none}
}
</style>
</head>
<body>
<div align="center">
EOHTML
;

print $header;

my $numEntries = scalar(@{$evts});
my $greg_year1 = $evts->[0]->{year};
my $greg_year2 = $evts->[$numEntries-1]->{year};
print qq{<h3>Candle Lighting Times for $short_city
<br>Hebrew Year $hebrew_year ($greg_year1 - $greg_year2)</h3>
<p style="margin:0 0 4px">www.hebcal.com</p>
<!-- $cmd_pretty -->
};

my $items = filter_events($evts);
format_items($q,$items);

print qq{</div><!-- align=center -->
</body>
</html>
};

my $tend = Benchmark->new;
my $tdiff = timediff($tend, $t0);
print "<!-- ", timestr($tdiff), " -->\n";

exit(0);

sub filter_events {
    my($events) = @_;

    my $lang = $q->param("lg") || "s";
    $lang = "he" if $lang eq "h";
    my $numEntries = scalar(@{$events});
    my @items;
    for (my $i = 0; $i < $numEntries; $i++)
    {
        next unless $events->[$i]->{subj} eq 'Candle lighting';

        my $reason = "";
        my $yom_tov = 0;
        if (defined $events->[$i+1]
            && $events->[$i+1]->{subj} =~ /^(Parashat|Parshas) (.+)$/) {
            $reason = $2;
        } elsif ($i == $numEntries - 1) {
            $yom_tov = 1;
            $reason = "Rosh Hashana";
        } else {
            $yom_tov = $events->[$i+1]->{yomtov};
            $reason = Hebcal::get_holiday_basename($events->[$i+1]->{subj});
        }

        my $mon = $events->[$i]->{mon};
        my $mday = $events->[$i]->{mday};

        my $item_time = Hebcal::format_evt_time($events->[$i], "", $lang);

        my $s0 = $HebcalConst::TRANSLATIONS->{$lang}->{$reason};
        if (defined $s0) {
            $reason = $s0;
        } elsif (index($reason, "-") != -1) {
            my($p1,$p2) = split(/-/, $reason);
            my $s1 = $HebcalConst::TRANSLATIONS->{$lang}->{$p1};
            my $s2 = $HebcalConst::TRANSLATIONS->{$lang}->{$p2};
            if (defined $s1 && defined $s2) {
                $reason = join("-", $s1, $s2);
            }
        }

        push(@items, [$Hebcal::MoY_short[$mon], $mday, $item_time, $reason, $yom_tov]);
    }
    \@items;
}

sub format_items
{
    my($q,$items) = @_;

    my $table_head = <<EOHTML;
<table style="width:524px" id="fridge-table">
<colgroup>
<col><col><col><col>
<col>
<col style="border-left:1px solid #999"><col><col><col>
</colgroup>
<tbody>
EOHTML
    ;
    print $table_head;

    my $half = POSIX::ceil(scalar(@{$items}) / 2.0);
    for (my $i = 0; $i < $half; $i++) {
        print "<tr>";
        format_row($items->[$i], 0);
        print "\n";
        print "<td></td>\n";
        format_row($items->[$i+$half], 1);
        print "</tr>\n";
    }

    print qq{</tbody></table>\n};

    my $url_base = $script_name . "?";
    $url_base .= Hebcal::get_geo_args($q, "&amp;");
    foreach my $arg (qw(a i)) {
        $url_base .= sprintf("&amp;%s=%s", $arg, scalar $q->param($arg))
            if defined $q->param($arg) && $q->param($arg) =~ /^on|1$/;
    }
    $url_base .= "&amp;lg=$lang";
    $url_base .= "&amp;m=" . $q->param('m');
    $url_base .= "&amp;year=";

    print "<p><a class=\"goto\" title=\"Previous\" href=\"",
        $url_base, ($hebrew_year - 1),
        "\" rel=\"nofollow\">&larr;&nbsp;", $hebrew_year - 1,
        "</a>&nbsp;&nbsp;&nbsp;",
        "Times in <strong>bold</strong> indicate holidays.",
        "&nbsp;&nbsp;&nbsp;<a class=\"goto\" title=\"Next\" href=\"",
        $url_base, ($hebrew_year + 1),
        "\" rel=\"nofollow\">", $hebrew_year + 1, "&nbsp;&rarr;</a>",
        "</p>\n";
}

sub td_with_class {
    if (@_) {
        return qq{<td class="} . join(" ", @_) . qq{">};
    } else {
        return "<td>";
    }
}

sub format_row {
    my($item,$right) = @_;

    unless (defined $item) {
        print "<td></td><td></td><td></td><td></td>";
        return;
    }
    my($month,$day,$time,$subject,$yom_tov) = @{$item};
    my @class = ();
    if ($yom_tov) {
        push(@class, "yomtov");
    }
    my @narrow = ();
    if ($lang eq "he") {
        push(@narrow, "text-right");
    } elsif (length($subject) > 14) {
        push(@narrow, "narrow");
    }
    my @monthClass = @class;
    my @timeClass = @class;
    push(@timeClass, "text-right");
    if ($right) {
        push(@monthClass, "leftpad");
    }
    print td_with_class(@monthClass), $month, "</td>",
        td_with_class(@class, "text-right"), $day, "</td>",
        td_with_class(@class, @narrow), $subject, "</td>",
        td_with_class(@timeClass), $time, "</td>";
}

sub process_args
{
    my($q) = @_;

    my %cconfig;

    # force a valid Havdalah setting for yomtov starting Motzei Shabbat
    if (!defined $q->param('m') || $q->param('m') eq '0') {
        $q->param('m', $Hebcal::havdalah_min);
    }

    my @status = Hebcal::process_args_common($q, 0, 1, \%cconfig);
    unless ($status[0]) {
        print "Status: 400 Bad Request\r\n", "Content-Type: text/html\r\n\r\n",
            $status[1], "\n";
        exit(0);
    }

    my($ok,$cmd,$latitude,$longitude,$city_descr) = @status;

    my $short_city = $cconfig{"city"} ? $cconfig{"city"} : $city_descr;
    if ($cconfig{"geo"} eq "zip") {
        $short_city = $cconfig{"city"} . ", " . $cconfig{"state"};
    }

    $cmd .= " -c -s -x";

    if (defined $q->param('year') && $q->param('year') =~ /^\d+$/) {
        $cmd .= " -H " . $q->param('year');
    } else {
        my($yy,$mm,$dd) = Date::Calc::Today();
        my $HEB_YR = Hebcal::get_default_hebrew_year($yy,$mm,$dd);
        $cmd .= " -H " . $HEB_YR;
    }

    my(@events) = Hebcal::invoke_hebcal_v2($cmd, '', 0);

    my $cfg;
    (\@events,$cfg,$city_descr,$short_city,$cmd);
}

# local variables:
# mode: cperl
# end:
