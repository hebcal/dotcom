#!/usr/local/bin/perl -w

########################################################################
# Refrigerator candle-lighting times.  1 page for entire year.
#
# Copyright (c) 2004  Michael J. Radwin.
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

use lib "/home/mradwin/local/share/perl";
use lib "/home/mradwin/local/share/perl/site_perl";

use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;
use Hebcal;
use POSIX qw(strftime);
use strict;

my($rcsrev) = '$Revision$'; #'

# process form params
my($q) = new CGI;
my($script_name) = $q->script_name();
$script_name =~ s,/index.cgi$,/,;

my $cfg;
my($evts,undef,$city_descr,$dst_descr,$tz_descr,$cmd_pretty) =
    process_args($q);

my $hebrew_year = '';
if ($evts->[0]->[$Hebcal::EVT_IDX_SUBJ] =~ /^Rosh Hashana (\d{4})$/)
{
    $hebrew_year = $1;
}

my($title) = "Refrigerator Shabbos Times for $hebrew_year";

print "Cache-Control: private\015\012";
print $q->header(),
    Hebcal::start_html($q, $title, [], undef, undef);

print Hebcal::navbar2($q, "Shabbat Times $hebrew_year", 1, "1-Click Shabbat", "/shabbat/");

my $numEntries = scalar(@{$evts});
Hebcal::out_html($cfg,
		 qq{<h2>Candle Lighting Times for<br>\n$city_descr &nbsp;$evts->[0]->[$Hebcal::EVT_IDX_YEAR] - $evts->[$numEntries-1]->[$Hebcal::EVT_IDX_YEAR]</h2>\n});
    
Hebcal::out_html($cfg,"<!-- $cmd_pretty -->\n");

format_items($q,$evts);

form($cfg,0,'','');
exit(0);

sub format_items
{
    my($q,$events) = @_;

    my $numEntries = scalar(@{$events});
    my @items;
    for (my $i = 0; $i < $numEntries; $i++)
    {
	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	
	next unless $subj eq 'Candle lighting';
	
	my($year) = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events->[$i]->[$Hebcal::EVT_IDX_MON];
	my($mday) = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my $stime = sprintf("%2d %s &nbsp;%d:%02d",
			    $mday, $Hebcal::MoY_short[$mon], $hour, $min);
	$stime =~ s/^ /&nbsp;/;
	push(@items, $stime);
    }

    Hebcal::out_html($cfg,qq{<p><table border="1" cellpadding="8"><tr>\n});

    my $third = int(scalar(@items) / 3);
    for (my $i = 0; $i < 3; $i++)
    {
	Hebcal::out_html($cfg,"<td>\n");
	for (my $j = 0; $j < $third; $j++)
	{
	    my $k = $j + ($third * $i);
	    Hebcal::out_html($cfg, "<tt>$items[$k]</tt>",
			     "<br>\n");
	}
	Hebcal::out_html($cfg,"</td>\n");
    }

    Hebcal::out_html($cfg,qq{</tr></table></p><p>&nbsp;</p>\n});
}

sub process_args
{
    my($q) = @_;

    # default setttings needed for cookie
    $q->param('c','on');

    my($cookies) = Hebcal::get_cookies($q);
    if (defined $cookies->{'C'})
    {
	Hebcal::process_cookie($q,$cookies->{'C'});
    }

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

    my($cmd)  = './hebcal -c -H';

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
	    form($cfg,1,
		  "Sorry, <b>" . $q->param('zip') . "</b> does\n" .
		  "not appear to be a 5-digit zip code.");
	}

	my $DB = Hebcal::zipcode_open_db();
	my($val) = $DB->{$q->param('zip')};
	Hebcal::zipcode_close_db($DB);
	undef($DB);

	form($cfg,1,
	      "Sorry, can't find\n".  "<b>" . $q->param('zip') .
	      "</b> in the zip code database.\n",
	      "<ul><li>Please try a nearby zip code</li></ul>")
	    unless defined $val;

	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    Hebcal::zipcode_fields($val);

	# allow CGI args to override
	$tz = $q->param('tz')
	    if (defined $q->param('tz') && $q->param('tz') =~ /^-?\d+$/);

	$city_descr = "$city, $state";

	if ($tz eq '?')
	{
	    $q->param('tz_override', '1');

	    form($cfg,1,
		  "Sorry, can't auto-detect\n" .
		  "timezone for <b>" . $city_descr . "</b>\n" .
		  "<ul><li>Please select your time zone below.</li></ul>");
	}

	$q->param('tz', $tz);

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

    my(@events) = Hebcal::invoke_hebcal($cmd, '', 0);
    
    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename

    (\@events,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty);
}

sub form
{
    my($cfg,$head,$message,$help) = @_;

    if ($head)
    {
	print "Cache-Control: private\015\012";
	print $q->header(),
	Hebcal::start_html($q, '1-Click Shabbat', undef, undef, undef);

	print Hebcal::navbar2($q, "1-Click Shabbat", 1, undef, undef),
	"<h1>1-Click\nShabbat Candle Lighting Times</h1>\n";
    }

    Hebcal::out_html($cfg, qq{<div class="goto">\n});

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help;
    }

    Hebcal::out_html($cfg,
	qq{$message\n},
	qq{<hr noshade size="1"><h3><a name="change">Change City</a></h3>\n},
	qq{<table cellpadding="8"><tr><td class="box">\n},
	qq{<h4>Zip Code</h4>\n},
	qq{<form name="f1" id="f1"\naction="$script_name">},
	qq{<label for="zip">Zip code:\n},
	$q->textfield(-name => 'zip',
		      -id => 'zip',
		      -size => 5,
		      -maxlength => 5),
	qq{</label>});

    if ($q->param('geo') eq 'pos' || $q->param('tz_override'))
    {
	Hebcal::out_html($cfg,
	qq{&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor="tz">Time zone:\n},
	$q->popup_menu(-name => 'tz',
		       -id => 'tz',
		       -values => ['auto',-5,-6,-7,-8,-9,-10],
		       -default => 'auto',
		       -labels => \%Hebcal::tz_names),
	qq{</label><br>Daylight Saving Time:\n},
	$q->radio_group(-name => 'dst',
			-values => ['usa','none'],
			-default => 'usa',
			-labels =>
			{'usa' => "\nUSA (except AZ, HI, and IN) ",
			 'none' => "\nnone ", }));
    }
    
    Hebcal::out_html($cfg,
	$q->hidden(-name => 'geo',
		   -value => 'zip',
		   -override => 1),
	qq{<br><input\ntype="submit" value="Get Shabbat Times"></form>});


    Hebcal::out_html($cfg,
	qq{</td><td>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td><td class="box">\n},
	qq{<h4>Major City</h4>},
	qq{<form name="f2" id="f2"\naction="$script_name">},
	qq{<label\nfor="city">Closest City:\n},
	$q->popup_menu(-name => 'city',
		       -id => 'city',
		       -values => [sort keys %Hebcal::city_tz],
		       -default => 'Jerusalem'),
	qq{</label>},
	$q->hidden(-name => 'geo',
		   -value => 'city',
		   -override => 1),
	qq{<br><input\ntype="submit" value="Get Shabbat Times"></form>},
	qq{</td></tr></table>});

    Hebcal::out_html($cfg,Hebcal::html_footer($q,$rcsrev));

    Hebcal::out_html($cfg, qq{</div>\n});

    exit(0);
}

# local variables:
# mode: perl
# end:
