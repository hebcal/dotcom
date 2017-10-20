#!/usr/bin/perl -w

########################################################################
# Hebcal Shabbat Times generates weekly Shabbat candle lighting times
# and Parsha HaShavua from Hebcal information.
#
# Copyright (c) 2017  Michael J. Radwin.
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
use POSIX qw(strftime tzset);

use Benchmark qw(:hireswallclock :all);

my $t0 = Benchmark->new;

# process form params
my($q) = new CGI;

if (defined $ENV{'REQUEST_METHOD'} && $ENV{'REQUEST_METHOD'} eq "POST" && $ENV{'QUERY_STRING'}) {
    print STDOUT "Allow: GET\n";
    print STDOUT $q->header(-type => "text/plain",
                            -status => "405 Method Not Allowed");
    print STDOUT "POST not allowed; try using GET instead.\n";
    exit(0);
}

my($script_name) = $q->script_name();
$script_name =~ s,/[^/]+$,/,;
my $is_legacy_js = (defined $ENV{'QUERY_STRING'}
    && $ENV{'QUERY_STRING'} =~ /^geo=zip;zip=\d+;m=\d+;cfg=j$/) ? 1 : 0;

foreach my $key ($q->param()) {
    my $val = $q->param($key);
    if (defined $val) {
        my $orig = $val;
        if ($key eq "city" || $key eq "city-typeahead") {
            $val = decode_utf8($val);
        } elsif ($key eq "tzid") {
            $val =~ s/[^\/\w\.\s-]//g; # allow forward-slash in tzid
        } else {
            # sanitize input to prevent people from trying to hack the site.
            # remove anthing other than word chars, white space, or hyphens.
            $val =~ s/[^\w\.\s-]//g;
        }
        $val =~ s/^\s+//g;              # nuke leading
        $val =~ s/\s+$//g;              # and trailing whitespace
        $q->param($key, $val) if $val ne $orig;
    }
}

foreach my $opt (qw(maj min mod mf ss nx)) {
    $q->param($opt, "on") unless defined $q->param($opt);
}

my($this_year,$this_mon,$this_day) = Date::Calc::Today();
my $hyear = Hebcal::get_default_hebrew_year($this_year,$this_mon,$this_day);

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

my($latitude,$longitude);
my %cconfig;
my($city_descr,$cmd) = process_args($q,\%cconfig);

if ($cconfig{"tzid"}) {
    $ENV{TZ} = $cconfig{"tzid"};
    tzset();
}
my($friday,$fri_year,$saturday,$sat_year) = get_saturday($q);

my $hebcal_cookies = Hebcal::get_cookies($q);
if (defined $hebcal_cookies->{"C"}) {
    # private cache only if we're tailoring results by cookie
    print "Cache-Control: private\015\012";
} elsif (defined $ENV{'QUERY_STRING'} && $ENV{'QUERY_STRING'} !~ /^\s*$/) {
    # only set expiry if there are CGI arguments
    print "Cache-Control: max-age=86400\015\012";
}

my $evts = get_events($city_descr,$cmd,$fri_year,$sat_year);

my $ignore_tz = (defined $cfg && ($cfg eq "r" || $cfg eq "json")) ? 0 : 1;
my $include_leyning = (defined $cfg && $cfg eq "json" && !$leyning eq "n") ? 1 : 0;
my $items = Hebcal::events_to_dict($evts,$cfg,$q,$friday,$saturday,
    $cconfig{"tzid"},$ignore_tz,
    $include_leyning,
    $cconfig{"tzid"} eq "Asia/Jerusalem" ? 1 : 0);
my $cmd_pretty = $cmd;

my $rss_href = url_html("/shabbat/?cfg=r&" . get_link_args($q) . "&pubDate=0");

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

exit(0);

sub out_html {
    my($cfg,@args) = @_;

    if (defined $cfg && $cfg eq 'j') {
        if ($is_legacy_js) {
            print STDOUT "document.write(\"";
        } else {
            print STDOUT "\"";
        }
        foreach (@args) {
            s/\"/\\\"/g;
            s/\n/\\n/g;
            print STDOUT;
        }
        if ($is_legacy_js) {
            print STDOUT "\");\n";
        } else {
            print STDOUT "\",";
        }
    }
    else {
        foreach (@args) {
            print STDOUT;
        }
    }

    1;
}

sub possibly_set_cookie {
    my $cookies = Hebcal::get_cookies($q);
    my $newcookie = Hebcal::gen_cookie($q);
    if (! defined $cookies->{"C"}) {
        my_set_cookie($newcookie);
    } else {
        my $cmp1 = $newcookie;
        my $cmp2 = $cookies->{"C"};

        $cmp1 =~ s/^C=t=\d+\&?//;
        $cmp2 =~ s/^t=\d+\&?//;

        my_set_cookie($newcookie) if $cmp1 ne $cmp2;
    }
}

sub my_set_cookie {
    my($str) = @_;
    if ($str =~ /&/) {
        my $cookie_expires = "Tue, 02-Jun-2037 20:00:00 GMT";
        print STDOUT "Cache-Control: private\015\012Set-Cookie: ",
        $str, "; expires=", $cookie_expires, "; path=/\015\012";
    }
}

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

    if (! defined $q->param('m')) {
        $q->param('m', $Hebcal::havdalah_min);
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

    ($city_descr,$cmd);
}

sub get_events {
    my($city_descr,$cmd,$fri_year,$sat_year) = @_;
    my $no_havdalah = (defined $q->param('m') && $q->param('m') eq "0") ? 1 : 0;

    my @events = Hebcal::invoke_hebcal_v2("$cmd $sat_year", "", 0,
        0, 0, 0, 0, 0, $no_havdalah);
    if ($sat_year != $fri_year) {
        # Happens when Friday is Dec 31st and Sat is Jan 1st
        my @ev2 = Hebcal::invoke_hebcal_v2("$cmd 12 $fri_year", "", 0,
            0, 0, 0, 0, 0, $no_havdalah);
        @events = (@ev2, @events);
    }

    \@events;
}

sub url_html {
    my($url) = @_;
    $url =~ s/&/&amp;/g;
    return $url;
}

sub self_url
{
    my $url = join('',
                   "http://", $q->virtual_host(), $script_name,
                   "?geo=", scalar $q->param('geo'), "&", get_link_args($q));
    $url;
}

sub timestamp_comment {
    my $tend = Benchmark->new;
    my $tdiff = timediff($tend, $t0);
    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime(time())) . "Z";
    out_html($cfg, "<!-- generated ", $dc_date, "; ",
        timestr($tdiff), " -->\n");
}

sub display_wml
{
    my($items) = @_;

    my $title = 'Hebcal Shabbat Times';

    print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";

    out_html($cfg,
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

        out_html($cfg, "<p>$subj");

        if ($item->{'class'} =~ /^(candles|havdalah)$/)
        {
            my $pm = $item->{'time'};
            $pm =~ s/pm$/p/;
            out_html($cfg, ": $pm");
        }
        elsif ($item->{'class'} =~ /^(holiday|roshchodesh)$/)
        {
            out_html($cfg, "<br/>\n", $item->{'date'});
        }

        out_html($cfg, "</p>\n");
    }

    out_html($cfg, "</card>\n</wml>\n");
    timestamp_comment();
}


sub display_json
{
    my($items) = @_;

    print "Access-Control-Allow-Origin: *\015\012";
    print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";

    Hebcal::items_to_json($items,$q,$city_descr,undef,undef,\%cconfig);
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
            $utm_param = "utm_source=shabbat1c&amp;utm_medium=rss";
        } else {
            $utm_param = "utm_source=shabbat1c&amp;utm_medium=js";
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
    if (defined $dc_date) {
        $guid .= "&amp;dt=" . URI::Escape::uri_escape_utf8($dc_date);
    }

    if ($frag) {
        $link .= "#$frag";
        $guid .= "#$frag";
    }

    return ($link, $guid);
}

sub evt_pubdate {
    my($evt) = @_;

    my $sec = 0;
    my $min = $evt->{min};
    my $hour24 = $evt->{hour};
    if ($evt->{untimed}) {
        $min = $hour24 = 0;
        $sec = 1;
    }
    my $time = Time::Local::timelocal($sec,$min,$hour24,
        $evt->{mday},
        $evt->{mon},
        $evt->{year} - 1900,
        "","","");
    return strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime($time));
}

sub display_rss
{
    my($items) = @_;

    print "Access-Control-Allow-Origin: *\015\012";
    print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";

    my $url = url_html(self_url());

    my $title = 'Shabbat Times for ' . $city_descr;

    my $lastBuildDate = strftime("%a, %d %b %Y %H:%M:%S GMT", gmtime(time()));

    my $lang = defined $q->param("lg") && index($q->param("lg"), "h") > -1 ? "he" : "en-us";
    my $utm_param = "utm_source=shabbat1c&amp;utm_medium=rss";
    out_html($cfg,
qq{<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<title>$title</title>
<link>$url&amp;$utm_param</link>
<atom:link href="$url&amp;cfg=r" rel="self" type="application/rss+xml" />
<description>Weekly Shabbat candle lighting times for $city_descr</description>
<language>$lang</language>
<copyright>Copyright (c) $this_year Michael J. Radwin. All rights reserved.</copyright>
<lastBuildDate>$lastBuildDate</lastBuildDate>
<!-- $cmd_pretty -->
});

    my $evtPubDate = 1;
    if (defined $q->param("pubDate")) {
        $evtPubDate = $q->param("pubDate") ? 1 : 0;
    }

    foreach my $item (@{$items}) {
        my $subj = $lang eq "he" ? $item->{'hebrew'} : $item->{'subj'};
        if (defined $item->{'time'}) {
            $subj .= ": " . $item->{'time'};
        }

        my $pubDate = $evtPubDate ? evt_pubdate($item->{"evt"}) : $lastBuildDate;
        my($link,$guid) = get_link_and_guid($item->{"link"}, $item->{"dc:date"});

        out_html($cfg,
qq{<item>
<title>$subj</title>
<link>$link</link>
<guid isPermaLink="false">$guid</guid>
<description>$item->{'date'}</description>
<category>$item->{'class'}</category>
<pubDate>$pubDate</pubDate>
});

        if ($item->{'class'} eq "candles" && defined $latitude) {
            out_html($cfg,
qq{<geo:lat>$latitude</geo:lat>
<geo:long>$longitude</geo:long>
});
      }

        out_html($cfg, "</item>\n");
    }

    out_html($cfg, "</channel>\n</rss>\n");
    timestamp_comment();
}

sub display_html_common
{
    my($items) = @_;

    out_html($cfg,"<!-- $cmd_pretty -->\n");
    out_html($cfg,"<ul class=\"hebcal-results\">\n");

    my $tgt = $q->param('tgt') ? $q->param('tgt') : '_top';

    foreach my $item (@{$items}) {
        my $anchor = '';
        if (!$cfg)
        {
            $anchor = $item->{'about'};
            $anchor =~ s/^.*#//;
            $anchor = qq{ id="$anchor"};
        }

        out_html($cfg,qq{<li class="$item->{'class'}"$anchor>});

        my($link,$guid) = get_link_and_guid($item->{"link"}, $item->{"dc:date"});
        if (defined $cfg && $cfg eq "widget") {
            $link = "javascript:widget.openURL('" . $link . "');";
        }

        if ($item->{class} eq 'parashat') {
            out_html($cfg,qq{This week\'s Torah portion is <a target="$tgt" href="$link">$item->{'subj'}</a>});
        } elsif ($item->{class} =~ /^(candles|havdalah|holiday|roshchodesh)$/) {
            my $html = "";
            if ($item->{class} =~ /^(holiday|roshchodesh)$/) {
                $html = qq{<a target="$tgt" href="$link">};
            }
            $html .= $item->{subj};
            if ($item->{class} =~ /^(holiday|roshchodesh)$/) {
                $html .= qq{</a>};
            }
            if (defined $item->{time}) {
                $html .= qq{: <time datetime="$item->{'dc:date'}"><strong>$item->{'time'}</strong> on $item->{'date'}</time>};
            } else {
                $html .= qq{ occurs on <time datetime="$item->{'dc:date'}">$item->{'date'}</time>};
            }
            out_html($cfg,$html);
        }

        out_html($cfg,qq{</li>\n});
    }

    out_html($cfg,"</ul>\n");
}

sub display_javascript
{
    my($items) = @_;

    my $shabbat = defined $q->param("a") && $q->param("a") =~ /^(on|1)$/
        ? "Shabbos" : "Shabbat";
    my $title = "$shabbat Times for $city_descr";

    if ($cfg eq "i" || $cfg eq "widget") {
        print $q->header(-type => $content_type, -charset => "UTF-8");
        out_html($cfg, qq{<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title</title>
<style type="text/css">
ul.hebcal-results{list-style-type:none}
</style>
</head>
<body>
});
    } else {
        print "Access-Control-Allow-Origin: *\015\012";
        print "Content-Type: $content_type; charset=UTF-8\015\012\015\012";
    }

    print "document.write(["
        if $cfg eq "j" && !$is_legacy_js;

    my $loc_class = '';
    if ($cconfig{"geo"} eq "zip") {
        $loc_class = $cconfig{"zip"};
    } elsif ($cconfig{"geo"} eq "geoname") {
        $loc_class = $cconfig{"geonameid"};
    } elsif ($cconfig{"geo"} eq "city") {
        $loc_class = lc($q->param('city'));
        $loc_class =~ s/\s+/-/g;
    }

    out_html($cfg, qq{<div id="hebcal" class="hebcal-container">\n},
                     qq{<div class="hebcal-$loc_class">\n},
                     qq{<h3>$shabbat times for $city_descr</h3>\n});


    display_html_common($items);

    if ($cfg ne "x") {
    my $tgt = $q->param('tgt') ? $q->param('tgt') : '_top';

    my $url = url_html(self_url() . "&utm_source=shabbat1c&utm_medium=js");
    if ($cfg eq "widget")
    {
        $url = "javascript:widget.openURL('" . $url . "');";
    }

    out_html($cfg, qq{<div class="copyright">
<small>Powered by <a target="$tgt" href="$url">Hebcal $shabbat Times</a></small>
</div><!-- .copyright -->
</div><!-- .hebcal-$loc_class -->
</div><!-- .hebcal-container -->
});
    }

    if ($cfg eq "i" || $cfg eq "widget") {
        out_html($cfg, "</body></html>\n");
    }

    timestamp_comment();

    print "''].join(''));\n"
        if $cfg eq "j" && !$is_legacy_js;
}

sub get_json_ld_admin1 {
    if (defined $cconfig{admin1} && $cconfig{admin1} ne $cconfig{city}) {
        return qq/\n      "addressRegion" : "$cconfig{admin1}",/;
    } elsif (defined $cconfig{state}) {
        return qq/\n      "addressRegion" : "$cconfig{state}",/;
    } else {
        return "";
    }
}

sub json_ld_markup {
    my($items) = @_;

    foreach my $item (@{$items}) {
        if ($item->{"class"} eq "candles") {
            my $startDate = $item->{"dc:date"};
            my $admin1 = get_json_ld_admin1();
            my $s = <<EOHTML;
<script type="application/ld+json">
{
  "\@context" : "http://schema.org",
  "\@type" : "Event",
  "name" : "Candle Lighting for $cconfig{city} at $item->{time}",
  "startDate" : "$startDate",
  "location" : {
    "\@type" : "Place",
    "name" : "$city_descr",
    "address" : {
      "\@type" : "PostalAddress",
      "addressLocality" : "$cconfig{city}",$admin1
      "addressCountry" : "$cconfig{country}"
    },
    "geo" : {
      "\@type" : "GeoCoordinates",
      "latitude" : $latitude,
      "longitude" : $longitude
    }
  }
}
</script>
EOHTML
;
            return $s;
        }
    }

    return "";
}

sub display_html
{
    my($items) = @_;

    my $title = "Shabbat Candle Lighting Times for $city_descr";

    possibly_set_cookie();
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
        } elsif ($item->{"class"} =~ /^(holiday|roshchodesh)$/) {
            push(@description_items, "$item->{subj} on $datestr");
        }
    }

    my $xtra_head = qq{<meta name="description" content="}
        . join(". ", @description_items) . qq{.">\n};
    $xtra_head .= json_ld_markup($items);

    my_head($title,$xtra_head);

    out_html($cfg, $HebcalHtml::indiana_warning)
        if ($city_descr =~ / IN /);

    out_html($cfg, $HebcalHtml::arizona_warning)
        if (defined $cconfig{"state"} && $cconfig{"state"} eq "AZ"
            && defined $cconfig{"tzid"} && $cconfig{"tzid"} eq "America/Denver");

    out_html(undef, $HebcalHtml::usno_warning)
        if (defined $latitude && ($latitude >= 60.0 || $latitude <= -60.0));

    display_html_common($items);

    form($cfg,0,'','');
}

sub get_link_args {
    my($q) = @_;

    my $url = Hebcal::get_geo_args($q);

    foreach my $arg (qw(a i)) {
        $url .= sprintf("&%s=%s", $arg, scalar $q->param($arg))
            if defined $q->param($arg) && $q->param($arg) =~ /^on|1$/;
    }

    $url .= "&m=" . $q->param("m")
        if (defined $q->param("m") && $q->param("m") =~ /^\d+$/);

    $url .= "&lg=" . $q->param("lg") if $q->param("lg");

    $url;
}

sub more_from_hebcal {
    # Fridge calendar
    my $url = "/shabbat/fridge.cgi?";
    $url .= get_link_args($q);
    $url .= "&year=" . $hyear;
    my $fridge_href = url_html($url);

    # link to hebcal full calendar
    $url = join('', "/hebcal/?v=1&geo=", $cconfig{"geo"}, "&");
    $url .= get_link_args($q);
    $url .= '&month=x&year=now';
    foreach my $opt (qw(c s maj min mod mf ss nx)) {
        $url .= join("", "&", $opt, "=on");
    }
    my $full_calendar_href = url_html($url);
    my $developer_api_href = url_html("/link/?" . get_link_args($q));

    my $email_url = "https://www.hebcal.com/email/?geo=" . $cconfig{"geo"} . "&amp;";
    $email_url .= Hebcal::get_geo_args($q, "&amp;");
    $email_url .= "&amp;m=" . $q->param("m")
        if defined $q->param("m") && $q->param("m") =~ /^\d+$/;

    my $html = <<EOHTML;
<div style="padding-bottom:16px">
<h4>$cconfig{"city"}</h4>
<ul class="list-unstyled nav-list">
  <li>
    <span class="glyphicon glyphicon-print"></span>
    <a title="Compact candle-lighting times for $hyear" href="$fridge_href"> Print $hyear</a>
  </li>
  <li><span class="glyphicon glyphicon-calendar"></span> <a href="$full_calendar_href">Monthly calendar</a></li>
  <li><span class="glyphicon glyphicon-envelope"></span> <a href="$email_url">Email weekly Shabbat times</a></li>
  <li>
  <img src="data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgd2lkdGg9IjI0IiBoZWlnaHQ9IjI0Ij4KPGc+CjxwYXRoIGQ9Ik0yMS41LDAgTDIuNSwwIEMxLjEyNSwwIDAsMS4xMjUgMCwyLjUgTDAsMjEuNSBDMCwyMi44NzUgMS4xMjUsMjQgMi41LDI0IEwyMS41LDI0IEMyMi44NzUsMjQgMjQsMjIuODc1IDI0LDIxLjUgTDI0LDIuNSBDMjQsMS4xMjUgMjIuODc1LDAgMjEuNSwwIE02LjE4MiwxOS45OCBDNC45NzcsMTkuOTggNCwxOS4wMDUgNCwxNy44IEM0LDE2LjU5NiA0Ljk3NywxNS42MTkgNi4xODIsMTUuNjE5IEM3LjM4NSwxNS42MTkgOC4zNjQsMTYuNTk2IDguMzY0LDE3LjggQzguMzYzLDE5LjAwNSA3LjM4NSwxOS45OCA2LjE4MiwxOS45OCBNMTEuNjUzLDIwIEMxMS42NTMsMTcuOTQzIDEwLjg1NSwxNi4wMDYgOS40MSwxNC41NTMgQzcuOTY3LDEzLjEwMiA2LjA1NiwxMi4zMDIgNCwxMi4zMDIgTDQsOS4xNTMgQzkuODI2LDkuMTUzIDE0LjgwMywxNC4xNzQgMTQuODAzLDIwLjAwMSBMMTEuNjUzLDIwLjAwMSBMMTEuNjUzLDIwIE0xNy4yMTcsMjAgQzE3LjIxNywxMi42NzcgMTEuMTk4LDYuNzE5IDQsNi43MTkgTDQsMy41NyBDMTIuOTEsMy41NyAyMC4zNjUsMTAuOTQgMjAuMzY1LDIwIEwxNy4yMTcsMjAgWiIvPgo8L2c+Cjwvc3ZnPgo=" width="14" height="14">
  <a title="RSS feed of candle lighting times" href="$rss_href">RSS feed</a></li>
  <li><span class="glyphicon glyphicon-wrench"></span> <a rel="nofollow" title="Candle lighting and Torah portion for your synagogue site" href="$developer_api_href">Developer API</a></li>
</ul>
</div>
EOHTML
;

    return $html;
}

sub my_head {
    my($title,$xtra_head) = @_;
    my $rss_href2 = "http://" . $q->virtual_host() . $rss_href;
    my $xtra_head2 = <<EOHTML;
<link rel="alternate" type="application/rss+xml" title="RSS" href="$rss_href2">
<link rel="stylesheet" type="text/css" href="/i/hyspace-typeahead.css">
<style type="text/css">
ul.hebcal-results {
  list-style-type:none;
  padding-left: 0;
}
ul.hebcal-results li {
  margin-bottom: 11px;
  font-size: 21px;
  font-weight: 200;
  line-height: normal;
}
ul.list-unstyled.nav-list li {
  margin-bottom: 6px;
}
</style>
EOHTML
;
    $city_descr ||= "UNKNOWN";
    my $head_divs = <<EOHTML;
<div class="row">
<div class="col-sm-9">
<h1>Shabbat Times <small>$city_descr</small></h1>
EOHTML
;

    out_html($cfg,
        HebcalHtml::header_bootstrap3($title, $script_name, "",
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
        out_html($cfg,qq{<p>$message</p>\n},
                  qq{<do type="accept" label="Back">\n},
                  qq{<prev/>\n</do>\n</card>\n</wml>\n});
        exit(0);
    }

    if ($message ne '')
    {
        $help = '' unless defined $help;
        $message = qq{<div class="alert alert-danger alert-dismissible">\n} .
            qq{<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>\n} .
            $message . $help . "</div>";
    }

    out_html($cfg, $message);

    my $form_hidden = join("",
        $q->hidden(-name => "geo",
                   -id => "geo",
                   -default => "geoname"),
        $q->hidden(-name => "zip", -id => "zip"),
        $q->hidden(-name => "city", -id => "city"),
        $q->hidden(-name => "geonameid", -id => "geonameid"),
    );
    my $form_city_typeahead = $q->textfield(
        -name => "city-typeahead",
        -id => "city-typeahead",
        -class => "form-control typeahead",
        -default => $cconfig{"title"},
        -placeholder => "Search for city or ZIP code");
    my $form_havdalah_min = $q->textfield(
        -name      => "m",
        -id        => "m1",
        -pattern   => '\d*',
        -class     => "form-control",
        -style     => "width:60px",
        -size      => 2,
        -maxlength => 2,
        -default   => $Hebcal::havdalah_min
    );

    my $form_html = <<EOHTML;
<hr>
<form action="/shabbat/" method="get" role="form" id="shabbat-form">
$form_hidden
  <div class="form-group">
    <label for="city-typeahead">City</label>
    <div class="city-typeahead" style="margin-bottom:12px">
      $form_city_typeahead
    </div>
  </div>
  <div class="form-group">
    <label for="m1">
      Havdalah minutes past sundown
      <a href="#" id="havdalahInfo" data-toggle="tooltip" data-placement="top" title="Use 42 min for three medium-sized stars, 50 min for three small stars, 72 min for Rabbeinu Tam, or 0 to suppress Havdalah times"><span class="glyphicon glyphicon-info-sign"></span></a>
    </label>
    $form_havdalah_min
  </div>
  <input type="submit" value="Get Shabbat Times" class="btn btn-primary">
</form>
EOHTML
;

    out_html($cfg, $form_html);

    my $more_from_hebcal = $cconfig{"geo"} ? more_from_hebcal() : "";

    my $footer_divs2=<<EOHTML;
<hr>
<p>Shabbat times for world cities</p>
<ul class="bullet-list-inline">
<li><a href="/shabbat/?city=IL-Jerusalem">Jerusalem</a></li>
<li><a href="/shabbat/?city=IL-Tel%20Aviv">Tel Aviv</a></li>
<li><a href="/shabbat/?city=US-New%20York-NY">New York</a></li>
<li><a href="/shabbat/?city=US-Los%20Angeles-CA">Los Angeles</a></li>
<li><a href="/shabbat/?city=GB-London">London</a></li>
<li><a href="/shabbat/?city=US-Miami-FL">Miami</a></li>
<li><a href="/shabbat/?city=CA-Montreal">Montreal</a></li>
<li><a href="/shabbat/?city=US-Baltimore-MD">Baltimore</a></li>
<li><a href="/shabbat/?city=CA-Toronto">Toronto</a></li>
<li><a href="/shabbat/?geonameid=5100280">Lakewood, NJ</a></li>
<li><a href="/shabbat/?city=US-Chicago-IL">Chicago</a></li>
<li><a href="/shabbat/?geonameid=5110302">Brooklyn</a></li>
<li><a href="/shabbat/?city=US-San%20Francisco-CA">San Francisco</a></li>
<li><a href="/shabbat/?geonameid=4148411">Boca Raton</a></li>
<li><a href="/shabbat/?city=US-Washington-DC">Washington, DC</a></li>
<li><a href="/shabbat/?geonameid=5809844">Seattle</a></li>
<li><a href="/shabbat/?city=AU-Melbourne">Melbourne</a></li>
<li><a href="/shabbat/?city=US-Boston-MA">Boston</a></li>
<li><a href="/shabbat/?city=CA-Toronto">Toronto</a></li>
<li><a href="/shabbat/browse/">More ...</a></li>
</ul>
</div><!-- .col-sm-9 -->
<div class="col-sm-3" role="complementary">
$more_from_hebcal
<h5>Advertisement</h5>
<script async src="//pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
<!-- responsive textonly -->
<ins class="adsbygoogle"
     style="display:block"
     data-ad-client="ca-pub-7687563417622459"
     data-ad-slot="5981467974"
     data-ad-format="auto"></ins>
<script>
(adsbygoogle = window.adsbygoogle || []).push({});
</script>
</div><!-- .col-sm-3 -->
</div><!-- .row -->
EOHTML
;
    out_html(undef, $footer_divs2);


    my $xtra_html=<<JSCRIPT_END;
<script src="$Hebcal::JS_TYPEAHEAD_BUNDLE_URL"></script>
<script src="$Hebcal::JS_APP_URL"></script>
<script type="text/javascript">
window['hebcal'].createCityTypeahead(false);
\$('#havdalahInfo').click(function(e){e.preventDefault()}).tooltip();
</script>
JSCRIPT_END
        ;

    delete $ENV{'SCRIPT_FILENAME'};
    out_html(undef, HebcalHtml::footer_bootstrap3($q, undef, 1, $xtra_html));
    out_html($cfg, "</body></html>\n");
    timestamp_comment();
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
