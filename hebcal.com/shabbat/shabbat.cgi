#!/usr/local/bin/perl5 -w

########################################################################
# 1-Click Shabbat generates weekly Shabbat candle lighting times and
# Parsha HaShavua from Hebcal information.
#
# Copyright (c) 2000  Michael John Radwin.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
########################################################################

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;
use Hebcal;
use POSIX qw(strftime);

$author = 'michael@radwin.org';
$expires_date = 'Thu, 15 Apr 2010 20:00:00 GMT';

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($hhmts) = "<!-- hhmts start -->
Last modified: Wed Nov  8 08:58:14 PST 2000
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated:\n/g;

$html_footer = "<hr
noshade size=\"1\"><small>$hhmts ($rcsrev)<br><br>Copyright
&copy; $this_year <a href=\"/michael/contact.html\">Michael J. Radwin</a>.
All rights reserved.</small></body></html>
";

my($inline_style) = qq[<style type="text/css">
<!--
.boxed { border-style: solid;
border-color: #666666;
border-width: thin;
padding: 8px; }
-->
</style>];

# process form params
$q = new CGI;

# default setttings needed for cookie
$q->param('c','on');
$q->param('nh','on');
$q->param('nx','on');

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;
my($server_name) = $q->server_name();
$server_name =~ s/^www\.//;

$q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		"\t\"http://www.w3.org/TR/html4/loose.dtd");

if (defined $q->raw_cookie() &&
    $q->raw_cookie() =~ /[\s;,]*C=([^\s,;]+)/)
{
    &process_cookie($q,$1);
}

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
my($key);
foreach $key ($q->param())
{
    $val = $q->param($key);
    $val =~ s/[^\w\s-]//g;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

my($now) = time;
if (defined $q->param('t') && $q->param('t') =~ /^\d+$/)
{
    $now = $q->param('t');
}

my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;
#$friday = $now + ((4 - $wday) * 60 * 60 * 24);
$friday = &Time::Local::timelocal(0,0,0,$mday,$mon,$year,$wday,$yday,$isdst);
$saturday = $now + ((6 - $wday) * 60 * 60 * 24);

$sat_year = (localtime($saturday))[5] + 1900;
$cmd  = '/home/users/mradwin/bin/hebcal';

my($default) = 0;
if (defined $q->param('city'))
{
    unless (defined($Hebcal::city_tz{$q->param('city')}))
    {
	$q->param('city','New York');
	$default = 1;
    }

    $q->param('geo','city');
    $q->delete('tz');
    $q->delete('dst');

    $cmd .= " -C '" . $q->param('city') . "'";

    $city_descr = $q->param('city');
}
elsif (defined $q->param('zip') && $q->param('zip') ne '')
{
    $q->param('dst','usa')
	unless $q->param('dst');
    $q->param('tz','auto')
	unless $q->param('tz');
    $q->param('geo','zip');

    if ($q->param('zip') !~ /^\d{5}$/)
    {
	&form(1,
	      "Sorry, <b>" . $q->param('zip') . "</b> does\n" .
	      "not appear to be a 5-digit zip code.");
    }

    $dbmfile = 'zips.db';
    tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	|| die "Can't tie $dbmfile: $!\n";

    $val = $DB{$q->param('zip')};
    untie(%DB);

    &form(1,
	  "Sorry, can't find\n".  "<b>" . $q->param('zip') .
	  "</b> in the zip code database.\n",
          "<ul><li>Please try a nearby zip code</li></ul>")
	unless defined $val;

    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));

    if (($state eq 'HI' || $state eq 'AZ') &&
	$q->param('dst') eq 'usa')
    {
	$q->param('dst','none');
    }

    my(@city) = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = lc($_);
	$_ = "\u$_";		# inital cap
	$city .= $_;
    }

    $city_descr = "$city, $state &nbsp;" . $q->param('zip');

    if ($q->param('tz') !~ /^-?\d+$/)
    {
	$ok = 0;
	if (defined $Hebcal::known_timezones{$q->param('zip')})
	{
	    if ($Hebcal::known_timezones{$q->param('zip')} ne '??')
	    {
		$q->param('tz',$Hebcal::known_timezones{$q->param('zip')});
		$ok = 1;
	    }
	}
	elsif (defined $Hebcal::known_timezones{substr($q->param('zip'),0,3)})
	{
	    if ($Hebcal::known_timezones{substr($q->param('zip'),0,3)} ne '??')
	    {
		$q->param('tz',$Hebcal::known_timezones{substr($q->param('zip'),0,3)});
		$ok = 1;
	    }
	}
	elsif (defined $Hebcal::known_timezones{$state})
	{
	    if ($Hebcal::known_timezones{$state} ne '??')
	    {
		$q->param('tz',$Hebcal::known_timezones{$state});
		$ok = 1;
	    }
	}

	if ($ok == 0)
	{
	    &form(1,
		  "Sorry, can't auto-detect\n" .
		  "timezone for <b>" . $city_descr . "</b>\n".
		  "(state <b>" . $state . "</b> spans multiple time zones).",
		  "<ul><li>Please select your time zone below.</li></ul>");
	}
    }

    $dst_descr = "Daylight Saving Time: " . $q->param('dst');
    $tz_descr = "Time zone: " . $Hebcal::tz_names{$q->param('tz')};

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}
else
{
    $q->param('city','New York');
    $q->param('geo','city');
    $q->delete('tz');
    $q->delete('dst');

    $cmd .= " -C '" . $q->param('city') . "'";

    $city_descr = $q->param('city');
    $default = 1;
}

$cmd .= " -z " . $q->param('tz')
    if (defined $q->param('tz') && $q->param('tz') ne '');

$cmd .= " -Z " . $q->param('dst')
    if (defined $q->param('dst') && $q->param('dst') ne '');

$cmd .= " -m " . $q->param('m')
    if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

$cmd .= " -a"
    if defined $q->param('a') &&
    ($q->param('a') eq 'on' || $q->param('a') eq '1');

$cmd .= ' -s -c ' . $sat_year;

unless ($default)
{
    my($newcookie) = &gen_cookie($q);
    if (! defined $q->raw_cookie())
    {
	print STDOUT "Set-Cookie: ", $newcookie, "; expires=",
	$expires_date, "; path=/\015\012";
    }
    else
    {
	my($cmp1) = $newcookie;
	my($cmp2) = $q->raw_cookie();

	$cmp1 =~ s/\bC=t=\d+\&//;
	$cmp2 =~ s/\bC=t=\d+\&//;

	print STDOUT "Set-Cookie: ", $newcookie, "; expires=",
	$expires_date, "; path=/\015\012"
	    if $cmp1 ne $cmp2;
    }
}

my($title) = "1-Click Shabbat for $city_descr";
$title =~ s/ &nbsp;/ /;

if (defined $q->param('cfg') && $q->param('cfg') eq 'i')
{
    &my_header($title, '');

    print STDOUT "<h3><a target=\"_top\" href=\"/shabbat/\">1-Click\n",
	"Shabbat</a> for $city_descr</h3>\n";
}
else
{
    &my_header($title, $inline_style);

    print STDOUT "<h2>$city_descr</h2>\n";

    if (defined $dst_descr && defined $tz_descr)
    {
	print STDOUT "&nbsp;&nbsp;$dst_descr\n<br>&nbsp;&nbsp;$tz_descr\n";
    }

    if ($city_descr =~ / IN &nbsp;/)
    {
	print STDOUT "<p><font color=\"#ff0000\">",
	"Indiana has confusing time zone &amp;\n",
	"Daylight Saving Time rules.</font>\n",
	"You might want to read <a\n",
	"href=\"http://www.mccsc.edu/time.html\">What time is it in\n",
	"Indiana?</a> to make sure the above settings are\n",
	"correct.</p>";
    }
}

my($cmd_pretty) = $cmd;
$cmd_pretty =~ s,.*/,,; # basename
print STDOUT "<!-- $cmd_pretty -->\n";

my($loc) = (defined $city_descr && $city_descr ne '') ?
    "in $city_descr" : '';
$loc =~ s/\s*&nbsp;\s*/ /g;

my(@events) = &invoke_hebcal($cmd, $loc);

print STDOUT qq{<p>Today is }, strftime("%A, %d %B %Y", localtime($now)),
    qq{.</p>\n<p>\n};

my($numEntries) = scalar(@events);
my($i);
for ($i = 0; $i < $numEntries; $i++)
{
    # holiday is at 12:00:01 am
    $time = &Time::Local::timelocal(1,0,0,
		       $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events[$i]->[$Hebcal::EVT_IDX_MON],
		       $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
    next if $time < $friday || $time > $saturday;

    my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
    my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
    my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
    my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

    my($min) = $events[$i]->[$Hebcal::EVT_IDX_MIN];
    my($hour) = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
    $hour -= 12 if $hour > 12;

    if ($subj eq 'Candle lighting' || $subj =~ /Havdalah/)
    {
	print STDOUT qq{$subj for\n}, 
	    strftime("%A, %d %B", localtime($time));
	printf STDOUT ("\nis at <b>%d:%02d PM</b>.<br>\n", $hour, $min);
    }
    else
    {
	if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)/)
	{
	    print STDOUT "This week's Torah portion is\n";
	}
	else
	{
	    print STDOUT "Holiday:\n";
	}

	my($href) = &get_holiday_anchor($subj);
	if ($href ne '')
	{
	    print STDOUT qq{<a href="$href">$subj</a>};
	}
	else
	{
	    print STDOUT $subj;
	}

	# output day if it's a holiday
	if ($subj !~ /^(Parshas\s+|Parashat\s+)/)
	{
	    print STDOUT "\non ", strftime("%A, %d %B", localtime($time));
	}

	print STDOUT ".<br>\n";
    }
}

print STDOUT "</p>\n";
if (! defined $q->param('cfg') || $q->param('cfg') ne 'i')
{
    &form(0,'','');
    print STDOUT $html_footer;
}

close(STDOUT);
exit(0);

sub my_header
{
    my($title,$inline_style) = @_;

    print STDOUT $q->header(),
    $q->start_html(-title => $title,
		   -target => '_top',
		   -head => [
			     "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			     $q->Link({-rel => 'stylesheet',
				       -href => '/style.css',
				       -type => 'text/css'}),
			     $inline_style,
			     ],
		   -meta => {'robots' => 'noindex'});

    unless (defined $q->param('cfg') && $q->param('cfg') eq 'i')
    {
	print STDOUT
	    "<table width=\"100%\"\nclass=\"navbar\">",
	    "<tr><td><small>",
	    "<strong><a\nhref=\"/\">", $server_name, "</a></strong>\n",
	    "<tt>-&gt;</tt>\n",
	    "1-Click Shabbat</small></td>",
	    "<td align=\"right\"><small><a\n",
	    "href=\"/search/\">Search</a></small>",
	    "</td></tr></table>",
	    "<h1>1-Click\nShabbat</h1>\n";
    }

    1;
}

sub form
{
    my($head,$message,$help) = @_;

    &my_header('1-Click Shabbat', $inline_style) if $head;

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">";
    }


    print STDOUT
	qq{$message\n},
	qq{<table><tr><td class="boxed"><form\naction="$script_name">},
	qq{<label for="zip">Zip code:\n},
	$q->textfield(-name => 'zip',
		      -id => 'zip',
		      -size => 5,
		      -maxlength => 5),
	qq{</label>&nbsp;&nbsp;&nbsp;&nbsp;<label\nfor="tz">Time zone:\n},
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
			 'israel' => "\nIsrael ",
			 'none' => "\nnone ", }),
	$q->hidden(-name => 'geo',
		   -value => 'zip',
		   -override => 1);

    print STDOUT
	qq{<br><input\ntype="submit" value="Get Shabbat Times"></form>},
	qq{</td>\n<td>&nbsp;or&nbsp;</td>\n},
	qq{<td class="boxed"><form\naction="$script_name">},
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
	qq{</td></tr></table>};

    print STDOUT $html_footer;

    exit(0);
}
