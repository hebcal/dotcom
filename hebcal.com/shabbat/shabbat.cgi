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

my($rcsrev) = '$Revision$'; #'

my(%STATES) = (
"AK" => "alaska",
"AL" => "alabama",
"AR" => "arkansas",
"AZ" => "arizona",
"CA" => "california",
"CO" => "colorado",
"CT" => "connecticut",
"DC" => "washington d c",
"DE" => "delaware",
"FL" => "florida",
"GA" => "georgia",
"HI" => "hawaii",
"IA" => "iowa",
"ID" => "idaho",
"IL" => "illinois",
"IN" => "indiana",
"KS" => "kansas",
"KY" => "kentucky",
"LA" => "louisiana",
"MA" => "massachusetts",
"MD" => "maryland",
"ME" => "maine",
"MI" => "michigan",
"MN" => "minnesota",
"MO" => "missouri",
"MS" => "mississippi",
"MT" => "montana",
"NC" => "north carolina",
"ND" => "north dakota",
"NE" => "nebraska",
"NH" => "new hampshire",
"NJ" => "new jersey",
"NM" => "new mexico",
"NV" => "nevada",
"NY" => "new york",
"OH" => "ohio",
"OK" => "oklahoma",
"OR" => "oregon",
"PA" => "pennsylvania",
"PR" => "puerto rico",
"RI" => "rhode island",
"SC" => "south carolina",
"SD" => "south dakota",
"TN" => "tennessee",
"TX" => "texas",
"UT" => "utah",
"VA" => "virginia",
"VT" => "vermont",
"WA" => "washington",
"WI" => "wisconsin",
"WV" => "west virginia",
"WY" => "wyoming",
    );

# process form params
my($q) = new CGI;
my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;

my($evts,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty) =
    process_args($q);
my($items) = format_items($evts);

if (defined $cfg && $cfg =~ /^[ijrwv]$/)
{
    display_wml($items) if ($cfg eq 'w');
    display_rss($items) if ($cfg eq 'r');
    display_vxml($items) if ($cfg eq 'v');
    display_javascript($items) if ($cfg eq 'j' || $cfg eq 'i');
}

display_html($items);
exit(0);

sub format_items
{
    my($events) = @_;

    my($url) = self_url();
    my(@items);

    my $now = time();
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($now);
    $year += 1900;

    my($friday) = &Time::Local::timelocal(0,0,0,
					  $mday,$mon,$year,
					  $wday,$yday,$isdst);
    my($saturday) = ($wday == 6) ?
	$now + (60 * 60 * 24) : $now + ((6 - $wday) * 60 * 60 * 24);

    for (my $i = 0; $i < scalar(@{$events}); $i++)
    {
	# holiday is at 12:00:01 am
	my($time) = &Time::Local::timelocal(1,0,0,
		       $events->[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events->[$i]->[$Hebcal::EVT_IDX_MON],
		       $events->[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
	next if $time < $friday || $time > $saturday;

	my($subj) = $events->[$i]->[$Hebcal::EVT_IDX_SUBJ];
	my($year) = $events->[$i]->[$Hebcal::EVT_IDX_YEAR];
	my($mon) = $events->[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	my($mday) = $events->[$i]->[$Hebcal::EVT_IDX_MDAY];

	my($min) = $events->[$i]->[$Hebcal::EVT_IDX_MIN];
	my($hour) = $events->[$i]->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;

	my(%item);
	$item{'date'} = strftime("%A, %d %B %Y", localtime($time));

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    $item{'dc:date'} =
		sprintf("%04d-%02d-%02dT%02d:%02d:%02d%s%02d:00",
			$year,$mon,$mday,
			$hour,$min,0,
			$q->param('tz') > 0 ? "+" : "",
			$q->param('tz'));
	}
	else
	{
	    $item{'dc:date'} = sprintf("%04d-%02d-%02d",$year,$mon,$mday);
	    $item{'dc:date'} .= "T00:00:00-00:00";
	}

	my $anchor = sprintf("%04d%02d%02d_",$year,$mon,$mday) . lc($subj);
	$anchor =~ s/[^\w]/_/g;
	$anchor =~ s/_+/_/g;
	$anchor =~ s/_$//g;
	$item{'about'} = $url . "#" . $anchor;
	$item{'subj'} = $subj;

	if ($subj eq 'Candle lighting' || $subj =~ /Havdalah/)
	{
	    $item{'class'} = 'candles';
	    $item{'time'} = sprintf("%d:%02d PM", $hour, $min);
	    $item{'link'} = $url . "#" . $anchor;
	}
	else
	{
	    if ($subj =~ /^(Parshas|Parashat)\s+/)
	    {
		$item{'class'} = 'parashat';
	    }
	    else
	    {
		$item{'class'} = 'holiday';
	    }

	    my($href,$hebrew,$memo,$torah_href,$haftarah_href,$drash_href)
		= &Hebcal::get_holiday_anchor($subj,0,$q);

	    $item{'link'} = $href;
	}

	push(@items, \%item);
    }

    \@items;
}

sub process_args
{
    my($q) = @_;

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

    my $wday = (localtime($now))[6];
    my($saturday) = ($wday == 6) ?
	$now + (60 * 60 * 24) : $now + ((6 - $wday) * 60 * 60 * 24);

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
	    form($cfg,1,
		  "Sorry, <b>" . $q->param('zip') . "</b> does\n" .
		  "not appear to be a 5-digit zip code.");
	}

	my $DB = &Hebcal::zipcode_open_db();
	my($val) = $DB->{$q->param('zip')};
	&Hebcal::zipcode_close_db($DB);
	undef($DB);

	form($cfg,1,
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

    foreach ('a', 'i')
    {
	$cmd .= ' -' . $_
	    if defined $q->param($_) && $q->param($_) =~ /^on|1$/;
    }

    # don't do holidays or rosh chodesh for WML and VoiceXML
    if (defined $cfg && ($cfg eq 'w' || $cfg eq 'v'))
    {
	$cmd .= ' -x -h';
    }

    $cmd .= ' -s -c ' . $sat_year;

    # only set expiry if there are CGI arguments
    if (defined $ENV{'QUERY_STRING'} && $ENV{'QUERY_STRING'} !~ /^\s*$/)
    {
	unless (defined $cfg && $cfg eq 'v') {
	    print "Expires: ", &Hebcal::http_date($saturday), "\015\012";
	}

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

	my($expires_date) = 'Thu, 15 Apr 2010 20:00:00 GMT';

	print "Set-Cookie: ", $cookie_to_set,
	"; path=/; expires=",  $expires_date, "\015\012"
	    if $cookie_to_set && !$cfg;
    }

    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';

    my(@events) = &Hebcal::invoke_hebcal($cmd, $loc);
    
    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename

    print "Cache-Control: private\015\012";
    (\@events,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty);
}

sub self_url
{
    my($url) = join('', "http://", $q->virtual_host(), $script_name,
			 "?geo=", $q->param('geo'));

    $url .= ";zip=" . $q->param('zip')
	if $q->param('zip');
    $url .= ";city=" . &Hebcal::url_escape($q->param('city'))
	if $q->param('city');
#      $url .= ";dst=" . $q->param('dst')
#  	if $q->param('dst');
#      $url .= ";tz=" . $q->param('tz')
#  	if (defined $q->param('tz') && $q->param('tz') ne 'auto');
    $url .= ";m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    $url;
}

sub display_wml
{
    my($items) = @_;

    my $title = '1-Click Shabbat';
	
    print "Content-Type: text/vnd.wap.wml\015\012\015\012";

    print qq{<?xml version="1.0"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
"http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
<card id="shabbat2" title="$title">
<!-- $cmd_pretty -->
<p><b>$city_descr</b></p>
};

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	my $subj = $items->[$i]->{'subj'};
	$subj =~ s/^Candle lighting/Candles/;

	print "<p>$subj";

	if ($items->[$i]->{'class'} eq 'candles') 
	{
	    my $pm = $items->[$i]->{'time'};
	    $pm =~ s/ PM$/p/;
	    print ": $pm";
	}
	elsif ($items->[$i]->{'class'} eq 'holiday')
	{
	    print "<br/>\n", $items->[$i]->{'date'};
	}

	print "</p>\n";
    }

    print "</card>\n</wml>\n";

    exit(0);
}


sub display_vxml
{
    my($items) = @_;

    print "Content-Type: text/xml\015\012\015\012";

    my($url) = self_url();
    my $title = '1-Click Shabbat: ' . $q->param('zip');

    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S%z", localtime(time()));
    $dc_date =~ s/00$/:00/;

    my($this_year) = (localtime)[5];
    $this_year += 1900;

    # fallback
    my $city_audio = "<audio>$city_descr</audio>";

    if ($city_descr =~ /^(.+),\s+(\w\w)\s+(\d{5})$/)
    {
	my($city,$state,$zip) = ($1,$2,$3);
	$city_audio = "<audio>$city,</audio>";

	if (defined $STATES{$state})
	{
	    $city_audio .= "<audio>$STATES{$state},</audio>";
	}
	else
	{
	    foreach my $d (split(//, $state))
	    {
		$city_audio .= "<audio>$d</audio>\n";
	    }
	}

	foreach my $d (split(//, $zip))
	{
	    $city_audio .= "<audio>$d</audio>\n";
	}
    }

    print qq{<?xml version="1.0"?>
<vxml version="2.0">
<form id="results">
<block>
	<audio>Here are candle lighting times for</audio>
	$city_audio
	<break time="500ms"/>
	<goto next="#times"/>
</block>
</form>
<form id="times">
<block>
};

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	if ($items->[$i]->{'class'} eq 'candles')
	{
	    my $subj = $items->[$i]->{'subj'};
	    $subj =~ s/Havdalah \(\d+ min\)/Hav doll ah/g;
	    print qq{\t<audio>$subj for
$items->[$i]->{'date'} is at $items->[$i]->{'time'}.</audio>
};
	}
	elsif ($items->[$i]->{'class'} eq 'holiday')
	{
	    print qq{\t<audio>Holiday... $items->[$i]->{'subj'} is on
$items->[$i]->{'date'}.</audio>
};
	}
	elsif ($items->[$i]->{'class'} eq 'parashat')
	{
	    print qq{\t<audio>This week's Torah portion is
$items->[$i]->{'subj'}.</audio>
};
	}

	print qq{\t<break time="250ms"/>\n};
    }

    print qq{
	<break time="250ms"/>
	<audio>That's all!</audio>
	<goto next="#again"/>
</block>
</form>
<form id="again">
	<field name="again_verify" type="boolean">
		<prompt>
			<audio>Would you like to hear those times again?</audio>
		</prompt>
		<nomatch count="1">
			<audio>I'm sorry...I didn't catch that.</audio>
			<audio>Say Yes or No</audio>
		</nomatch>
		<nomatch count="2">
			<audio>I'm sorry...I still didn't catch that.</audio>
			<audio>Say Yes or No</audio>
			<audio>or for yes, press one. for no, press 2</audio>
			<audio>on your telephone keypad</audio>
			<break time="250ms"/>
			<audio>To choose another keyword say "Tell me menu" or press star.</audio>
		</nomatch>
		<noinput count="1">
			<audio>I'm sorry, I didn't hear you.</audio>
		</noinput>
		<noinput count="2">
			<audio>I'm sorry, I still didn't hear you.</audio>
			<audio>Say Yes or No</audio>
			<audio>or for yes, press one. for no, press 2</audio>
			<audio>on your telephone keypad</audio>
		</noinput>
		<filled>
			<if cond="again_verify == true">
				<audio>O K.</audio>
				<goto next="#times"/>
				<else/>
				<audio>Thanks for using the Heeb cal interactive Jewish Calendar.</audio>
				<audio>Shabbat Shalom.</audio>
			</if>
		</filled>
	</field>
</form>
</vxml>
};
    exit(0);
}

sub display_rss
{
    my($items) = @_;

    print "Content-Type: text/xml\015\012\015\012";

    my($url) = self_url();
    my $title = '1-Click Shabbat: ' . $q->param('zip');

    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S%z", localtime(time()));
    $dc_date =~ s/00$/:00/;

    my($this_year) = (localtime)[5];
    $this_year += 1900;

    print qq{<?xml version="1.0"?>
<rdf:RDF
xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns="http://purl.org/rss/1.0/">
<channel rdf:about="$url">
<title>$title</title>
<link>$url</link>
<description>Weekly Shabbat candle lighting times for 
$city_descr</description>
<dc:language>en-us</dc:language>
<dc:creator>hebcal.com</dc:creator>
<dc:rights>Copyright &#169; $this_year Michael J. Radwin. All rights reserved.</dc:rights>
<dc:date>$dc_date</dc:date>
<!-- $cmd_pretty -->
<items>
<rdf:Seq>
};

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	my($anchor) = $items->[$i]->{'about'};
	print qq{<rdf:li rdf:resource="$anchor" />\n};
    }

    print "</rdf:Seq>\n</items>\n</channel>\n";

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	my $subj = $items->[$i]->{'subj'};
	if (defined $items->[$i]->{'time'}) { 
	    $subj .= ": " . $items->[$i]->{'time'};
	}
	print qq{<item rdf:about="$items->[$i]->{'about'}">
<title>$subj</title>
<link>$items->[$i]->{'link'}</link>
<description>$items->[$i]->{'date'}</description>
<dc:subject>$items->[$i]->{'class'}</dc:subject>
<dc:date>$items->[$i]->{'dc:date'}</dc:date> 
</item>
};
    }

    print "</rdf:RDF>\n";

    exit(0);
}

sub display_html_common
{
    my($items) = @_;

    &Hebcal::out_html($cfg,"<!-- $cmd_pretty -->\n");
    &Hebcal::out_html($cfg,"<dl>\n");

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	&Hebcal::out_html($cfg,qq{<dt class="$items->[$i]->{'class'}>">});

	if ($items->[$i]->{'class'} eq 'candles')
	{
	    &Hebcal::out_html($cfg,qq{$items->[$i]->{'subj'} for
$items->[$i]->{'date'} is at <b>$items->[$i]->{'time'}</b>});
	}
	elsif ($items->[$i]->{'class'} eq 'holiday')
	{
	    &Hebcal::out_html($cfg,qq{Holiday: <a
href="$items->[$i]->{'link'}">$items->[$i]->{'subj'}</a> on
$items->[$i]->{'date'}});
	}
	elsif ($items->[$i]->{'class'} eq 'parashat')
	{
	    &Hebcal::out_html($cfg,"This week's Torah portion is <a
href=\"$items->[$i]->{'link'}\">$items->[$i]->{'subj'}</a>");
	}
    
	&Hebcal::out_html($cfg,qq{</dt>\n});
    }

    &Hebcal::out_html($cfg,"</dl>");
}

sub display_javascript
{
    my($items) = @_;

    my($title) = "1-Click Shabbat Candle Lighting Times for $city_descr";

    if ($cfg eq 'i') {
	print $q->header(),
	&Hebcal::start_html($q, $title, undef, undef, undef);
    } else {
	print "Content-Type: application/x-javascript\015\012\015\012";
    }

    my($url) = self_url();

    if (defined $ENV{'HTTP_REFERER'} && $ENV{'HTTP_REFERER'} !~ /^\s*$/)
    {
	$url .= ";.from=" . &Hebcal::url_escape($ENV{'HTTP_REFERER'});
    }
    elsif ($q->param('.from'))
    {
	$url .= ";.from=" . &Hebcal::url_escape($q->param('.from'));
    }

    &Hebcal::out_html($cfg, qq{<h3><a target="_top"
href="$url">1-Click
Shabbat</a> for $city_descr</h3>
});

    display_html_common($items);

    &Hebcal::out_html($cfg, 
		      "<font size=\"-2\" face=\"Arial\">1-Click Shabbat\n",
		      &Hebcal::html_copyright($q), "</font>\n");

    if ($cfg eq 'i') {
	&Hebcal::out_html($cfg, "</body></html>\n");
    }

    exit(0);
}

sub display_html
{
    my($items) = @_;

    my($title) = "1-Click Shabbat Candle Lighting Times for $city_descr";
    my $rss_href = self_url() . ";cfg=r";

    print $q->header(),
    &Hebcal::start_html($q, $title,
			[
			 qq{<link rel="alternate" type="application/rss+xml" title="RSS" href="$rss_href">},
			 ],
			undef, undef);

    print &Hebcal::navbar2($q, "1-Click Shabbat", 1, undef, undef),
    qq{<h1><a href="$rss_href"><img\nsrc="/i/xml.gif" border="0" alt="View the raw XML source" align="right" width="36" height="14"></a>\n},
    "1-Click\nShabbat Candle Lighting Times</h1>\n";

    print "<h3>$city_descr</h3>\n";

    if (defined $dst_descr && defined $tz_descr)
    {
	print "&nbsp;&nbsp;$dst_descr\n<br>&nbsp;&nbsp;$tz_descr\n";
    }

    print $Hebcal::indiana_warning
	if ($city_descr =~ / IN /);

    display_html_common($items);

    # link to hebcal full calendar
    my($url) = join('', "http://", $q->virtual_host(), "/hebcal/",
			 "?v=1;geo=", $q->param('geo'), ";");

    if ($q->param('zip')) {
	$url .= "zip=" . $q->param('zip');
    } else {
	$url .= "city=" . Hebcal::url_escape($q->param('city'));
    }

    $url .= ";m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    $url .= ';vis=on;month=now;year=now;nh=on;nx=on;s=on;c=on';

    &Hebcal::out_html($cfg,"<p><span class=\"sm-grey\">&gt;</span>\n",
		      "<a href=\"$url\">Get\n",
		      "candle lighting times for dates in the future</a>\n");

    # Email
    $url = join('', "http://", $q->virtual_host(), "/email/",
			 "?geo=", $q->param('geo'), "&amp;");

    if ($q->param('zip')) {
	$url .= "zip=" . $q->param('zip');
    } else {
	$url .= "city=" . Hebcal::url_escape($q->param('city'));
    }

    $url .= "&amp;m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    &Hebcal::out_html($cfg,"<br><span class=\"sm-grey\">&gt;</span>\n",
		      "<a href=\"$url\">Email:\n",
		      "subscribe to weekly Candle Lighting Times</a>\n");

    # Synagogues link
    $url = join('', "http://", $q->virtual_host(), "/link/?");
    if ($q->param('zip')) {
	$url .= "zip=" . $q->param('zip');
    } else {
	$url .= "city=" . Hebcal::url_escape($q->param('city'));
    }
    $url .= "&amp;m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);
    $url .= "&amp;type=shabbat";

    &Hebcal::out_html($cfg, "<br>");
    &Hebcal::out_html($cfg,"<span class=\"sm-grey\">&gt;</span>\n",
		      "<a href=\"$url\">Synagogues: add\n",
		      "1-Click Shabbat candle-lighting times to your\n",
		      "web site</a></p>\n");
 
    &Hebcal::out_html($cfg,"<p><span class=\"sm-grey\">&gt;</span>\n",
qq{<span class="hl"><b>NEW!</b></span> Automated candle lighting times by Phone:
Call Tellme at 1-800-555-TELL.
Say <b>extensions</b>.
Dial <b>00613</b>.</p>
});

    form($cfg,0,'','');

    exit(0);
}

sub form($$$$)
{
    my($cfg,$head,$message,$help) = @_;

    if (defined $cfg && $cfg eq 'v')
    {
	print "Content-Type: text/xml\015\012\015\012";
	print qq{<?xml version="1.0"?>
<vxml version="2.0">
	<form id="top">
		<block>
			<audio>I'm sorry, there was a problem.</audio>
			<audio>let's try this again...</audio>
			<goto next="http://www.hebcal.com/shabbat.vxml#enterzip"/>
		</block>
	</form>
</vxml>
};
	exit(0);
}

    if ($head)
    {
	print $q->header(),
	&Hebcal::start_html($q, '1-Click Shabbat', undef, undef, undef);

	print &Hebcal::navbar2($q, "1-Click Shabbat", 1, undef, undef),
	"<h1>1-Click\nShabbat Candle Lighting Times</h1>\n";
    }

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
