#!/usr/local/bin/perl -w

########################################################################
# 1-Click Shabbat generates weekly Shabbat candle lighting times and
# Parsha HaShavua from Hebcal information.
#
# Copyright (c) 2002  Michael J. Radwin.  All rights reserved.
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

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;
use Hebcal;
use POSIX qw(strftime);
use strict;

my($expires_date) = 'Thu, 15 Apr 2010 20:00:00 GMT';

my($this_mon,$this_year) = (localtime)[4,5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'

# process form params
my($q) = new CGI;

$q->param('cfg', 'w')
    if (defined $ENV{'HTTP_ACCEPT'} &&
	$ENV{'HTTP_ACCEPT'} =~ /text\/vnd\.wap\.wml/);

my($cfg) = $q->param('cfg');

if (defined $cfg && $cfg eq 'w')
{
    my $dbmfile = 'wap.db';
    my %DB;
    my($user) = $ENV{'HTTP_X_UP_SUBNO'};

    $q->param('noset', 1);

    if (defined $user &&
	defined $q->param('zip') && $q->param('zip') =~ /^\d{5}$/)
    {
	tie(%DB, 'DB_File', $dbmfile, O_RDWR|O_CREAT, 0644, $DB_File::DB_HASH)
	    || die "Can't tie $dbmfile: $!\n";
	my($val) = $DB{$user};
	if (defined $val)
	{
	    my($c) = new CGI($val);
	    $c->param('zip', $q->param('zip'));
	    $DB{$user} = $c->query_string();
	}
	else
	{
	    $DB{$user} = 'zip=' . $q->param('zip');
	}
	untie(%DB);
    }
    elsif (defined $user && !defined $q->param('zip'))
    {
	tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	    || die "Can't tie $dbmfile: $!\n";
	my($val) = $DB{$user};
	untie(%DB);

	if (defined $val)
	{
	    my($c) = new CGI($val);
	    if (defined $c->param('zip'))
	    {
		$q->param('zip', $c->param('zip'));
		$q->param('geo', 'zip');
	    }
	}
    }
}

# default setttings needed for cookie
$q->param('c','on');
$q->param('nh','on');
$q->param('nx','on');

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;

my($cookies) = &Hebcal::get_cookies($q);
if (defined $cookies->{'C'})
{
    &Hebcal::process_cookie($q,$cookies->{'C'});
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

my($saturday) = ($wday == 6) ?
    $now + (60 * 60 * 24) :
    $now + ((6 - $wday) * 60 * 60 * 24);

my($sat_year) = (localtime($saturday))[5] + 1900;
my($cmd)  = './hebcal';

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
}
elsif (defined $q->param('zip') && $q->param('zip') ne '')
{
    $q->param('dst','usa')
	unless $q->param('dst');
    $q->param('tz','auto')
	unless $q->param('tz');
    $q->param('geo','zip');
    $q->delete('city');

    if ($q->param('zip') !~ /^\d{5}$/)
    {
	&form(1,
	      "Sorry, <b>" . $q->param('zip') . "</b> does\n" .
	      "not appear to be a 5-digit zip code.");
    }

    my $DB = &Hebcal::zipcode_open_db();
    my($val) = $DB->{$q->param('zip')};
    &Hebcal::zipcode_close_db($DB);
    undef($DB);

    &form(1,
	  "Sorry, can't find\n".  "<b>" . $q->param('zip') .
	  "</b> in the zip code database.\n",
          "<ul><li>Please try a nearby zip code</li></ul>")
	unless defined $val;

    my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state) =
	&Hebcal::zipcode_fields($val);

    # allow CGI args to override
    $tz = $q->param('tz')
	if (defined $q->param('tz') && $q->param('tz') =~ /^-?\d+$/);

    $city_descr = "$city, $state " . $q->param('zip');

    if ($tz eq '?')
    {
	$q->param('tz_override', '1');

	&form(1,
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
    $q->delete('zip');

    $cmd .= " -C '" . $q->param('city') . "'";

    $city_descr = $q->param('city');
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

# only set expiry if there are CGI arguments
if (defined $ENV{'QUERY_STRING'} && $ENV{'QUERY_STRING'} !~ /^\s*$/)
{
    print STDOUT "Expires: ", &Hebcal::http_date($saturday), "\015\012";

    my($cookie_to_set);

    my($C_cookie) = (defined $cookies->{'C'}) ?
	'C=' . $cookies->{'C'} : '';
    if (! $C_cookie)
    {
	$cookie_to_set = &Hebcal::gen_cookie($q)
	    unless $q->param('noset');
    }
    else
    {
	my($newcookie) = &Hebcal::gen_cookie($q);
	my($cmp1) = $newcookie;
	my($cmp2) = $C_cookie;

	$cmp1 =~ s/^C=t=\d+\&//;
	$cmp2 =~ s/^C=t=\d+\&//;

	$cookie_to_set = $newcookie 
	    if ($cmp2 ne 'opt_out' &&
		$cmp1 ne $cmp2 && ! $q->param('noset'));
    }

    print STDOUT "Set-Cookie: ", $cookie_to_set,
    "; path=/; expires=",  $expires_date, "\015\012"
	if $cookie_to_set && !$cfg;
}

my($title) = "1-Click Shabbat Candle Lighting Times for $city_descr";

if (defined $cfg && $cfg =~ /^[ijrw]$/)
{
    my($self_url) = join('', "http://", $q->virtual_host(), $script_name,
			 "?geo=", $q->param('geo'));

    $self_url .= ";zip=" . $q->param('zip')
	if $q->param('zip');
    $self_url .= ";city=" . &Hebcal::url_escape($q->param('city'))
	if $q->param('city');
    $self_url .= ";dst=" . $q->param('dst')
	if $q->param('dst');
    $self_url .= ";tz=" . $q->param('tz')
	if (defined $q->param('tz') && $q->param('tz') ne 'auto');
    $self_url .= ";m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    if (defined $ENV{'HTTP_REFERER'} && $ENV{'HTTP_REFERER'} !~ /^\s*$/)
    {
	$self_url .= ";.from=" . &Hebcal::url_escape($ENV{'HTTP_REFERER'});
    }
    elsif ($q->param('.from'))
    {
	$self_url .= ";.from=" . &Hebcal::url_escape($q->param('.from'));
    }

    if ($cfg eq 'j' &&
	$q->param('site') && $q->param('site') eq 'keshernj.com')
    {
	&my_header($title);

	&Hebcal::out_html($cfg,
			  "<font size=5><strong>", $city_descr, 
			  "</strong></font>\n",
			  "<br>$dst_descr\n",
			  "<br>$tz_descr\n",
			  );
    }
    elsif ($cfg =~ /^[ij]$/)
    {
	&my_header($title);

	&Hebcal::out_html($cfg,"<h3><a target=\"_top\"\nhref=\"$self_url\">1-Click\n",
		  "Shabbat</a> for $city_descr</h3>\n");
    }
    elsif ($cfg eq 'r')
    {
	$title = '1-Click Shabbat: ' . $q->param('zip');
	&my_header($title);

	&Hebcal::out_html($cfg,"<?xml version=\"1.0\"?>
<!DOCTYPE rss PUBLIC \"-//Netscape Communications//DTD RSS 0.91//EN\"
\t\"http://my.netscape.com/publish/formats/rss-0.91.dtd\">
<rss version=\"0.91\">
<channel>
<title>$title</title>
<link>$self_url</link>
<description>Weekly Shabbat candle lighting times for 
$city_descr</description>
<language>en-us</language>
<copyright>Copyright &copy; $this_year Michael J. Radwin. 
All rights reserved.</copyright>
");
    }
    elsif ($cfg eq 'w')
    {
	&my_header($title);
    }
}
else
{
    &my_header($title);

    &Hebcal::out_html($cfg,"<h3>$city_descr</h3>\n");

    if (defined $dst_descr && defined $tz_descr)
    {
	&Hebcal::out_html($cfg,"&nbsp;&nbsp;$dst_descr\n<br>&nbsp;&nbsp;$tz_descr\n");
    }

    &Hebcal::out_html($cfg,$Hebcal::indiana_warning)
	if ($city_descr =~ / IN /);
}

my($cmd_pretty) = $cmd;
$cmd_pretty =~ s,.*/,,; # basename
&Hebcal::out_html($cfg,"<!-- $cmd_pretty -->\n");

my($loc) = (defined $city_descr && $city_descr ne '') ?
    "in $city_descr" : '';

my(@events) = &Hebcal::invoke_hebcal($cmd, $loc);

unless (defined $cfg && $cfg =~ /^[rw]$/)
{
#    &Hebcal::out_html($cfg,qq{<p>Today is }, strftime("%A, %d %B %Y", localtime($now)),
#	      qq{.</p>\n<p>\n});
    &Hebcal::out_html($cfg,"<dl>");
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

    my(%rss);
    $rss{'description'} = strftime("%A, %d %B %Y", localtime($time));

    if ($subj eq 'Candle lighting' || $subj =~ /Havdalah/)
    {
	$rss{'title'} = sprintf("%s: %d:%02d PM", $subj, $hour, $min);
	if (defined $cfg && $cfg eq 'r')
	{
	    $rss{'link'} =
		&Hebcal::yahoo_calendar_link($events[$i], $city_descr);
	    &out_rss(\%rss);
	}
	elsif (defined $cfg && $cfg eq 'w')
	{
	    delete($rss{'description'});
	    $rss{'title'} =~ s/^Candle lighting/Candles/;
	    $rss{'title'} =~ s/ PM$/p/;
	    &out_wap(\%rss);
	}
	else
	{
	    &Hebcal::out_html($cfg,qq{\n<dt class="candles">$subj for\n},
		      $rss{'description'},
		      sprintf(" is at <b>%d:%02d PM</b>", $hour, $min));
	    &Hebcal::out_html($cfg,"</dt>");
	    &Hebcal::out_html($cfg,"<br>&nbsp;")
		if ($q->param('site') &&
		    $q->param('site') eq 'keshernj.com');
	}
    }
    else
    {
	if ($subj =~ /^(Parshas|Parashat)\s+/)
	{
	    $rss{'title'} =
		(defined $cfg && $cfg eq 'w') ?
		    'Torah: ' : "This week's Torah portion is ";
	}
	else
	{
	    $rss{'title'} = "Holiday: ";
	}

	my($href,$hebrew,$memo,$torah_href,$haftarah_href,$drash_href)
	    = &Hebcal::get_holiday_anchor($subj,0,$q);

	if ($drash_href =~
	    m,^(http://learn.jtsa.edu/topics/parashah)/(\d{4})/(.+),)
	{
	    my($drash_prefix,$drash_yr,$drash_html) = ($1,$2,$3);

	    # heuristic to guess the hebrew year
	    if ($this_mon < 8) {
		# jan 1 - aug 31
		$drash_yr = $this_year + 3760;
	    } elsif ($this_mon > 9) {
		# nov 1 - dec 31
		$drash_yr = $this_year + 3761;
	    } elsif ($memo =~ /Torah: Genesis/) {
		$drash_yr = $this_year + 3761;
	    } elsif ($subj eq "Ha'Azinu") {
		$drash_yr = $this_year + 3761;
	    }

	    $drash_href = join('/', $drash_prefix, $drash_yr, $drash_html);
	}

	$rss{'link'} = $href;

	if ($href ne '' &&
	    !(defined $cfg && $cfg =~ /^[rw]$/))
	{
	    if ($q->param('site') && $q->param('site') eq 'keshernj.com')
	    {
		$rss{'title'} .= "<b>$subj</b>";
	    }
#	    elsif (defined $torah_href && $torah_href ne '')
#	    {
#		$rss{'title'} .=
#		    qq{<b>$subj</b>\n<span class="goto">(<a } .
#		    qq{target="_top"\nhref="$drash_href">Drash</a>\n} .
#		    qq{- <a target="_top"\nhref="$torah_href">Torah</a>\n} .
#		    qq{- <a target="_top"\nhref="$haftarah_href">Haftarah</a>)</span>};
#	    }
	    else
	    {
		$rss{'title'} .= qq{<a\ntarget="_top" href="$href">$subj</a>};
	    }
	}
	else
	{
	    $rss{'title'} .= $subj;
	}

	if (defined $cfg && $cfg eq 'r')
	{
	    &out_rss(\%rss);
	}
	elsif (defined $cfg && $cfg eq 'w')
	{
	    delete($rss{'description'})
		if ($subj =~ /^(Parshas|Parashat)\s+/);
	    &out_wap(\%rss);
	}
	else
	{
	    my $class = ($subj =~ /^(Parshas|Parashat)\s+/) ?
		'parashat' : 'holiday';
	    &Hebcal::out_html($cfg,qq{\n<dt class="$class">}, $rss{'title'});
	    &Hebcal::out_html($cfg,"\non ", $rss{'description'})
		unless ($subj =~ /^(Parshas|Parashat)\s+/);
	    &Hebcal::out_html($cfg,"</dt>");
	    &Hebcal::out_html($cfg,"<br>&nbsp;")
		if ($q->param('site') &&
		    $q->param('site') eq 'keshernj.com');
	}
    }
}

&Hebcal::out_html($cfg,"\n</dl>\n")
    unless (defined $cfg && $cfg =~ /^[rw]$/);

if (!$cfg && $q->param('zip'))
{
    my($url) = join('', "http://", $q->virtual_host(), "/email/",
			 "?geo=", $q->param('geo'));

    $url .= "&amp;zip=" . $q->param('zip');
    $url .= "&amp;m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    &Hebcal::out_html($cfg,"<p><span class=\"sm-grey\">&gt;</span>\n",
		      "<a href=\"$url\">Email:\n",
		      "subscribe to weekly Candle Lighting Times</a>\n");

    $url = join('', "http://", $q->virtual_host(), "/link/",
		"?zip=", $q->param('zip'));
    $url .= "&amp;m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);
    $url .= "&amp;type=shabbat";

    &Hebcal::out_html($cfg,"<br><span class=\"sm-grey\">&gt;</span>\n",
		      "<a href=\"$url\">Synagogues: add\n",
		      "1-Click Shabbat candle-lighting times to your\n",
		      "web site</a></p>\n");
}

if (defined $cfg && $cfg =~ /^[ijrw]$/)
{
    if ($cfg eq 'i')
    {
	&Hebcal::out_html($cfg, "<font size=\"-2\" face=\"Arial\">1-Click Shabbat\n",
			  &Hebcal::html_copyright($q), "</font>\n",
			  "</body></html>\n");
    }
    elsif ($cfg eq 'r')
    {
	&Hebcal::out_html($cfg,"<textinput>
<title>1-Click Shabbat</title>
<description>Get Shabbat Times for another zip code</description>
<name>zip</name>
");
	&Hebcal::out_html($cfg,"<link>http://", $q->virtual_host(), $script_name,
		  "</link>\n</textinput>\n");
	&Hebcal::out_html($cfg,"</channel>\n</rss>\n");
    }
    elsif ($cfg eq 'w')
    {
	&Hebcal::out_html($cfg,"</card>\n</wml>\n");
    }
    elsif ($cfg eq 'j' &&
	   $q->param('site') && $q->param('site') eq 'keshernj.com')
    {
	# no copyright
    }
    elsif ($cfg eq 'j')
    {
	&Hebcal::out_html($cfg, "<font size=\"-2\" face=\"Arial\">1-Click Shabbat\n",
			  &Hebcal::html_copyright($q), "</font>\n");
    }
}
else
{
    &form(0,'','');
}

close(STDOUT);
exit(0);

sub out_wap
{
    my($rss) = @_;

    print STDOUT "<p>", $rss->{'title'};
    print STDOUT "<br/>\n", $rss->{'description'}
	    if defined $rss->{'description'};
    print STDOUT "</p>\n";
}

sub out_rss
{
    my($rss) = @_;

    print STDOUT
	"<item>\n",
	"<title>", $rss->{'title'}, "</title>\n",
	"<link>", $rss->{'link'}, "</link>\n";

    print STDOUT
	"<description>", $rss->{'description'}, "</description>\n"
	    if defined $rss->{'description'};

    print STDOUT
	"</item>\n";
}

sub my_header
{
    my($title) = @_;

    print STDOUT "Cache-Control: private\015\012";
    if (defined $cfg && $cfg eq 'j')
    {
	print STDOUT "Content-Type: application/x-javascript\015\012\015\012";
    }
    elsif (defined $cfg && $cfg eq 'r')
    {
	print STDOUT "Content-Type: text/xml\015\012\015\012";
    }
    elsif (defined $cfg && $cfg eq 'w')
    {
	my($descr);
	if ($title =~ /^(1-Click Shabbat) for (.+)$/)
	{
	    $title = $1;
	    $descr = $2;
	}
	
	print STDOUT "Content-Type: text/vnd.wap.wml\015\012\015\012";

	&Hebcal::out_html($cfg,qq{<?xml version="1.0"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
"http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
<card id="shabbat2" title="$title">
});
	&Hebcal::out_html($cfg,qq{<p><b>$descr</b></p>\n}) if defined $descr;
    }
    else
    {
	&Hebcal::out_html($cfg,$q->header(),
		  &Hebcal::start_html($q, $title, undef, undef)
		  );
    }

    unless (defined $cfg && $cfg =~ /^[ijrw]$/)
    {
	&Hebcal::out_html($cfg,&Hebcal::navbar2($q, "1-Click Shabbat", 1, undef, undef),
		  "<h1>1-Click\nShabbat Candle Lighting Times</h1>\n");
    }

    1;
}

sub form
{
    my($head,$message,$help) = @_;

    &my_header('1-Click Shabbat') if $head;

    if (defined $cfg && $cfg eq 'w')
    {
	&Hebcal::out_html($cfg,qq{<p>$message</p>\n},
		  qq{<do type="accept" label="Back">\n},
		  qq{<prev/>\n</do>\n</card>\n</wml>\n});
	exit(0);
    }

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help;
    }

    &Hebcal::out_html($cfg,
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
	&Hebcal::out_html($cfg,
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
			 'israel' => "\nIsrael ",
			 'none' => "\nnone ", }));
    }
    
    &Hebcal::out_html($cfg,
	$q->hidden(-name => 'geo',
		   -value => 'zip',
		   -override => 1),
	"<br><label\nfor=\"m1\">Havdalah minutes past sundown:\n",
	$q->textfield(-name => 'm',
		      -id => 'm1',
		      -size => 3,
		      -maxlength => 3,
		      -default => $Hebcal::havdalah_min),
	"</label>",
	qq{<br><input\ntype="submit" value="Get Shabbat Times"></form>});


    &Hebcal::out_html($cfg,
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
	"<br><label\nfor=\"m2\">Havdalah minutes past sundown:\n",
	$q->textfield(-name => 'm',
		      -id => 'm2',
		      -size => 3,
		      -maxlength => 3,
		      -default => $Hebcal::havdalah_min),
	"</label>",
	qq{<br><input\ntype="submit" value="Get Shabbat Times"></form>},
	qq{</td></tr></table>});

    &Hebcal::out_html($cfg,&Hebcal::html_footer($q,$rcsrev));

    exit(0);
}

# local variables:
# mode: perl
# end:
