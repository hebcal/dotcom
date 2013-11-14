#!/usr/bin/perl -w

########################################################################
# Hebcal Shabbat Times generates weekly Shabbat candle lighting times
# and Parsha HaShavua from Hebcal information.
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
use CGI qw(-no_xhtml);
use Encode qw(decode_utf8);
use CGI::Carp qw(fatalsToBrowser);
use Time::Local ();
use Date::Calc ();
use Hebcal ();
use HebcalHtml ();
use URI::Escape;
use URI;
use POSIX qw(strftime);

# process form params
my($q) = new CGI;
my($script_name) = $q->script_name();
$script_name =~ s,/[^/]+$,/,;

foreach my $key ($q->param()) {
    my $val = $q->param($key);
    if (defined $val) {
	my $orig = $val;
	if ($key eq "city") {
	    $val = decode_utf8($val);
	} else {
	    # sanitize input to prevent people from trying to hack the site.
	    # remove anthing other than word chars, white space, or hyphens.
	    $val =~ s/[^\w\.\s-]//g;
	}
	$val =~ s/^\s+//g;		# nuke leading
	$val =~ s/\s+$//g;		# and trailing whitespace
	$q->param($key, $val) if $val ne $orig;
    }
}

my($this_year,$this_mon,$this_day) = Date::Calc::Today();
my $hyear = Hebcal::get_default_hebrew_year($this_year,$this_mon,$this_day);

my($friday,$fri_year,$saturday,$sat_year) = get_saturday($q);

my($latitude,$longitude);
my %cconfig;
my $content_type = "text/html";
my $cfg = $q->param("cfg");
if (defined $cfg && ($cfg =~ /^[ijrw]$/ ||
		     $cfg eq "widget" || $cfg eq "json")) {
    $content_type = "text/vnd.wap.wml" if $cfg eq "w";
    $content_type = "text/xml" if $cfg eq "r";
    $content_type = "text/javascript" if $cfg eq "j";
    $content_type = "application/json" if $cfg eq "json";
} else {
    undef($cfg);
}

my($evts,$city_descr,$cmd_pretty) = process_args($q,\%cconfig);
my $items = Hebcal::events_to_dict($evts,$cfg,$q,$friday,$saturday,$cconfig{"tzid"});

my $cache = Hebcal::cache_begin($q,0);

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
    my($q,$cconfig) = @_;

    $q->param('cfg', 'w')
	if (defined $ENV{'HTTP_ACCEPT'} &&
	    $ENV{'HTTP_ACCEPT'} =~ /text\/vnd\.wap\.wml/);

    my $cfg = $q->param('cfg');

    if (defined $q->param("city") && $q->param("city") ne "") {
	$q->param("geo", "city");
    }

    my @status = Hebcal::process_args_common($q, 1, 1, $cconfig);
    unless ($status[0]) {
	form($cfg, 1, $status[1], $status[2]);
    }

    my $cmd;
    my $city_descr;
    (undef,$cmd,$latitude,$longitude,$city_descr) = @status;

    $cmd .= ' -c -s';

    # don't do holidays or rosh chodesh for WML
    if (defined $cfg && $cfg eq 'w') {
	$cmd .= ' -h -x';
    }

    my $loc = (defined $city_descr && $city_descr ne '') ?
	"in $city_descr" : '';

    my @events = Hebcal::invoke_hebcal("$cmd $sat_year", $loc, 0);
    if ($sat_year != $fri_year) {
	# Happens when Friday is Dec 31st and Sat is Jan 1st
	my @ev2 = Hebcal::invoke_hebcal("$cmd 12 $fri_year", $loc, 0);
	@events = (@ev2, @events);
    }
    
    (\@events,$city_descr,$cmd);
}

sub url_html {
    my($url) = @_;
    $url =~ s/&/&amp;/g;
    return $url;
}

sub self_url
{
    my($url) = join('', "http://", $q->virtual_host(), $script_name,
			 "?geo=", $q->param('geo'));

    $url .= "&zip=" . $q->param('zip')
	if $q->param('zip');
    $url .= "&city=" . URI::Escape::uri_escape_utf8($q->param('city'))
	if $q->param('city');
    $url .= "&m=" . $q->param('m')
	if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

    $url;
}

sub display_wml
{
    my($items) = @_;

    my $title = 'Hebcal Shabbat Times';
	
    print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";

    Hebcal::out_html($cfg,
qq{<?xml version="1.0"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
"http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
<card id="shabbat2" title="$title">
<!-- $cmd_pretty -->
<p><strong>$city_descr</strong></p>
});

    foreach my $item (@{$items}) {
	my $subj = $item->{'subj'};
	$subj =~ s/^Candle lighting/Candles/;

	Hebcal::out_html($cfg, "<p>$subj");

	if ($item->{'class'} =~ /^(candles|havdalah)$/)
	{
	    my $pm = $item->{'time'};
	    $pm =~ s/pm$/p/;
	    Hebcal::out_html($cfg, ": $pm");
	}
	elsif ($item->{'class'} eq 'holiday')
	{
	    Hebcal::out_html($cfg, "<br/>\n", $item->{'date'});
	}

	Hebcal::out_html($cfg, "</p>\n");
    }

    Hebcal::out_html($cfg, "</card>\n</wml>\n");
    Hebcal::out_html($cfg, "<!-- generated ", scalar(localtime), " -->\n");
}


sub display_json
{
    my($items) = @_;

    print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";

    Hebcal::items_to_json($items,$q,$city_descr,$latitude,$longitude);
}


sub get_link_and_guid {
    my($item_link, $dc_date) = @_;

    my $u = URI->new($item_link);
    my $scheme = $u->scheme;
    my $host   = $u->authority;
    my $path   = $u->path;
    my $query  = $u->query;
    my $frag   = $u->fragment;

    my $utm_param;
    if (defined $cfg) {
	if ($cfg eq "r") {
	    $utm_param = "utm_source=rss&amp;utm_campaign=shabbat1c";
	} else {
	    $utm_param = "utm_source=shabbat1c&amp;utm_campaign=shabbat1c";
	}
    }

    my $link = sprintf("%s://%s%s", $scheme, $host, $path);
    if ($query) {
	$query =~ s/;/&amp;/g;
	$link .= "?$query";
	$link .= "&amp;$utm_param" if defined $utm_param;
    } elsif (defined $utm_param) {
	$link .= "?$utm_param";
    }

    my $guid = $link;
    $guid .= "&amp;dt=" . URI::Escape::uri_escape_utf8($dc_date);

    if ($frag) {
	$link .= "#$frag";
	$guid .= "#$frag";
    }

    return ($link, $guid);
}

sub display_rss
{
    my($items) = @_;

    print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";

    my $url = url_html(self_url());

    my $title = 'Shabbat Times for ' . $city_descr;

    my $lastBuildDate = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time()));

    my $utm_param = "utm_source=rss&amp;utm_campaign=shabbat1c";
    Hebcal::out_html($cfg,
qq{<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<title>$title</title>
<link>$url&amp;$utm_param</link>
<atom:link href="$url&amp;cfg=r" rel="self" type="application/rss+xml" />
<description>Weekly Shabbat candle lighting times for $city_descr</description>
<language>en-us</language>
<copyright>Copyright (c) $this_year Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$lastBuildDate</lastBuildDate>
<!-- $cmd_pretty -->
});

    foreach my $item (@{$items}) {
	my $subj = $item->{'subj'};
	if (defined $item->{'time'}) { 
	    $subj .= ": " . $item->{'time'};
	}

	my($link,$guid) = get_link_and_guid($item->{"link"}, $item->{"dc:date"});

	Hebcal::out_html($cfg, 
qq{<item>
<title>$subj</title>
<link>$link</link>
<guid isPermaLink="false">$guid</guid>
<description>$item->{'date'}</description>
<category>$item->{'class'}</category>
<pubDate>$item->{'pubDate'}</pubDate> 
});

	if ($item->{'class'} eq "candles" && defined $latitude) {
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

    foreach my $item (@{$items}) {
	Hebcal::out_html($cfg,qq{<li class="$item->{'class'}">});

	my $anchor = '';
	if (!$cfg)
	{
	    $anchor = $item->{'about'};
	    $anchor =~ s/^.*#//;
	    $anchor = qq{ id="$anchor"};
	}

	my($link,$guid) = get_link_and_guid($item->{"link"}, $item->{"dc:date"});
	if (defined $cfg && $cfg eq "widget") {
	    $link = "javascript:widget.openURL('" . $link . "');";
	}

	if ($item->{'class'} =~ /^(candles|havdalah)$/)
	{
	    Hebcal::out_html($cfg,qq{<a$anchor></a>})
		unless $cfg;
	    Hebcal::out_html($cfg,qq{$item->{'subj'}: <strong>$item->{'time'}</strong> on $item->{'date'}});
	}
	elsif ($item->{'class'} eq 'holiday')
	{
	    Hebcal::out_html($cfg,qq{<a$anchor target="$tgt" href="$link">$item->{'subj'}</a> occurs on $item->{'date'}});
	}
	elsif ($item->{'class'} eq 'parashat')
	{
	    Hebcal::out_html($cfg,qq{This week\'s Torah portion is <a$anchor target="$tgt" href="$link">$item->{'subj'}</a>});
	}
    
	Hebcal::out_html($cfg,qq{</li>\n});
    }

    Hebcal::out_html($cfg,"</ul>\n");
}

sub display_javascript
{
    my($items) = @_;

    my $shabbat = defined $q->param("a") && $q->param("a") =~ /^(on|1)$/
	? "Shabbos" : "Shabbat";
    my $title = "$shabbat Times for $city_descr";

    if ($cfg eq "i" || $cfg eq "widget") {
	print $q->header(-type => $content_type, -charset => "UTF-8");
	Hebcal::out_html($cfg, qq{<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<style type="text/css">
ul#hebcal-results{list-style-type:none}
</style>
</head>
<body>
});
    } else {
	print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";
    }

    my $loc_class = '';
    if (defined $q->param('zip') && $q->param('zip') ne '') {
	$loc_class = $q->param('zip');
    } else {
	$loc_class = lc($q->param('city'));
	$loc_class =~ s/\s+/-/g; 
    }

    Hebcal::out_html($cfg, qq{<div id="hebcal">\n},
		     qq{<div id="hebcal-$loc_class">\n},
		     qq{<h3>$shabbat times for $city_descr</h3>\n});


    display_html_common($items);

    if ($cfg ne "x") {
    my $tgt = $q->param('tgt') ? $q->param('tgt') : '_top';

    my $url = url_html(self_url() . "&utm_source=shabbat1c&utm_campaign=shabbat1c");
    if ($cfg eq "widget")
    {
	$url = "javascript:widget.openURL('" . $url . "');";
    }

    Hebcal::out_html($cfg, qq{<div class="copyright">
<small>Powered by <a target="$tgt" href="$url">Hebcal $shabbat Times</a></small>
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

    print $q->header(-type => $content_type, -charset => "UTF-8");

    my @description_items;
    foreach my $item (@{$items}) {
	my $datestr = "";
	if ($item->{"dc:date"} =~ /^\d{4}-0?(\d+)-0?(\d+)/) {
	    my $month = $1;
	    my $mday = $2;
	    $datestr = $Hebcal::MoY_short[$month - 1] . " " . $mday;
	}
	if ($item->{"class"} =~ /^(candles|havdalah)$/) {
	    push(@description_items, "$item->{subj} at $item->{time} on $datestr");
	} elsif ($item->{"class"} eq "parashat") {
	    push(@description_items, $item->{subj});
	} elsif ($item->{"class"} eq "holiday") {
	    push(@description_items, "$item->{subj} on $datestr");
	}
    }
    my $xtra_head = qq{<meta name="description" content="}
	. join(". ", @description_items) . qq{.">\n};
    my_head($title,$xtra_head);

    Hebcal::out_html($cfg, $HebcalHtml::indiana_warning)
	if ($city_descr =~ / IN /);

    Hebcal::out_html(undef, $HebcalHtml::usno_warning)
	if (defined $latitude && ($latitude >= 60.0 || $latitude <= -60.0));

    display_html_common($items);

    Hebcal::out_html(undef, "<hr>\n");
    
    more_from_hebcal();

    form($cfg,0,'','');
}

sub get_link_args {
    my($q,$do_havdalah_mins) = @_;

    my $url = "";
    if ($q->param("zip")) {
	$url .= "zip=" . $q->param("zip");
    } else {
	$url .= "city=" . URI::Escape::uri_escape_utf8($q->param("city"));
    }
    foreach my $arg (qw(a i)) {
	$url .= sprintf("&%s=%s", $arg, $q->param($arg))
	    if defined $q->param($arg) && $q->param($arg) =~ /^on|1$/;
    }

    if ($do_havdalah_mins) {
	$url .= "&m=" . $q->param("m")
	    if (defined $q->param("m") && $q->param("m") =~ /^\d+$/);
    }

    $url;
}

sub more_from_hebcal {
    Hebcal::out_html($cfg, qq{<div class="btn-toolbar">\n});

    # link to hebcal full calendar
    my $url = join('', "/hebcal/?v=1&geo=", $q->param('geo'), "&");
    $url .= get_link_args($q, 1);
    $url .= '&vis=on&month=now&year=now&nh=on&nx=on&s=on&c=on&mf=on&ss=on';

    my $month_name = join(" ", $Hebcal::MoY_short[$this_mon-1], $this_year);
    Hebcal::out_html($cfg, qq{<a class="btn" href="},
		     url_html($url),
		     qq{"><i class="icon-calendar"></i> $month_name calendar &raquo;</a>\n});

    # Fridge calendar
    $url = "/shabbat/fridge.cgi?";
    $url .= get_link_args($q, 0);
    $url .= "&year=" . $hyear;
    Hebcal::out_html($cfg, qq{<a class="btn" title="Print and post on your refrigerator"\n},
		     qq{href="}, url_html($url),
		     qq{"><i class="icon-print"></i> Print candle-lighting times &raquo;</a>\n});

    # RSS
    my $rss_href = url_html(self_url() . "&cfg=r");
    my $rss_html = <<EOHTML;
<a class="btn" title="RSS feed of candle lighting times"
href="$rss_href"><img
src="/i/feed-icon-14x14.png" style="border:none" width="14" height="14"
alt="RSS feed of candle lighting times"> RSS feed &raquo;</a>
EOHTML
;

    Hebcal::out_html($cfg, $rss_html);

    # Synagogues link
    $url = "/link/?";
    $url .= get_link_args($q, 1);
    $url .= "&type=shabbat";

    Hebcal::out_html($cfg, qq{<a class="btn" title="Candle lighting and Torah portion for your synagogue site"\n},
		     qq{href="}, url_html($url), qq{"><i class="icon-wrench"></i> Developer API &raquo;</a>\n});

    Hebcal::out_html($cfg, qq{</div><!-- .btn-toolbar -->\n});

    # Email
    my $email_form = <<EOHTML;
<form class="form-inline" action="/email/">
<fieldset>
<input type="hidden" name="v" value="1">
EOHTML
;
    if ($q->param("zip")) {
	$email_form .= qq{<input type="hidden" name="geo" value="zip">\n};
	$email_form .= qq{<input type="hidden" name="zip" value="} . $q->param("zip") . qq{">\n};
    } else {
	$email_form .= qq{<input type="hidden" name="geo" value="city">\n};
	$email_form .= qq{<input type="hidden" name="city" value="} . $q->param("city") . qq{">\n};
    }

    if (defined $q->param("m") && $q->param("m") =~ /^\d+$/) {
	$email_form .= qq{<input type="hidden" name="m" value="} . $q->param("m") . qq{">\n};
    }

    $email_form .= <<EOHTML;
<p><small>Subscribe to weekly Shabbat candle lighting times and Torah portion by email.</small></p>
<div class="input-append input-prepend">
<span class="add-on"><i class="icon-envelope"></i></span><input type="email" name="em" placeholder="Email address">
<button type="submit" class="btn" name="modify" value="1"> Sign up</button>
</div>
</fieldset>
</form>
EOHTML
;
    Hebcal::out_html($cfg, $email_form);
}

sub my_head {
    my($title,$xtra_head) = @_;
    my $rss_href = url_html(self_url() . "&cfg=r");
    my $xtra_head2 = <<EOHTML;
<link rel="alternate" type="application/rss+xml" title="RSS" href="$rss_href">
<style type="text/css">
ul#hebcal-results { list-style-type:none }
ul#hebcal-results li {
  margin-bottom: 11px;
  font-size: 21px;
  font-weight: 200;
  line-height: normal;
}
.pseudo-legend {
  font-size: 17px;
  font-weight: bold;
  line-height: 30px;
}
</style>
EOHTML
;
    $city_descr ||= "UNKNOWN";
	my $head_divs = <<EOHTML;
<div class="span10">
<div class="page-header">
<h1>Shabbat Times <small>$city_descr</small></h1>
</div>

EOHTML
;
	Hebcal::out_html($cfg,
			 Hebcal::html_header_bootstrap($title,
					     $script_name,
					     "single single-post",
					     $xtra_head . $xtra_head2),
			 $head_divs
	    );
}

sub form($$$$)
{
    my($cfg,$head,$message,$help) = @_;

    print $q->header(-type => $content_type, -charset => "UTF-8") if $head;

    if ($message ne "" && defined $cfg) {
	if ($cfg eq "j") {
	    $message =~ s/\"/\\"/g;
	    print STDOUT qq{alert("Error: $message");\n};
	} elsif ($cfg eq "r") {
	    print STDOUT "<error><![CDATA[$message]]></error>\n";
	} elsif ($cfg eq "json") {
	    $message =~ s/\"/\\"/g;
	    print STDOUT "{\"error\":\"$message\"}\n";
	} else {
	    print STDOUT $message, "\n";
	}
	exit(0);
    }

    my_head("Shabbat Candle Lighting Times","") if $head;

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
	$message = qq{<div class="alert alert-error alert-block">\n} .
	    qq{<button type="button" class="close" data-dismiss="alert">&times;</button>\n} .
	    $message . $help . "</div>";
    }

    Hebcal::out_html($cfg,
	qq{$message\n},
	qq{<div id="hebcal-form-zipcode" class="well well-small">\n},
	qq{<div class="pseudo-legend">World cities</div>\n});

    Hebcal::out_html(undef, qq{<div class="btn-toolbar">\n});
    my %groups;
    while(my($id,$info) = each(%HebcalConst::CITIES_NEW)) {
	my($country,$city,$latitude,$longitude,$tzName,$woeid) = @{$info};
	my $grp = ($country =~ /^US|CA|IL$/)
	    ? $country
	    : $HebcalConst::COUNTRIES{$country}->[1];
	$groups{$grp} = [] unless defined $groups{$grp};
	push(@{$groups{$grp}}, [$id, $country, Hebcal::woe_country($id), $city]);
    }
    foreach my $grp (qw(US CA IL EU NA SA AS OC AF AN)) {
	next unless defined $groups{$grp};
	my $label;
	if ($grp eq "US") {
	    $label = "USA";
	} elsif ($grp eq "CA" || $grp eq "IL") {
	    $label = $HebcalConst::COUNTRIES{$grp}->[0];
	} else {
	    $label = $Hebcal::CONTINENTS{$grp};
	}
	my $btn_html=<<EOHTML;
<div class="btn-group">
<button class="btn btn-primary dropdown-toggle" data-toggle="dropdown">$label <span class="caret"></span></button>
<ul class="dropdown-menu">
EOHTML
;
	foreach my $info (sort {$a->[3] cmp $b->[3]} @{$groups{$grp}}) {
	    my($id,$cc,$country,$city) = @{$info};
	    my $city_country = $city;
	    $country = "UK" if $country eq "United Kingdom";
	    $city_country .= ", $country" unless $grp=~ /^US|CA|IL$/;

	    my $url = "/shabbat/?city=" . URI::Escape::uri_escape_utf8($id);
	    $btn_html .= qq{<li><a href="$url">$city_country</a></li>\n};
	}
	$btn_html .= qq{</ul></div><!-- /btn-group -->\n};
	Hebcal::out_html(undef, $btn_html);
    }

    Hebcal::out_html(undef, qq{</div><!-- .btn-toolbar -->\n});

    Hebcal::out_html($cfg,
	qq{<div class="pseudo-legend">United States of America</div>\n});

    Hebcal::out_html($cfg,
	qq{<form action="$script_name">},
	qq{<fieldset>\n},
	$q->hidden(-name => 'geo',
		   -value => 'zip',
		   -override => 1),
	qq{<label for="zip">ZIP code:\n},
	$q->textfield(-name => 'zip',
		      -id => 'zip',
		      -pattern => '\d*',
		      -class => 'input-mini',
		      -size => 5,
		      -maxlength => 5),
	qq{</label>});

    Hebcal::out_html($cfg,
	qq{<label>Havdalah minutes past sundown:\n},
	$q->textfield(-name => 'm',
		      -id => 'm1',
		      -pattern => '\d*',
		      -style => "width:auto",
		      -size => 2,
		      -maxlength => 2,
		      -default => $Hebcal::havdalah_min),
	qq{&nbsp;<a href="#" id="havdalahInfo" data-toggle="tooltip" data-placement="right" },
	qq{title="Use 42 min for three medium-sized stars, },
	qq{50 min for three small stars, },
	qq{72 min for Rabbeinu Tam, or 0 to suppress Havdalah times"><i class="icon icon-info-sign"></i></a>},
	"</label>",
	qq{<input\ntype="submit" value="Get Shabbat Times" class="btn btn-primary">\n},
	qq{</fieldset></form>});

    Hebcal::out_html(undef, qq{</div><!-- #hebcal-form-zipcode -->\n});

    my $footer_divs2=<<EOHTML;
</div><!-- .span10 -->
<div class="span2" role="complementary">
<h5>Advertisement</h5>
<script async src="http://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- skyscraper text only -->
<ins class="adsbygoogle"
     style="display:inline-block;width:160px;height:600px"
     data-ad-client="ca-pub-7687563417622459"
     data-ad-slot="7666032223"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .span2 -->
EOHTML
;
    Hebcal::out_html(undef, $footer_divs2);

    Hebcal::out_html(undef, Hebcal::html_footer_bootstrap($q,undef,1));
    Hebcal::out_html($cfg, "<script>\$('#havdalahInfo').tooltip()</script>\n");
    Hebcal::out_html($cfg, "</body></html>\n");
    Hebcal::out_html($cfg, "<!-- generated ", scalar(localtime), " -->\n");
    Hebcal::cache_end() if $cache;
    exit(0);
}

sub get_saturday
{
    my($q) = @_;

    my($gy,$gm,$gd,$dow);
    if (defined $q->param("gy") && $q->param("gy") =~ /^\d+$/
	&& defined $q->param("gm") && $q->param("gm") =~ /^\d+$/
	&& defined $q->param("gd") && $q->param("gd") =~ /^\d+$/) {
	($gy,$gm,$gd) = ($q->param("gy"),$q->param("gm"),$q->param("gd"));
	$dow = Hebcal::get_dow($gy,$gm,$gd);
    } else {
	my $now;
	if (defined $q->param('t') && $q->param('t') =~ /^\d+$/) {
	    $now = $q->param('t');
	} else {
	    $now = time();
	}
	my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	    localtime($now);
	($gy,$gm,$gd) = ($year+1900,$mon+1,$mday);
	$dow = $wday;
    }

    my $friday = Time::Local::timelocal(0,0,0,$gd,$gm-1,$gy);

    my $saturday = ($dow == 6)
	? $friday + (60 * 60 * 24)
	: $friday + ((6 - $dow) * 60 * 60 * 24) + 3601;
    my $sat_year = (localtime($saturday))[5] + 1900;

    ($friday,$gy,$saturday,$sat_year);
}

# local variables:
# mode: cperl
# end:
