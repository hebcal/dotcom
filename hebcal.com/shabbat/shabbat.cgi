#!/usr/local/bin/perl -w

########################################################################
# 1-Click Shabbat generates weekly Shabbat candle lighting times and
# Parsha HaShavua from Hebcal information.
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
$script_name =~ s,/index.cgi$,/,;

my($evts,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty) =
    process_args($q);
my($items) = format_items($q,$evts);

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
    my($q,$events) = @_;

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

    my $tz = 0;
    if ($q->param('tz'))
    {
	$tz = $q->param('tz');
	$tz = 0 if $tz eq 'auto';
    }
    elsif ($q->param('city') && 
	   defined($Hebcal::city_tz{$q->param('city')}))
    {
	$tz = $Hebcal::city_tz{$q->param('city')};
    }

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
	my $format = (defined $cfg && $cfg =~ /^[ij]$/) ?
	    "%A, %d %b %Y" : "%A, %d %B %Y";
	$item{'date'} = strftime($format, localtime($time));

	if ($events->[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0)
	{
	    $item{'dc:date'} =
		sprintf("%04d-%02d-%02dT%02d:%02d:%02d%s%02d:00",
			$year,$mon,$mday,
			$hour + 12,$min,0,
			$tz > 0 ? "+" : "-",
			abs($tz));
	}
	else
	{
	    $item{'dc:date'} = sprintf("%04d-%02d-%02d",$year,$mon,$mday);
	    $item{'dc:date'} .= sprintf("T00:00:00%s%02d:00",
					$tz > 0 ? "+" : "-",
					abs($tz));
	}

	my $anchor = sprintf("%04d%02d%02d_",$year,$mon,$mday) . lc($subj);
	$anchor =~ s/[^\w]/_/g;
	$anchor =~ s/_+/_/g;
	$anchor =~ s/_$//g;
	$item{'about'} = $url . "#" . $anchor;
	$item{'subj'} = $subj;

	if ($subj eq 'Candle lighting' || $subj =~ /Havdalah/)
	{
	    $item{'class'} = ($subj eq 'Candle lighting') ?
		'candles' : 'havdalah';
	    $item{'time'} = sprintf("%d:%02dpm", $hour, $min);
	    $item{'link'} = $url . "#" . $anchor;
	}
	elsif ($subj eq 'No sunset today.')
	{
	    $item{'class'} = 'candles';
	    $item{'link'} = self_url();
	    $item{'time'} = '';
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

	    $item{'link'} = Hebcal::get_holiday_anchor($subj,0,$q);
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
    if (defined $ENV{'QUERY_STRING'} && $ENV{'QUERY_STRING'} !~ /^\s*$/ &&
	(! defined $cfg || $cfg ne 'v'))
    {
	print "Expires: ", &Hebcal::http_date($saturday), "\015\012";
    }

    if (defined $ENV{'QUERY_STRING'} && $ENV{'QUERY_STRING'} !~ /^\s*$/ &&
	! defined $cfg)
    {
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

	print "Cache-Control: private\015\012", "Set-Cookie: ", $cookie_to_set,
	"; path=/; expires=",  $expires_date, "\015\012"
	    if $cookie_to_set;
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

	if ($items->[$i]->{'class'} =~ /^(candles|havdalah)$/)
	{
	    my $pm = $items->[$i]->{'time'};
	    $pm =~ s/pm$/p/;
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
	$city_audio = "<audio>$city,";

	if (defined $STATES{$state})
	{
	    $city_audio .= " $STATES{$state},";
	}
	else
	{
	    foreach my $d (split(//, $state))
	    {
		$city_audio .= " $d";
	    }
	    $city_audio .= ",";
	}

	foreach my $d (split(//, $zip))
	{
		$city_audio .= " $d";
	}
	$city_audio .= ".</audio>\n";
    }

    print qq{<?xml version="1.0"?>
<vxml version="2.0">
<form id="results">
<block>
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
	my $date = $items->[$i]->{'date'};
	$date =~ s/, 0(\d) /, $1 /;

	if ($items->[$i]->{'class'} =~ /^(candles|havdalah)$/)
	{
	    my $subj = $items->[$i]->{'subj'};
	    $subj =~ s/Havdalah \(\d+ min\)/Hav doll ah/g;
	    print qq{\t<audio>$subj is at $items->[$i]->{'time'}.</audio>\n};
	}
	elsif ($items->[$i]->{'class'} eq 'holiday')
	{
	    print qq{\t<audio>Holiday... $items->[$i]->{'subj'} is on $date.</audio>\n};
	}
	elsif ($items->[$i]->{'class'} eq 'parashat')
	{
	    my $subj = $items->[$i]->{'subj'};
	    $subj =~ s/Parashat/Par shot/g;
	    print qq{\t<audio>This week's Torah portion is $subj.</audio>\n};
	}

	print qq{\t<break time="250ms"/>\n};
    }

    print qq{
	<break time="250ms"/>
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
    my $title = '1-Click Shabbat: ' . $city_descr;

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
<description>Weekly Shabbat candle lighting times for $city_descr</description>
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

    my $tgt = $q->param('tgt') ? $q->param('tgt') : '_top';

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	&Hebcal::out_html($cfg,qq{<dt class="$items->[$i]->{'class'}">});

	my $anchor = '';
	if (!$cfg)
	{
	    $anchor = $items->[$i]->{'about'};
	    $anchor =~ s/^.*#//;
	    $anchor = qq{ name="$anchor"};
	}

	if ($items->[$i]->{'class'} =~ /^(candles|havdalah)$/)
	{
	    Hebcal::out_html($cfg,qq{<a$anchor></a>})
		unless $cfg;
	    Hebcal::out_html($cfg,qq{$items->[$i]->{'subj'}:
<b>$items->[$i]->{'time'}</b> on $items->[$i]->{'date'}});
	}
	elsif ($items->[$i]->{'class'} eq 'holiday')
	{
	    &Hebcal::out_html($cfg,qq{Holiday: <a$anchor
target="$tgt" href="$items->[$i]->{'link'}">$items->[$i]->{'subj'}</a> on
$items->[$i]->{'date'}});
	}
	elsif ($items->[$i]->{'class'} eq 'parashat')
	{
	    &Hebcal::out_html($cfg,qq{This week's Torah portion is <a$anchor
target="$tgt" href="$items->[$i]->{'link'}">$items->[$i]->{'subj'}</a>});
	}
    
	&Hebcal::out_html($cfg,qq{</dt>\n});
    }

    &Hebcal::out_html($cfg,"</dl>\n");
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
    $url .= ";.from=" . 
	($q->param('.from') ?
	 Hebcal::url_escape($q->param('.from')) :
	 $cfg);

    Hebcal::out_html($cfg, qq{<div id="hebcal">\n},
		     qq{<h3>Shabbat times for $city_descr</h3>\n});

    display_html_common($items);

    my($this_year) = (localtime)[5];
    $this_year += 1900;

    my $tgt = $q->param('tgt') ? $q->param('tgt') : '_top';
    &Hebcal::out_html($cfg, qq{<font size="-2" face="Arial"><a target="$tgt"
href="$url">1-Click Shabbat</a>
Copyright &copy; $this_year Michael J. Radwin. All rights reserved.</font>
</div>
});

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
	print "&nbsp;&nbsp;$tz_descr\n<br>&nbsp;&nbsp;$dst_descr\n";
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
		      "See all of <a href=\"$url\">this\n",
		      "month's calendar</a>\n");

    # Fridge calendar
    $url = join('', "http://", $q->virtual_host(), "/shabbat/fridge.cgi?");
    if ($q->param('zip')) {
	$url .= "zip=" . $q->param('zip');
    } else {
	$url .= "city=" . Hebcal::url_escape($q->param('city'));
    }
    Hebcal::out_html($cfg,"|\nprintable page of <a href=\"$url\">this year's times</a>\n",
		     "<span class=\"hl\"><b>NEW!</b></span>\n");

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
		      "Email: <a href=\"$url\">subscribe</a>\n",
		      "to weekly candle lighting times\n");

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
		      "Synagogues: <a href=\"$url\">include</a>\n",
		      "1-Click Shabbat candle-lighting times on your\n",
		      "web site</p>\n");
 
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
		       -default => 'New York'),
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
