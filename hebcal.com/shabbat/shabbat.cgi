#!/usr/local/bin/perl5 -w

########################################################################
# 1-Click Shabbat generates weekly Shabbat candle lighting times and
# Parsha HaShavua from Hebcal information.
#
# Copyright (c) 2001  Michael J. Radwin.  All rights reserved.
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
use strict;

my($author) = 'webmaster@hebcal.com';
my($expires_date) = 'Thu, 15 Apr 2010 20:00:00 GMT';

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($hhmts) = "<!-- hhmts start -->
Last modified: Mon May  7 10:38:40 PDT 2001
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated:\n/g;

my($html_footer) = "<hr
noshade size=\"1\"><font size=-2 face=Arial>Copyright
&copy; $this_year Michael J. Radwin. All rights reserved.
<a href=\"/privacy/\">Privacy Policy</a> -
<a href=\"/help/\">Help</a>
<br>$hhmts ($rcsrev)
</font></body></html>
";

my($inline_style) = '';
#my($inline_style) = qq[<style type="text/css">
#<!--
#.boxed { border-style: solid;
#border-color: #666666;
#border-width: thin;
#padding: 8px; }
#-->
#</style>];

# process form params
my($q) = new CGI;

# default setttings needed for cookie
$q->param('c','on');
$q->param('nh','on');
$q->param('nx','on');

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;
my($server_name) = $q->virtual_host();
$server_name =~ s/^www\.//;

$q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		"\t\"http://www.w3.org/TR/html4/loose.dtd");

if (defined $q->raw_cookie() &&
    $q->raw_cookie() =~ /[\s;,]*C=([^\s,;]+)/)
{
    &Hebcal::process_cookie($q,$1);
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

my($now) = time;
if (defined $q->param('t') && $q->param('t') =~ /^\d+$/)
{
    $now = $q->param('t');
}

my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;

my($friday) = &Time::Local::timelocal(0,0,0,
				      $mday,$mon,$year,$wday,$yday,$isdst);
my($saturday) = $now + ((6 - $wday) * 60 * 60 * 24);

my($sat_year) = (localtime($saturday))[5] + 1900;
my($cmd)  = './hebcal';

my($default) = 0;
my($city_descr,$dst_descr,$tz_descr);
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

    my($dbmfile) = 'zips.db';
    my(%DB);
    tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	|| die "Can't tie $dbmfile: $!\n";

    my($val) = $DB{$q->param('zip')};
    untie(%DB);

    &form(1,
	  "Sorry, can't find\n".  "<b>" . $q->param('zip') .
	  "</b> in the zip code database.\n",
          "<ul><li>Please try a nearby zip code</li></ul>")
	unless defined $val;

    my($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    my($city,$state) = split(/\0/, substr($val,6));

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
	my($ok) = 0;
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

foreach (@Hebcal::opts)
{
    $cmd .= ' -' . $_
	if defined $q->param($_) && $q->param($_) =~ /^on|1$/;
}

$cmd .= ' -s -c ' . $sat_year;

unless ($default)
{
    my($cookie_to_set);

    if (! defined $q->raw_cookie())
    {
	$cookie_to_set = &Hebcal::gen_cookie($q)
	    unless $q->param('noset');
    }
    else
    {
	my($newcookie) = &Hebcal::gen_cookie($q);
	my($cmp1) = $newcookie;
	my($cmp2) = $q->raw_cookie();

	$cmp1 =~ s/\bC=t=\d+\&//;
	$cmp2 =~ s/\bC=t=\d+\&//;

	$cookie_to_set = $newcookie 
	    if ($cmp1 ne $cmp2 && ! $q->param('noset'));
    }

    print STDOUT "Set-Cookie: ", $cookie_to_set,
    "; path=/; expires=",  $expires_date, "\015\012"
	if $cookie_to_set;
	    
    print STDOUT "Expires: ",
    strftime("%a, %d %b %Y %T GMT", gmtime($saturday)), "\015\012"
	if (defined $q->param('cfg') && $q->param('cfg') =~ /^[ij]$/);
}

my($title) = "1-Click Shabbat for $city_descr";
$title =~ s/ &nbsp;/ /;

if (defined $q->param('cfg') && $q->param('cfg') =~ /^[ijr]$/)
{
    if ($q->param('cfg') =~ /^[ij]$/)
    {
	&my_header($title, '');

	my($url) = $q->url();
	$url =~ s,/index.html$,/,;

	&out_html("<h3><a target=\"_top\"\nhref=\"$url\">1-Click\n",
		  "Shabbat</a> for $city_descr</h3>\n");
    }
    else
    {
	$title = '1-Click Shabbat: ' . $q->param('zip');
	&my_header($title, '');

	&out_html("<?xml version=\"1.0\"?>
<!DOCTYPE rss PUBLIC \"-//Netscape Communications//DTD RSS 0.91//EN\"
\t\"http://my.netscape.com/publish/formats/rss-0.91.dtd\">
<rss version=\"0.91\">
<channel>
<title>$title</title>
");
	&out_html("<link>http://", $q->server_name(), $script_name,
		  "?zip=", $q->param('zip'), "&amp;dst=", $q->param('dst'));
	&out_html("&amp;tz=", $q->param('tz'))
	    if (defined $q->param('tz') && $q->param('tz') ne 'auto');
	&out_html("&amp;m=", $q->param('m'))
	    if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);
	&out_html("</link>\n<description>Weekly Shabbat candle lighting\n",
		  "times for $city_descr</description>\n",
		  "<language>en-us</language>\n");
	&out_html("<copyright>Copyright &copy; $this_year Michael J. Radwin.",
		  " All rights reserved.</copyright>\n");
    }
}
else
{
    &my_header($title, $inline_style);

    &out_html("<h2>$city_descr</h2>\n");

    if (defined $dst_descr && defined $tz_descr)
    {
	&out_html("&nbsp;&nbsp;$dst_descr\n<br>&nbsp;&nbsp;$tz_descr\n");
    }

    if ($city_descr =~ / IN &nbsp;/)
    {
	&out_html("<p><font color=\"#ff0000\">",
	"Indiana has confusing time zone &amp;\n",
	"Daylight Saving Time rules.</font>\n",
	"You might want to read <a\n",
	"href=\"http://www.mccsc.edu/time.html\">What time is it in\n",
	"Indiana?</a> to make sure the above settings are\n",
	"correct.</p>");
    }
}

my($cmd_pretty) = $cmd;
$cmd_pretty =~ s,.*/,,; # basename
&out_html("<!-- $cmd_pretty -->\n");

my($loc) = (defined $city_descr && $city_descr ne '') ?
    "in $city_descr" : '';
$loc =~ s/\s*&nbsp;\s*/ /g;

my(@events) = &Hebcal::invoke_hebcal($cmd, $loc);

unless (defined $q->param('cfg') && $q->param('cfg') eq 'r')
{
#    &out_html(qq{<p>Today is }, strftime("%A, %d %B %Y", localtime($now)),
#	      qq{.</p>\n<p>\n});
    &out_html('<p>');
}

my($numEntries) = scalar(@events);
my($i);
for ($i = 0; $i < $numEntries; $i++)
{
    # holiday is at 12:00:01 am
    my($time) = &Time::Local::timelocal(1,0,0,
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
	if (defined $q->param('cfg') && $q->param('cfg') eq 'r')
	{
	    my($link) = &ycal($subj,$year,$mon,$mday,$min,$hour,
			      $events[$i]->[$Hebcal::EVT_IDX_UNTIMED],
			      $events[$i]->[$Hebcal::EVT_IDX_DUR]);

	    &out_html("<item>\n");
	    &out_html(sprintf("<title>%s: %d:%02d PM</title>\n",
			      $subj, $hour, $min));
	    &out_html("<link>$link</link>\n");
	    &out_html("<description>",
		      strftime("%A, %d %B", localtime($time)),
		      "</description>\n");
	    &out_html("</item>\n");
	}
	else
	{
	    &out_html(qq{$subj for\n}, 
		      strftime("%A, %d %B", localtime($time)));
	    &out_html(sprintf("\nis at <b>%d:%02d PM</b>.<br>\n",
			      $hour, $min));
	}
    }
    else
    {
	&out_html("<item>\n<title>")
	    if (defined $q->param('cfg') && $q->param('cfg') eq 'r');
	if ($subj =~ /^(Parshas\s+|Parashat\s+)(.+)/)
	{
	    &out_html("This week's Torah portion is ");
	}
	else
	{
	    &out_html("Holiday: ");
	}

	my($href,$hebrew,$memo,$torah_href,$haftarah_href)
	    = &Hebcal::get_holiday_anchor($subj,0,$q);

	if ($href ne '' &&
	    !(defined $q->param('cfg') && $q->param('cfg') eq 'r'))
	{

	    if (defined $torah_href && $torah_href ne '')
	    {
		&out_html(qq{<b>$subj</b>\n(<a href="$href">Drash</a>\n} .
		    qq{- <a href="$torah_href">Torah</a>\n} .
		    qq{- <a href="$haftarah_href">Haftarah</a>)});
	    }
	    elsif ($href ne '')
	    {
		&out_html(qq{<a href="$href">$subj</a>});
	    }
	}
	else
	{
	    &out_html($subj);
	}

	# output day if it's a holiday
	if ($subj !~ /^(Parshas\s+|Parashat\s+)/)
	{
	    &out_html(" on ", strftime("%A, %d %B", localtime($time)));
	}

	if (defined $q->param('cfg') && $q->param('cfg') eq 'r')
	{
	    &out_html("</title>\n<link>");
	    if ($href ne '')
	    {
		&out_html($href);
	    }
	    elsif ($subj =~ /^(Parshas\s+|Parashat\s+)/)
	    {
		&out_html("http://learn.jtsa.edu/topics/parashah/");
	    }
	    else
	    {
		&out_html("http://www.vjholidays.com/");
	    }
	    &out_html("</link>\n</item>\n");
	}
	else
	{
	    &out_html(".<br>\n");
	}
    }
}

&out_html("</p>\n")
    unless (defined $q->param('cfg') && $q->param('cfg') eq 'r');

if (defined $q->param('cfg') && $q->param('cfg') =~ /^[ijr]$/)
{
    if ($q->param('cfg') eq 'i')
    {
	&out_html("</body></html>\n");
    }
    elsif ($q->param('cfg') eq 'r')
    {
	&out_html("<textinput>
<title>1-Click Shabbat</title>
<description>Get Shabbat Times for another zip code</description>
<name>zip</name>
");
	&out_html("<link>http://", $q->server_name(), $script_name,
		  "</link>\n</textinput>\n");
	&out_html("</channel>\n</rss>\n");
    }
}
else
{
    &form(0,'','');
    &out_html($html_footer);
}

close(STDOUT);
exit(0);

sub ycal
{
    my($subj,$year,$mon,$mday,$min,$hour,$untimed,$dur) = @_;

    my($ST) = sprintf("%04d%02d%02d", $year, $mon, $mday);
    if ($untimed == 0)
    {
	my($loc) = (defined $city_descr && $city_descr ne '') ?
	    "in $city_descr" : '';
	$loc =~ s/\s*&nbsp;\s*/ /g;

	$ST .= sprintf("T%02d%02d00",
		       ($hour < 12 && $hour > 0) ? $hour + 12 : $hour,
		       $min);

	if ($q->param('tz') ne '')
	{
	    my($abstz) = ($q->param('tz') >= 0) ?
		$q->param('tz') : -$q->param('tz');
	    my($signtz) = ($q->param('tz') < 0) ? '-' : '';

	    $ST .= sprintf("Z%s%02d00", $signtz, $abstz);
	}

	$ST .= "&amp;DUR=00" . $dur;

	$ST .= "&amp;DESC=" . &Hebcal::url_escape($loc)
	    if $loc ne '';
    }

    "http://calendar.yahoo.com/?v=60&amp;TITLE=" .
	&Hebcal::url_escape($subj) . "&amp;TYPE=16&amp;ST=" . $ST;
}

sub out_html
{
    my(@args) = @_;

    if (defined $q->param('cfg') && $q->param('cfg') eq 'j')
    {
	print STDOUT "document.write(\"";
	foreach (@args)
	{
	    s/\"/\\\"/g;
	    s/\n/\\n/g;
	    print STDOUT;
	}
	print STDOUT "\");\n";
    }
    else
    {
	foreach (@args)
	{
	    print STDOUT;
	}
    }

    1;
}

sub my_header
{
    my($title,$inline_style) = @_;

    if (defined $q->param('cfg') && $q->param('cfg') eq 'j')
    {
	print STDOUT "Content-Type: application/x-javascript\015\012\015\012";
    }
    elsif (defined $q->param('cfg') && $q->param('cfg') eq 'r')
    {
	print STDOUT "Content-Type: text/xml\015\012\015\012";
    }
    else
    {
	&out_html($q->header(),
    $q->start_html(-title => $title,
		   -target => '_top',
		   -head => [
			     "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true for \"http://www.$server_name\" r (n 0 s 0 v 0 l 0))'>",
			     $q->Link({-rel => 'stylesheet',
				       -href => '/style.css',
				       -type => 'text/css'}),
			     $q->Link({-rel => 'p3pv1',
				       -href => "http://www.$server_name/w3c/p3p.xml"}),
#			     $inline_style,
			     ],
		   ));
    }

    unless (defined $q->param('cfg') && $q->param('cfg') =~ /^[ijr]$/)
    {
	&out_html(&Hebcal::navbar($server_name,'1-Click Shabbat',1),
		  "<h1>1-Click\nShabbat</h1>\n");
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
	    $message . "</font></p>" . $help;
    }

    &out_html(
	qq{$message\n},
	qq{<hr noshade size=\"1\"><h3>Change City</h3>\n},
	qq{<form\naction="$script_name">},
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
		   -override => 1),
	"<br><label\nfor=\"m1\">Havdalah minutes past sundown:\n",
	$q->textfield(-name => 'm',
		      -id => 'm1',
		      -size => 3,
		      -maxlength => 3,
		      -default => 72),
	"</label>",
	qq{<br><input\ntype="submit" value="Get Shabbat Times"></form>});


    &out_html(
	qq{<b>(or select by major city</b>)<br>},
	qq{<form\naction="$script_name">},
	qq{<label\nfor="city">Closest City:\n},
	$q->popup_menu(-name => 'city',
		       -id => 'city',
		       -values => [sort keys %Hebcal::city_tz],
		       -default => 'Jerusalem'),
	qq{</label>},
	$q->hidden(-name => 'geo',
		   -value => 'city',
		   -override => 1),
	"<br><label\nfor=\"m2\">Havdalah minutes past sundown:\n",
	$q->textfield(-name => 'm',
		      -id => 'm2',
		      -size => 3,
		      -maxlength => 3,
		      -default => 72),
	"</label>",
	qq{<br><input\ntype="submit" value="Get Shabbat Times"></form>});

    &out_html(
	qq{<hr noshade size=\"1\">\n},
	qq{<p><a href="/help/#tags">How\n},
	qq{can my synagogue put 1-Click Shabbat candle-lighting\n},
	qq{times on its own website?</a></p>});

    &out_html($html_footer);

    exit(0);
}
