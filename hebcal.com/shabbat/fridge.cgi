#!/usr/local/bin/perl -w

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

use strict;
use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use Hebcal ();
use Date::Calc;
use HebcalGPL ();
use POSIX ();

my($rcsrev) = '$Revision$'; #'

# process form params
my($q) = new CGI;
my($script_name) = $q->script_name();
$script_name =~ s,/index.cgi$,/,;

my $cfg;
my($evts,undef,$city_descr,$dst_descr,$tz_descr,$cmd_pretty) =
    process_args($q);

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
print $q->header();
my $base = "http://" . $q->virtual_host() . $script_name;

my $head = <<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" type="text/css" id="bootstrap-css" href="/i/bootstrap-2.3.1/css/bootstrap.min.css" media="all">
<link rel="stylesheet" type="text/css" id="bootstrap-responsive-css" href="/i/bootstrap-2.3.1/css/bootstrap-responsive.min.css" media="all">
<style>
\@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
 .goto {display:none}
}
#fridge-table td {
  padding: 1px 6px;
}
</style>
<body>
<div class="container">
<div id="content" class="clearfix row-fluid">
EOHTML
;

Hebcal::out_html($cfg, $head);

my $numEntries = scalar(@{$evts});
Hebcal::out_html($cfg,
		 qq{<center><h3>Candle Lighting Times for $city_descr<br>\nHebrew Year $hebrew_year ($evts->[0]->[$Hebcal::EVT_IDX_YEAR] - $evts->[$numEntries-1]->[$Hebcal::EVT_IDX_YEAR])</h3>\n});
    
Hebcal::out_html($cfg,"<!-- $cmd_pretty -->\n");

format_items($q,$evts);

Hebcal::out_html($cfg, qq{</div><!-- #content -->\n</div><!-- .container -->\n</body>\n</html>\n});

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
	my $item_date = sprintf("%s %2d", $Hebcal::MoY_short[$mon], $mday);
	$item_date =~ s/  / &nbsp;/;

	my $min = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my $hour = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;
	my $item_time = sprintf("%d:%02d", $hour, $min);

	push(@items, [$item_date, $item_time, $reason, $yom_tov]);
    }

    my $table_head = <<EOHTML;
<table style="width:auto" id="fridge-table">
<col><col><col>
<col style="border-left:solid;border-width:2px;border-color:#dddddd"><col><col>
<tbody>
EOHTML
    ;
    Hebcal::out_html($cfg, $table_head);

    my $half = int(scalar(@items) / 2);
    for (my $i = 0; $i < $half; $i++) {
	Hebcal::out_html($cfg, "<tr>");
	my $left = $items[$i];

	my $left_reason = $left->[2];
	$left_reason = "<strong>" . $left_reason . "</strong>" if $left->[3];
	Hebcal::out_html($cfg, qq{<td style="text-align:right">}, $left->[0], "</td>",
			 qq{<td>}, $left_reason, "</td>",
			 "<td>", $left->[1], "</td>", "\n");

	my $right = $items[$i+$half];
	my $right_reason = $right->[2];
	$right_reason = "<strong>" . $right_reason . "</strong>" if $right->[3];
	Hebcal::out_html($cfg, qq{<td style="text-align:right">}, $right->[0], "</td>",
			 "<td>", $right_reason, "</td>",
			 "<td>", $right->[1], "</td>");
	Hebcal::out_html($cfg, "</tr>\n");
    }

    Hebcal::out_html($cfg,qq{</tbody></table>\n});

    Hebcal::out_html($cfg,"<p><a class=\"goto\" title=\"Previous\" href=\"",
		     Hebcal::self_url($q, {'year' => $hebrew_year - 1,
					   "tz" => undef, "dst" => undef}),
		     "\">&larr;&nbsp;", $hebrew_year - 1,
		     "</a>&nbsp;&nbsp;&nbsp;",
		     "Times in <b>bold</b> indicate holidays.",
		     "&nbsp;&nbsp;&nbsp;<a class=\"goto\" title=\"Next\" href=\"",
		     Hebcal::self_url($q, {'year' => $hebrew_year + 1,
					   "tz" => undef, "dst" => undef}),
		     "\">", $hebrew_year + 1, "&nbsp;&rarr;</a>",
		     "</p>\n");
}

sub process_args
{
    my($q) = @_;

    # default setttings needed for cookie
    $q->param('c','on');

    # sanitize input to prevent people from trying to hack the site.
    # remove anthing other than word chars, white space, or hyphens.
    my($key);
    foreach $key ($q->param())
    {
	my($val) = $q->param($key);
	$val = '' unless defined $val;
	$val =~ s/[^\w\s\.-]//g;
	$val =~ s/^\s*//g;		# nuke leading
	$val =~ s/\s*$//g;		# and trailing whitespace
	$q->param($key,$val);
    }

    my($cmd)  = './hebcal -s -x -c -H';

    my($city_descr,$dst_descr,$tz_descr);
    if (defined $q->param('city'))
    {
	unless (defined($Hebcal::city_tz{$q->param('city')}))
	{
	    $q->param('city','New York');
	}

	$q->param('geo','city');
	$q->delete('tz');
	$q->delete('dst');
	$q->delete('zip');

	$cmd .= " -C '" . $q->param('city') . "'";

	$city_descr = $q->param('city');

	if ($Hebcal::city_dst{$q->param('city')} eq 'israel')
	{
	    $q->param('i','on');
	}
	else
	{
	    $q->delete('i');
	}
    }
    elsif (defined $q->param('zip') && $q->param('zip') ne '')
    {
	$q->param('geo','zip');
	$q->delete('city');
	$q->delete('i');

	if ($q->param('zip') !~ /^\d{5}$/)
	{
	    $q->param('zip', 90210);
	}

	my $DB = Hebcal::zipcode_open_db();
	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    Hebcal::zipcode_get_zip_fields($DB, $q->param("zip"));
	Hebcal::zipcode_close_db($DB);
	undef($DB);

	unless (defined $state) {
	    print "Status: 400 Bad Request\r\n",
	    "Content-Type: text/plain\r\n\r\n",
	    "Can't find zip code ", $q->param('zip'), " in the DB.\n";
	    exit(0);
	}

	# allow CGI args to override
	if (defined $q->param('tz') && $q->param('tz') =~ /^-?\d+$/)
	{
	    $tz = $q->param('tz');
	}
	else
	{
	    $q->param('tz', $tz);
	}

	if ($tz eq '?') {
	    print "Status: 500 Internal Server Error\r\n",
	    "Content-Type: text/plain\r\n\r\n",
	    "No timezone for zip code ", $q->param('zip'), "\n";
	    exit(0);
	}

	$city_descr = "$city, $state";

	# allow CGI args to override
	if (defined $q->param('dst'))
	{
	    $dst = 0 if $q->param('dst') eq 'none';
	    $dst = 1 if $q->param('dst') eq 'usa';
	}

	if ($dst eq '1')
	{
	    $q->param('dst','usa');
	}
	else
	{
	    $q->param('dst','none');
	}

	my $dst_text = ($q->param('dst') eq 'none') ? 'none' :
	    'automatic for ' . $Hebcal::dst_names{$q->param('dst')};
	$dst_descr = "Daylight Saving Time: $dst_text";
	$tz_descr = "Time zone: " . $Hebcal::tz_names{$q->param('tz')};

	$cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
    }
    else
    {
	$q->param('city','New York');
	$q->param('geo','city');
	$q->delete('tz');
	$q->delete('dst');
	$q->delete('zip');
	$q->delete('i');

	$cmd .= " -C '" . $q->param('city') . "'";

	$city_descr = $q->param('city');
    }

    $cmd .= " -z " . $q->param('tz')
	if (defined $q->param('tz') && $q->param('tz') ne '');

    $cmd .= " -Z " . $q->param('dst')
	if (defined $q->param('dst') && $q->param('dst') ne '');

    foreach ('a', 'i')
    {
	$cmd .= ' -' . $_
	    if defined $q->param($_) && $q->param($_) =~ /^on|1$/;
    }

    if (defined $q->param('year') && $q->param('year') =~ /^\d+$/) {
	$cmd .= " " . $q->param('year');
    } else {
	my($this_year,$this_mon,$this_day) = Date::Calc::Today();
	my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
	my $HEB_YR = $hebdate->{"yy"};
	$HEB_YR++ if $hebdate->{"mm"} == 6; # Elul
	$cmd .= " " . $HEB_YR;
    }

    my(@events) = Hebcal::invoke_hebcal($cmd, '', 0);
    
    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename

    (\@events,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty);
}

# local variables:
# mode: perl
# end:
