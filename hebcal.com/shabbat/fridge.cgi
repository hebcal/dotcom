#!/usr/bin/perl -w

########################################################################
# Refrigerator candle-lighting times.  1 page for entire year.
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

use strict;
use CGI qw(-no_xhtml -utf8);
use CGI::Carp qw(fatalsToBrowser);
use Hebcal ();
use Date::Calc;
use URI::Escape;
use HebcalGPL ();
use POSIX ();

# process form params
my($q) = new CGI;
my($script_name) = $q->script_name();
$script_name =~ s,/index.cgi$,/,;

my $cfg;
my($evts,undef,$city_descr,$cmd_pretty) = process_args($q);

my $hebrew_year = 0;
my $numEntries2 = scalar(@{$evts});
for (my $i = 0; $i < $numEntries2; $i++)
{
    if ($evts->[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Rosh Hashana (\d{4})$/)
    {
	$hebrew_year = $1;
	last;
    }
}

my $title = "Refrigerator Shabbos Times for $hebrew_year";

print "Cache-Control: private\015\012";
print $q->header(-type => "text/html",
		 -charset => "UTF-8");

my $head = <<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<link href='http://fonts.googleapis.com/css?family=PT+Sans:400,700|PT+Sans+Narrow:400,700' rel='stylesheet' type='text/css'>
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="/i/bootstrap-2.3.1/css/bootstrap.min.css" media="all">
<script type="text/javascript">
var _gaq = _gaq || [];
_gaq.push(['_setAccount', 'UA-967247-1']);
_gaq.push(['_trackPageview']);
(function() {
var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
})();
</script>
<style>
body {
  font-size: 85%;
  font-family: 'PT Sans', sans-serif;
  line-height: 1.25;
}
\@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
 .goto {display:none}
}
#fridge-table td {
  padding: 0px 4px;
}
#fridge-table td.leftpad {
  padding: 0 0 0 6px;
}
.yomtov { font-weight:700 }
.narrow { font-family: 'PT Sans Narrow', sans-serif }
</style>
<body>
<div class="container">
<div id="content" class="clearfix row-fluid">
EOHTML
;

Hebcal::out_html($cfg, $head);

my $numEntries = scalar(@{$evts});
Hebcal::out_html($cfg,
		 qq{<div align="center">\n<h4 style="margin:24px 0 0">Candle Lighting Times for $city_descr<br>\nHebrew Year $hebrew_year ($evts->[0]->[$Hebcal::EVT_IDX_YEAR] - $evts->[$numEntries-1]->[$Hebcal::EVT_IDX_YEAR])</h4>\n});
Hebcal::out_html($cfg, qq{<p style="margin:0 0 4px">www.hebcal.com</p>\n});
    
Hebcal::out_html($cfg,"<!-- $cmd_pretty -->\n");

format_items($q,$evts);

Hebcal::out_html($cfg, qq{</div><!-- .center -->\n</div><!-- #content -->\n</div><!-- .container -->\n</body>\n</html>\n});

exit(0);

sub format_items
{
    my($q,$events) = @_;

    my $numEntries = scalar(@{$events});
    my @items;
    for (my $i = 0; $i < $numEntries; $i++)
    {
	next unless $events->[$i]->[$Hebcal::EVT_IDX_SUBJ] eq 'Candle lighting';

	my $reason = "";
	my $yom_tov = 0;
	if (defined $events->[$i+1]
	    && $events->[$i+1]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Parashat (.+)$/) {
	    $reason = $1;
	} elsif ($i == $numEntries - 1) {
	    $yom_tov = 1;
	    $reason = "Rosh Hashana";
	} else {
	    $yom_tov = $events->[$i+1]->[$Hebcal::EVT_IDX_YOMTOV];
	    $reason = $events->[$i+1]->[$Hebcal::EVT_IDX_SUBJ];
	    $reason =~ s/ \(CH\'\'M\)$//;
	    $reason =~ s/ \(Hoshana Raba\)$//;
	    $reason =~ s/ [IV]+$//;
	    $reason =~ s/: \d Candles?$//;
	    $reason =~ s/: 8th Day$//;
	    $reason =~ s/^Erev //;
	    $reason =~ s/ \d{4}$//;
	}

	my $mon = $events->[$i]->[$Hebcal::EVT_IDX_MON];
	my $mday = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my $min = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my $hour = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;
	my $item_time = sprintf("%d:%02d", $hour, $min);

	push(@items, [$Hebcal::MoY_short[$mon], $mday, $item_time, $reason, $yom_tov]);
    }

    my $table_head = <<EOHTML;
<table style="width:auto" id="fridge-table">
<col><col><col><col>
<col style="border-left:solid;border-width:1px;border-color:#999999"><col><col><col>
<tbody>
EOHTML
    ;
    Hebcal::out_html($cfg, $table_head);

    my $half = POSIX::ceil(scalar(@items) / 2.0);
    for (my $i = 0; $i < $half; $i++) {
	Hebcal::out_html($cfg, "<tr>");
	format_row($items[$i]);
	Hebcal::out_html($cfg, "\n");
	format_row($items[$i+$half]);
	Hebcal::out_html($cfg, "</tr>\n");
    }

    Hebcal::out_html($cfg,qq{</tbody></table>\n});

    my $url_base = $script_name . "?";
    if ($q->param("zip")) {
	$url_base .= "zip=" . $q->param("zip");
    } else {
	$url_base .= "city=" . URI::Escape::uri_escape_utf8($q->param("city"));
    }
    $url_base .= "&amp;year=";

    Hebcal::out_html($cfg,"<p><a class=\"goto\" title=\"Previous\" href=\"",
		     $url_base . ($hebrew_year - 1) .
		     "\">&larr;&nbsp;", $hebrew_year - 1,
		     "</a>&nbsp;&nbsp;&nbsp;",
		     "Times in <strong>bold</strong> indicate holidays.",
		     "&nbsp;&nbsp;&nbsp;<a class=\"goto\" title=\"Next\" href=\"",
		     $url_base . ($hebrew_year + 1) .
		     "\">", $hebrew_year + 1, "&nbsp;&rarr;</a>",
		     "</p>\n");
}

sub format_row {
    my($item) = @_;

    unless (defined $item) {
	Hebcal::out_html($cfg, "<td><td><td><td>");
	return;
    }
    my($month,$day,$time,$subject,$yom_tov) = @{$item};
    my @class = ();
    if ($yom_tov) {
	push(@class, "yomtov");
    }
    my @narrow = ();
    if (length($subject) > 14) {
	push(@narrow, "narrow");
    }
    Hebcal::out_html($cfg,
		     qq{<td class="}, join(" ", @class, "leftpad"), qq{">}, $month, "</td>",
		     qq{<td class="}, join(" ", @class, "text-right"), qq{">}, $day, "</td>",
		     qq{<td class="}, join(" ", @class, @narrow), qq{">}, $subject, "</td>",
		     qq{<td class="}, join(" ", @class), qq{">}, $time, "</td>");
}

sub process_args
{
    my($q) = @_;

    my @status = Hebcal::process_args_common($q, 0, 1);
    unless ($status[0]) {
	print "Status: 400 Bad Request\r\n", "Content-Type: text/html\r\n\r\n",
	    $status[1], "\n";
	exit(0);
    }

    my($ok,$cmd,$latitude,$longitude,$city_descr) = @status;
    $cmd .= " -c -s -x";

    if (defined $q->param('year') && $q->param('year') =~ /^\d+$/) {
	$cmd .= " -H " . $q->param('year');
    } else {
	my($this_year,$this_mon,$this_day) = Date::Calc::Today();
	my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
	my $HEB_YR = $hebdate->{"yy"};
	$HEB_YR++ if $hebdate->{"mm"} == 6; # Elul
	$cmd .= " -H " . $HEB_YR;
    }

    my(@events) = Hebcal::invoke_hebcal($cmd, '', 0);

    # shorten the headline for USA
    $city_descr =~ s/, USA$//;	# no United States of America
    $city_descr =~ s/ \d{5}$//;	# no zipcode
    (\@events,$cfg,$city_descr,$cmd);
}

# local variables:
# mode: cperl
# end:
