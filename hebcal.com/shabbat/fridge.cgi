#!/usr/local/bin/perl -w

########################################################################
# Refrigerator candle-lighting times.  1 page for entire year.
#
# Copyright (c) 2005  Michael J. Radwin.
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
use Time::Local ();
use Hebcal ();
use POSIX ();

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

my $numEntries = scalar(@{$evts});
Hebcal::out_html($cfg,
		 qq{<center><h3>Candle Lighting Times for $city_descr<br>\nHebrew Year $hebrew_year ($evts->[0]->[$Hebcal::EVT_IDX_YEAR] - $evts->[$numEntries-1]->[$Hebcal::EVT_IDX_YEAR])</h3>\n});
    
Hebcal::out_html($cfg,"<!-- $cmd_pretty -->\n");

format_items($q,$evts);
Hebcal::out_html($cfg,"</center>\n</body>\n</html>\n");

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

	my $time = Time::Local::timelocal(1,0,0,$mday,$mon,$year - 1900,'','','');
	my $wday = (localtime($time))[6];
	if ($wday != 5)
	{
	    $stime = "<b>$stime</b>";
	}

	$stime = "<tt>$stime</tt><br>\n";
	push(@items, $stime);
    }

    Hebcal::out_html($cfg,qq{<p><table border="1" cellpadding="8"><tr>\n});

    my $third = POSIX::ceil(scalar(@items) / 3.0);
    for (my $i = 0; $i < 3; $i++)
    {
	Hebcal::out_html($cfg,"<td valign=\"top\">\n");
	for (my $j = 0; $j < $third; $j++)
	{
	    my $k = $j + ($third * $i);
	    Hebcal::out_html($cfg, $items[$k]) if $items[$k];
	}

	if ($i == 2)
	{
	    for (my $k = ($third * 3); $k < scalar(@items); $k++)
	    {
		Hebcal::out_html($cfg, $items[$k]) if $items[$k];
	    }
	}
	Hebcal::out_html($cfg,"</td>\n");
    }

    Hebcal::out_html($cfg,qq{</tr></table>\n});

    Hebcal::out_html($cfg,"<p><a class=\"goto\" title=\"Previous\" href=\"",
		     Hebcal::self_url($q, {'year' => $hebrew_year - 1}),
		     "\">&laquo;&nbsp;", $hebrew_year - 1,
		     "</a>&nbsp;&nbsp;&nbsp;",
		     "Times in <b>bold</b> indicate holidays.",
		     "&nbsp;&nbsp;&nbsp;<a class=\"goto\" title=\"Next\" href=\"",
		     Hebcal::self_url($q, {'year' => $hebrew_year + 1}),
		     "\">", $hebrew_year + 1, "&nbsp;&raquo;</a>",
		     "</p>\n");
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
	    $q->param('zip', 90210);
	}

	my $DB = Hebcal::zipcode_open_db();
	my($val) = $DB->{$q->param('zip')};
	Hebcal::zipcode_close_db($DB);
	undef($DB);

	unless (defined $val) {
	    print "Status: 400 Bad Request\r\n",
	    "Content-Type: text/plain\r\n\r\n",
	    "Can't find zip code ", $q->param('zip'), " in the DB.\n";
	    exit(0);
	}

	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	    Hebcal::zipcode_fields($val);

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

    $cmd .= " " . $q->param('year')
	if (defined $q->param('year') && $q->param('year') =~ /^\d+$/);

    my(@events) = Hebcal::invoke_hebcal($cmd, '', 0);
    
    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename

    (\@events,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty);
}

# local variables:
# mode: perl
# end:
