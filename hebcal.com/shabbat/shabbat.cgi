#!/usr/local/bin/perl -w

########################################################################
# Hebcal Shabbat Times generates weekly Shabbat candle lighting times
# and Parsha HaShavua from Hebcal information.
#
# Copyright (c) 2011  Michael J. Radwin.
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
use DB_File;
use Time::Local ();
use Date::Calc ();
use Hebcal ();
use HebcalGPL ();
use POSIX qw(strftime);

my($rcsrev) = '$Revision$'; #'

# process form params
my($q) = new CGI;
my($script_name) = $q->script_name();
$script_name =~ s,/[^/]+$,/,;

my($this_year,$this_mon,$this_day) = Date::Calc::Today();
my $hebdate = HebcalGPL::greg2hebrew($this_year,$this_mon,$this_day);
my $hyear = $hebdate->{"yy"};
$hyear++ if $hebdate->{"mm"} == 6; # Elul

my($friday,$fri_year,$saturday,$sat_year) = get_saturday($q);

my($latitude,$longitude);
my($evts,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty) =
    process_args($q);
my $items = Hebcal::events_to_dict($evts,$cfg,$q,$friday,$saturday);

my $cache = Hebcal::cache_begin($q);

if (defined $cfg && ($cfg =~ /^[ijrw]$/ ||
		     $cfg eq "widget" || $cfg eq "json"))
{
    display_wml($items) if ($cfg eq 'w');
    display_rss($items) if ($cfg eq 'r');
    display_javascript($items) if ($cfg  =~ /^[ij]$/ || $cfg eq "widget");
    display_json($items) if ($cfg eq "json");
}
else
{
    undef($cfg);
    display_html($items);
}

Hebcal::cache_end() if $cache;
exit(0);

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

	my $DB = Hebcal::zipcode_open_db();
	my($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state);
	# set global $latitude and $longitude
	($long_deg,$long_min,$lat_deg,$lat_min,$tz,$dst,$city,$state,$latitude,$longitude) =
	    Hebcal::zipcode_get_zip_fields($DB, $q->param("zip"));
	Hebcal::zipcode_close_db($DB);
	undef($DB);

	form($cfg,1,
	      "Sorry, can't find\n".  "<b>" . $q->param('zip') .
	      "</b> in the zip code database.\n",
	      "<ul><li>Please try a nearby zip code</li></ul>")
	    unless defined $state;

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

    $cmd .= ' -c -s';

    foreach ('a', 'i')
    {
	$cmd .= ' -' . $_
	    if defined $q->param($_) && $q->param($_) =~ /^on|1$/;
    }

    # don't do holidays or rosh chodesh for WML
    if (defined $cfg && $cfg eq 'w')
    {
	$cmd .= ' -h -x';
    }

    $cmd .= " -m " . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    $cmd .= " -z " . $q->param('tz')
	if (defined $q->param('tz') && $q->param('tz') ne '');

    $cmd .= " -Z " . $q->param('dst')
	if (defined $q->param('dst') && $q->param('dst') ne '');

    my($loc) = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';

    my @events = Hebcal::invoke_hebcal("$cmd $sat_year", $loc, 0);
    if ($sat_year != $fri_year) {
	# Happens when Friday is Dec 31st and Sat is Jan 1st
	my @ev2 = Hebcal::invoke_hebcal("$cmd 12 $fri_year", $loc, 0);
	@events = (@ev2, @events);
    }
    
    my($cmd_pretty) = $cmd;
    $cmd_pretty =~ s,.*/,,; # basename

    (\@events,$cfg,$city_descr,$dst_descr,$tz_descr,$cmd_pretty);
}

sub self_url
{
    my($url) = join('', "http://", $q->virtual_host(), $script_name,
			 "?geo=", $q->param('geo'));

    $url .= ";zip=" . $q->param('zip')
	if $q->param('zip');
    $url .= ";city=" . Hebcal::url_escape($q->param('city'))
	if $q->param('city');
    $url .= ";m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    $url;
}

sub display_wml
{
    my($items) = @_;

    my $title = 'Hebcal Shabbat Times';
	
    print "Content-Type: text/vnd.wap.wml\015\012\015\012";

    Hebcal::out_html($cfg,
qq{<?xml version="1.0"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
"http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
<card id="shabbat2" title="$title">
<!-- $cmd_pretty -->
<p><b>$city_descr</b></p>
});

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	my $subj = $items->[$i]->{'subj'};
	$subj =~ s/^Candle lighting/Candles/;

	Hebcal::out_html($cfg, "<p>$subj");

	if ($items->[$i]->{'class'} =~ /^(candles|havdalah)$/)
	{
	    my $pm = $items->[$i]->{'time'};
	    $pm =~ s/pm$/p/;
	    Hebcal::out_html($cfg, ": $pm");
	}
	elsif ($items->[$i]->{'class'} eq 'holiday')
	{
	    Hebcal::out_html($cfg, "<br/>\n", $items->[$i]->{'date'});
	}

	Hebcal::out_html($cfg, "</p>\n");
    }

    Hebcal::out_html($cfg, "</card>\n</wml>\n");
    Hebcal::out_html($cfg, "<!-- generated ", scalar(localtime), " -->\n");
}


sub display_json
{
    my($items) = @_;

    print "Content-Type: text/json; charset=UTF-8\015\012\015\012";

    Hebcal::items_to_json($items,$q,$city_descr,$latitude,$longitude);
}


sub display_rss
{
    my($items) = @_;

    print "Content-Type: text/xml\015\012\015\012";

    my($url) = self_url();
    my $title = 'Shabbat Times for ' . $city_descr;

    my $lastBuildDate = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time()));

    Hebcal::out_html($cfg,
qq{<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#">
<channel>
<title>$title</title>
<link>$url</link>
<description>Weekly Shabbat candle lighting times for $city_descr</description>
<language>en-us</language>
<copyright>Copyright (c) $this_year Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$lastBuildDate</lastBuildDate>
<!-- $cmd_pretty -->
});

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	my $subj = $items->[$i]->{'subj'};
	if (defined $items->[$i]->{'time'}) { 
	    $subj .= ": " . $items->[$i]->{'time'};
	}

	my $link = $items->[$i]->{'link'};
	if ($link =~ /\.html$/)
	{
	    $link .= "?tag=rss";
	}

	Hebcal::out_html($cfg, 
qq{<item>
<title>$subj</title>
<link>$link</link>
<description>$items->[$i]->{'date'}</description>
<category>$items->[$i]->{'class'}</category>
<pubDate>$items->[$i]->{'pubDate'}</pubDate> 
});

	if ($items->[$i]->{'class'} eq "candles" && defined $latitude) {
	    Hebcal::out_html($cfg,
qq{<geo:lat>$latitude</geo:lat>
<geo:long>$longitude</geo:long>
});
      }

	Hebcal::out_html($cfg, "</item>\n");
    }

    Hebcal::out_html($cfg, "</channel>\n</rss>\n");
    Hebcal::out_html($cfg, "<!-- generated ", scalar(localtime), " -->\n");
}

sub display_html_common
{
    my($items) = @_;

    Hebcal::out_html($cfg,"<!-- $cmd_pretty -->\n");
    Hebcal::out_html($cfg,"<ul id=\"hebcal-results\">\n");

    my $tgt = $q->param('tgt') ? $q->param('tgt') : '_top';

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	Hebcal::out_html($cfg,qq{<li class="$items->[$i]->{'class'}">});

	my $anchor = '';
	if (!$cfg)
	{
	    $anchor = $items->[$i]->{'about'};
	    $anchor =~ s/^.*#//;
	    $anchor = qq{ id="$anchor"};
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
	    Hebcal::out_html($cfg,qq{Holiday: <a$anchor
target="$tgt" href="$items->[$i]->{'link'}">$items->[$i]->{'subj'}</a> on
$items->[$i]->{'date'}});
	}
	elsif ($items->[$i]->{'class'} eq 'parashat')
	{
	    Hebcal::out_html($cfg,qq{This week\'s Torah portion is <a$anchor
target="$tgt" href="$items->[$i]->{'link'}">$items->[$i]->{'subj'}</a>});
	}
    
	Hebcal::out_html($cfg,qq{</li>\n});
    }

    Hebcal::out_html($cfg,"</ul>\n");
}

sub display_javascript
{
    my($items) = @_;

    my($title) = "Shabbat Times for $city_descr";

    if ($cfg eq "i" || $cfg eq "widget") {
	print $q->header();
	my $base = "http://" . $q->virtual_host() . $script_name;
	print $q->start_html(
	    -title => $title,
	    -target => "_top",
	    -xbase => $base,
	    -style => { -verbatim => "ul#hebcal-results { list-style-type: none }" }
	    );
    } else {
	print "Content-Type: application/x-javascript\015\012\015\012";
    }

    my($url) = self_url();

    my $tag;
    if ($cfg eq "i") {
	$tag = "iframe.1c";
    } elsif ($cfg eq "widget") {
	$tag = "widget";
    } elsif ($q->param('.from')) {
	$tag = Hebcal::url_escape($q->param('.from'));
    } else {
	$tag = "js.1c";
    }

    $url .= ";tag=$tag";

    my $loc_class = '';
    if (defined $q->param('zip') && $q->param('zip') ne '') {
	$loc_class = $q->param('zip');
    } else {
	$loc_class = lc($q->param('city'));
	$loc_class =~ s/\s+/-/g; 
    }

    Hebcal::out_html($cfg, qq{<div id="hebcal">\n},
		     qq{<div id="hebcal-$loc_class">\n},
		     qq{<h3>Shabbat times for $city_descr</h3>\n});

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	if ($items->[$i]->{'link'} && $items->[$i]->{'link'} =~ /\.html$/)
	{
	    $items->[$i]->{'link'} .= "?tag=$tag";
	}

	if ($cfg eq "widget" && $items->[$i]->{'link'})
	{
	    $items->[$i]->{'link'} = "javascript:widget.openURL('" .
		$items->[$i]->{'link'} . "');";
	}
    }

    display_html_common($items);

    if ($cfg ne "x") {
    my $tgt = $q->param('tgt') ? $q->param('tgt') : '_top';

    if ($cfg eq "widget")
    {
	$url = "javascript:widget.openURL('" . $url . "');";
    }

    Hebcal::out_html($cfg, qq{<div class="copyright">
<small>Powered by <a target="$tgt"
href="$url">Hebcal Shabbat Times</a></small>
</div><!-- .copyright -->
</div><!-- #hebcal-$loc_class -->
</div><!-- #hebcal -->
});
    }

    if ($cfg eq "i" || $cfg eq "widget") {
	Hebcal::out_html($cfg, "</body></html>\n");
    }

    Hebcal::out_html($cfg, "<!-- generated ", scalar(localtime), " -->\n");
}

sub display_html
{
    my($items) = @_;

    my $title = "Shabbat Candle Lighting Times for $city_descr";

    print $q->header();

    my_head($title);

    Hebcal::out_html($cfg, $Hebcal::indiana_warning)
	if ($city_descr =~ / IN /);

    Hebcal::out_html(undef, $Hebcal::usno_warning)
	if (defined $latitude && ($latitude >= 60.0 || $latitude <= -60.0));

    for (my $i = 0; $i < scalar(@{$items}); $i++)
    {
	if ($items->[$i]->{'link'} && $items->[$i]->{'link'} =~ /\.html$/)
	{
	    $items->[$i]->{'link'} .= "?tag=1c";
	}
    }

    display_html_common($items);

    form($cfg,0,'','');
}

sub more_from_hebcal {
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

    $url .= ';vis=on;month=now;year=now;nh=on;nx=on;s=on;c=on;mf=on;ss=on';
    $url .= ';tag=1c';

    my $month_name = join(" ", $Hebcal::MoY_long{$this_mon}, $this_year);
    Hebcal::out_html($cfg, qq{<h3 class="widget-title">More candle lighting</h3>\n},
		     "<ul>\n",
		     "<li><a\nhref=\"$url\">$month_name</a> calendar\n");

    # Fridge calendar
    $url = join('', "http://", $q->virtual_host(), "/shabbat/fridge.cgi?");
    if ($q->param('zip')) {
	$url .= "zip=" . $q->param('zip');
    } else {
	$url .= "city=" . Hebcal::url_escape($q->param('city'));
    }
    $url .= ";year=" . $hyear;
    Hebcal::out_html($cfg,"<li><a title=\"Print and post on your refrigerator\"\n",
		     "href=\"$url\">Printable page for $hyear</a>\n",
		     "<br>year at a glance\n");

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

    Hebcal::out_html($cfg,"<li>",
		     "<a\nhref=\"$url\">Subscribe to weekly email</a>\n");

    # Mac OS X
    $url = "http://www.apple.com/downloads/dashboard/reference/hebcal.html";
    Hebcal::out_html($cfg,"<li>",
		     "<a title=\"by Mark Saper\"\nhref=\"$url\">Mac OS X Dashboard Widget</a>\n");

    my $rss_href = self_url() . ";cfg=r";
    my $rss_html = <<EOHTML;
<li><a href="$rss_href">RSS feed</a>
<a title="RSS feed of candle lighting times"
href="$rss_href"><img
src="/i/xml.gif" style="border:none" width="36" height="14"
alt="RSS feed of candle lighting times"></a>
EOHTML
;

    Hebcal::out_html($cfg, $rss_html);

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

    Hebcal::out_html($cfg,"<li>",
		     "<a title=\"Candle lighting and Torah portion ",
		     "for your synagogue site\"\nhref=\"$url\">Add\n",
		     "Shabbat Times to your Website</a>\n");
 
    Hebcal::out_html($cfg,"</ul>\n");
}

sub my_head {
    my($title) = @_;
    my $rss_href = self_url() . ";cfg=r";
    my $xtra_head = <<EOHTML;
<link rel="alternate" type="application/rss+xml" title="RSS" href="$rss_href">
<style type="text/css">
.entry-content fieldset {
border:1px solid #E7E7E7;
margin:0 0 12px;
padding:6px;
}
.entry-content input, .entry-content select {
margin:0;
}
form ol {
list-style:none inside none;
margin:0 0 12px 12px;
}
ul#hebcal-results { list-style-type: none }
#city-list  li { font-size:12px }
#city-list ul li { display: inline }
#city-list ul li:after { content:" | "}
#city-list ul li.last:after { content:"" }
</style>
EOHTML
;
	my $head_divs = <<EOHTML;
<div id="container">
<div id="content" role="main">
<div class="page type-page hentry">
<h1 class="entry-title">$title</h1>
<div class="entry-content">
EOHTML
;
	Hebcal::out_html($cfg,
			 Hebcal::html_header($title,
					     $script_name,
					     "single single-post",
					     $xtra_head),
			 $head_divs
	    );
}

sub form($$$$)
{
    my($cfg,$head,$message,$help) = @_;

    if ($head) {
	print $q->header();
	my_head("Shabbat Candle Lighting Times");
    }

    if (defined $cfg && $cfg eq 'w')
    {
	Hebcal::out_html($cfg,qq{<p>$message</p>\n},
		  qq{<do type="accept" label="Back">\n},
		  qq{<prev/>\n</do>\n</card>\n</wml>\n});
	Hebcal::cache_end() if $cache;
	exit(0);
    }

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<blockquote><p\nstyle=\"color: red\">" .
	    $message . "</p>" . $help . "</blockquote>";
    }

    Hebcal::out_html($cfg,
	qq{$message\n},
	qq{<div id="hebcal-form-zipcode">\n},
	qq{<form name="f1" id="f1"\naction="$script_name">},
	qq{<fieldset><legend>Get Shabbat times by Zip Code</legend>\n},
	$q->hidden(-name => 'geo',
		   -value => 'zip',
		   -override => 1),
	qq{<ol>\n},
	qq{<li><label for="zip">Zip code:\n},
	$q->textfield(-name => 'zip',
		      -id => 'zip',
		      -size => 5,
		      -maxlength => 5),
	qq{</label>});

    if ($q->param('geo') eq 'pos' || $q->param('tz_override'))
    {
	Hebcal::out_html($cfg,
	qq{<li><label\nfor="tz">Time zone:\n},
	$q->popup_menu(-name => 'tz',
		       -id => 'tz',
		       -values => ['auto',-5,-6,-7,-8,-9,-10],
		       -default => 'auto',
		       -labels => \%Hebcal::tz_names),
	qq{</label>\n<li>Daylight Saving Time:\n},
	$q->radio_group(-name => 'dst',
			-values => ['usa','none'],
			-default => 'usa',
			-labels =>
			{'usa' => "\nUSA (except AZ, HI, and IN) ",
			 'none' => "\nnone ", }));
    }
    
    Hebcal::out_html($cfg,
	"<li><label\nfor=\"m1\">Havdalah minutes past sundown:\n",
	$q->textfield(-name => 'm',
		      -id => 'm1',
		      -size => 3,
		      -maxlength => 3,
		      -default => $Hebcal::havdalah_min),
	"</label>",
	"<ol><li><small>(enter\n\"0\" to turn off\nHavdalah times)</small></ol>",
	qq{<li><input\ntype="submit" value="Get Shabbat Times">\n},
	qq{</ol></fieldset></form>});

    Hebcal::out_html(undef, qq{</div><!-- #hebcal-form-zipcode -->\n});


#    Hebcal::out_html(undef, qq{<div id="hebcal-form-right">\n});
#    more_from_hebcal();
#    Hebcal::out_html(undef, qq{</div><!-- #hebcal-form-right -->\n});

    Hebcal::out_html(undef, qq{<div id="hebcal-form-city">\n});
    Hebcal::out_html($cfg,
		     qq{<form>\n},
		     qq{<fieldset><legend>Get Shabbat times by Major City</legend>\n},
		     qq{<div id="city-list">\n},
		     qq{<ul>\n});
    foreach my $city_name (sort keys %Hebcal::city_tz) {
	my $url = join('', $script_name, "?city=", Hebcal::url_escape($city_name));
	$url .= ";m=" . $q->param('m')
	    if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);
	$city_name =~ s/ /&nbsp;/g;
	Hebcal::out_html($cfg, qq{<li><a href="$url">$city_name</a></li>\n});
    }
    Hebcal::out_html($cfg, qq{</ul>\n</div><!-- .city-list -->\n});
    Hebcal::out_html($cfg, qq{</fieldset></form>\n});
    Hebcal::out_html(undef, qq{</div><!-- #hebcal-form-city -->\n});

    my $footer_divs1=<<EOHTML;
</div><!-- .entry-content -->
</div><!-- #post-## -->
</div><!-- #content -->
</div><!-- #container -->
<div id="primary" class="widget-area" role="complementary">
<ul class="xoxo">
<li id="search-3" class="widget-container widget_search"><form role="search" method="get" id="searchform" action="http://www.hebcal.com/home/" >
<div><label class="screen-reader-text" for="s">Search for:</label>
<input type="text" value="" name="s" id="s" />
<input type="submit" id="searchsubmit" value="Search" />
</div>
</form></li>
<li id="more-from-hebcal" class="widget-container">
EOHTML
;
    Hebcal::out_html(undef, $footer_divs1);

    more_from_hebcal();

    my $footer_divs2=<<EOHTML;
</li><!-- #more-from-hebcal -->
<li id="advman-3" class="widget-container Advman_Widget"><h3 class="widget-title">Advertisement</h3>
<script type="text/javascript"><!--
google_ad_client = "ca-pub-7687563417622459";
/* 200x200 text only */
google_ad_slot = "5114852649";
google_ad_width = 200;
google_ad_height = 200;
//-->
</script>
<script type="text/javascript"
src="http://pagead2.googlesyndication.com/pagead/show_ads.js">
</script></li>
</ul><!-- .xoxo -->
</div><!-- #primary .widget-area -->
EOHTML
;
    Hebcal::out_html(undef, $footer_divs2);

    Hebcal::out_html(undef, Hebcal::html_footer_new($q,$rcsrev));
    Hebcal::out_html($cfg, "<!-- generated ", scalar(localtime), " -->\n");
    Hebcal::cache_end() if $cache;
    exit(0);
}

sub get_saturday
{
    my($q) = @_;

    my $now;
    if (defined $q->param('t') && $q->param('t') =~ /^\d+$/) {
	$now = $q->param('t');
    } else {
	$now = time();
    }

    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime($now);
    $year += 1900;

    my $friday = Time::Local::timelocal(0,0,0,
					$mday,$mon,$year,
					$wday,$yday,$isdst);
    my $saturday = ($wday == 6) ?
	$now + (60 * 60 * 24) : $now + ((6 - $wday) * 60 * 60 * 24);
    my $sat_year = (localtime($saturday))[5] + 1900;

    ($friday,$year,$saturday,$sat_year);
}

# local variables:
# mode: perl
# end:
