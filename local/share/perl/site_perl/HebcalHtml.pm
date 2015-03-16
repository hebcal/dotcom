########################################################################
# Copyright (c) 2015 Michael J. Radwin.
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

package HebcalHtml;

use strict;
use URI::Escape;
use POSIX qw(strftime);
use CGI qw(-no_xhtml);

$HebcalHtml::gregorian_warning = qq{<div class="alert alert-warning alert-dismissible">
<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
<strong>Warning!</strong>
Results for year 1752 C.E. and earlier may be inaccurate.
<p>Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation.<sup><a
href="http://en.wikipedia.org/wiki/Gregorian_calendar#Adoption_in_Europe">[1]</a></sup></p>
</div><!-- .alert -->
};

$HebcalHtml::indiana_warning = qq{<div class="alert alert-warning alert-dismissible">
<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
<strong>Warning!</strong>
Indiana has confusing time zone &amp; Daylight Saving Time
rules.</span><br>Please check <a
href="http://en.wikipedia.org/wiki/Time_in_Indiana">What time is it in
Indiana?</a> to make sure the above settings are correct.
</div><!-- .alert -->
};

$HebcalHtml::usno_warning =  qq{<div class="alert alert-warning alert-dismissible">
<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
<strong>Warning!</strong>
Candle-lighting times are guaranteed to be wrong at extreme
northern or southern latitudes.</span><br>Please consult your
local halachic authority for correct candle-lighting times.
</div><!-- .alert -->
};

sub tab_body {
    my($tab) = @_;
    my($short_title,$long_title,$slug,$content) = @{$tab};
    my $class_xtra = $slug eq "ios" ? " active" : "";
    my $s = <<EOHTML;
<div id="${slug}-body" class="tab-pane$class_xtra">
<p class="lead">$long_title</p>
<div>
$content
</div>
</div><!-- #${slug}-body -->
EOHTML
;
    return $s;
}

sub download_button_html {
    my($q,$filename,$href,$id,$button_text,$button_and_icon) = @_;

    my $nofollow =
        (($filename =~ /\.(dba|vcs)$/) || (defined $q->param("month") && $q->param("month") =~ /^\d+$/))
        ? qq{ rel="nofollow"} : "";

    my $html5download = ($href =~ m,^(webcal://|http://calendar\.live\.com),) ? "" : qq{ download="$filename"};

    my $class = $button_and_icon ? "btn btn-default download" : "download";
    my $icon = $button_and_icon ? qq{<span class="glyphicon glyphicon-download-alt"></span> } : "";

    return qq{<a class="$class" id="$id" title="$filename" href="$href"${nofollow}${html5download}>${icon}Download $button_text</a>};
}

sub download_html_bootstrap {
    my($q,$filename,$events,$title,$yahrzeit_mode) = @_;

    my($greg_year1,$greg_year2) = (0,0);
    my($numEntries) = scalar(@{$events});
    if ($numEntries > 0) {
        $greg_year1 = $events->[0]->[$Hebcal::EVT_IDX_YEAR];
        $greg_year2 = $events->[$numEntries - 1]->[$Hebcal::EVT_IDX_YEAR];
    }

    my $ical1 = Hebcal::download_href($q, $filename, "ics");
    $ical1 =~ /\?(.+)$/;
    my $args = $1;
    my $ical_href = Hebcal::get_vcalendar_cache_fn($args) . "?" . $args;
    my $subical_href = $ical_href;
    $subical_href =~ s/\?dl=1/\?subscribe=1/g;
    my $vhost = "download.hebcal.com";
    $ical_href = join("", "http://", $vhost, $ical_href);
    my $webcal_href;
    if ($yahrzeit_mode) {
        $webcal_href = $ical1;
        $ical_href = $ical1;
    } else {
        $webcal_href = join("", "webcal://", $vhost, $subical_href);
    }
    my $title_esc = $title ? URI::Escape::uri_escape_utf8("Hebcal $title")
        : URI::Escape::uri_escape_utf8("Hebcal $filename");
    my $ics_title = $title ? "Jewish Calendar $title.ics" : "$filename.ics";

    my $ol_ics_title = "Outlook 2007, 2010, 2013 (Windows)";
    my $ol_csv_title = "Outlook 97, 98, 2000, 2002, 2003 (Windows)";
    my $ical_title = "Mac OS X Calendar (Desktop)";
    my $ol_mac_title = "Outlook 2011 (Mac OS X)";
    my $ios_title = "Apple iPhone &amp; iPad";
    my $gcal_title = "Google Calendar";
    my $wlive_title = "Outlook.com Calendar";
    my $ycal_title = "Yahoo! Calendar";
    my $palm_title = "Palm Desktop (Windows-only)";

    my $ol_ics_btn = download_button_html($q, $ics_title, $webcal_href, "dl-ol-ics",
                                          "Outlook Internet Calendar Subscription", 1);
    my $ol_ics = <<EOHTML;
<p>$ol_ics_btn</p>
<p>Step-by-step: <a title="Outlook Internet Calendar Subscription - import Hebcal Jewish calendar to Outlook 2007, Outlook 2010"
href="http://www.hebcal.com/home/8/outlook-internet-calendar-subscription-jewish-calendar">Import
ICS (Internet Calendar Subscription) file into Outlook</a></p>
EOHTML
;
    if (!$yahrzeit_mode) {
        my $ol_ics_alt_btn = download_button_html($q, $ics_title, $ical_href, "dl-ol-ics-alt", $ics_title, 0);
        $ol_ics .= <<EOHTML
<p>Alternate option: $ol_ics_alt_btn
and then import manually into Microsoft Outlook.</p>
EOHTML
;
    }

    my $href_ol_usa = Hebcal::download_href($q, "${filename}_usa", "csv");
    my $ol_csv_btn_usa = download_button_html($q, "${filename}_usa.csv", $href_ol_usa, "dl-ol-csv-usa",
                                              "Outlook CSV - USA date format (month/day/year)", 1);
    my $href_ol_eur = Hebcal::download_href($q, "${filename}_eur", "csv") . ";euro=1";
    my $ol_csv_btn_eur = download_button_html($q, "${filename}_eur.csv", $href_ol_eur, "dl-ol-csv-eur",
                                              "Outlook CSV - European date format (day/month/year)", 1);
    my $ol_csv = <<EOHTML;
Select one of:
<ul class="list-unstyled">
<li>$ol_csv_btn_usa</li>
<li>$ol_csv_btn_eur</li>
</ul>
Step-by-step: <a title="Outlook CSV - import Hebcal Jewish calendar to Outlook 97, 98, 2000, 2002, 2003"
href="http://www.hebcal.com/home/12/outlook-csv-jewish-calendar">Import CSV file into Outlook</a>
EOHTML
;
    my $ical_btn = download_button_html($q, $ics_title, $webcal_href, "dl-ical-sub", "to Mac Calendar", 1);
    my $ical = <<EOHTML;
<p>$ical_btn</p>
<p>Step-by-step: <a title="Apple iCal - import Hebcal Jewish calendar"
href="http://www.hebcal.com/home/79/apple-ical-import-hebcal-jewish-calendar">Import ICS file into Apple Mac OS X Desktop Calendar</a></p>
EOHTML
;
    if (!$yahrzeit_mode) {
        my $ical_alt_btn = download_button_html($q, $ics_title, $ical_href, "dl-ical-alt", $ics_title, 0);
        $ical .= <<EOHTML;
<p>Alternate option: $ical_alt_btn
and then import manually into Apple iCal.</p>
EOHTML
;
    }

    my $ol_mac_btn = download_button_html($q, $ics_title, $ical_href, "dl-ol-mac", "to Outlook for Mac", 1);
    my $ol_mac = <<EOHTML;
<p>$ol_mac_btn</p>
<p>Step-by-step: <a title="Outlook 2011 Mac OS X - import Hebcal Jewish calendar"
href="http://www.hebcal.com/home/186/outlook-2011-mac-import">Import .ics file into
Outlook 2011 for Mac OS X</a></p>
EOHTML
;
    my $ios_btn = download_button_html($q, $ics_title, $webcal_href, "dl-ios-sub", "to iPhone/iPad", 1);
    my $ios = <<EOHTML;
<p>$ios_btn</p>
<p>Step-by-step: <a title="iPhone and iPad - import Hebcal Jewish calendar"
href="http://www.hebcal.com/home/77/iphone-ipad-jewish-calendar">Import into iPhone &amp; iPad</a></p>
EOHTML
;

    #############################################################
    # Google Calendar

    my $gcal_subical_href = $subical_href;
    $gcal_subical_href =~ s/;/&/g;
    my $full_http_href = "http://" . $vhost . $gcal_subical_href;
    my $gcal_href = URI::Escape::uri_escape_utf8($full_http_href);
    my $gcal;
    if ($yahrzeit_mode) {
        my $gcal_btn = download_button_html($q, $ics_title, $ical_href, "dl-gcal-alt", "$ics_title for Google Calendar", 1);
        $gcal = <<EOHTML;
<p>$gcal_btn</p>
<p>Step-by-step: <a href="http://www.hebcal.com/home/59/google-calendar-alternative-instructions">Import into Google Calendar</a></p>
EOHTML
;
    } else {
        my $gcal_btn = download_button_html($q, $ics_title, $ical_href, "dl-gcal-alt", $ics_title, 0);
        $gcal = <<EOHTML;
<p><a title="Add $ics_title to Google Calendar"
class="download" id="dl-gcal-sub" rel="nofollow"
href="http://www.google.com/calendar/render?cid=${gcal_href}"><img
src="/i/gc_button6.gif" width="114" height="36" style="border:none" alt="Add to Google Calendar"></a></p>
<p>Alternate option:
$gcal_btn
and then <a
title="Google Calendar alternative instructions - import Hebcal Jewish calendar"
href="http://www.hebcal.com/home/59/google-calendar-alternative-instructions">follow
our Google Calendar import instructions</a>.</p>
EOHTML
;
    }

    #############################################################
    # Windows Live Calendar

    my $wlive_btn = download_button_html($q, $ics_title,
                                         "http://calendar.live.com/calendar/calendar.aspx?rru=addsubscription&amp;url=${gcal_href}&amp;name=${title_esc}",
                                         "dl-wlive", "to Outlook.com Calendar", 1);
    my $wlive = <<EOHTML;
<p>$wlive_btn</p>
<p>Step-by-step: <a
href="http://windows.microsoft.com/en-us/windows/outlook/calendar-import-vs-subscribe">Import
or subscribe to a calendar in Outlook.com</a></p>
EOHTML
;

    ############################################################
    # Yahoo! Calendar

    my $ampersand_subical_href = $subical_href;
    $ampersand_subical_href =~ s/;/&amp;/g;
    my $ampersand_http_href = "http://" . $vhost . $ampersand_subical_href;
    my $ycal = <<EOHTML;
<form id="GrabLinkForm" action="#">
<ol>
<li>Copy the entire iCal URL here:
<label for="iCalUrl"><small><input type="text" size="80" id="iCalUrl" name="iCalUrl"
onfocus="this.select();" onKeyPress="return false;"
value="${ampersand_http_href}"></small></label>
<li>Go to your <a href="http://calendar.yahoo.com/">Yahoo! Calendar</a>,
and click the "<b>+</b>" button next to "Calendars" on the left side of the page
<li>Click <b>Subscribe to Calendar</b>
<li>Paste the web address into the "Email or iCal address" window
<li>Click <b>Next</b> at the top of the page
<li>Type a name for the calendar in the window after "Display as."
<li>Choose a color for the calendar in the "Color:" pull-down menu
<li>Click <b>Save</b> at the top of the page
</ol>
</form>
EOHTML
;

    #############################################################
    # Palm

    # only offer DBA export when we know timegm() will work
    my $palm_dba = "";
    my $dst;
    if ($q->param("geo") && $q->param("geo") ne "off"
        && $q->param("c") && $q->param("c") ne "off") {
        if (defined $q->param("dst") && $q->param("dst") ne "") {
            $dst = $q->param("dst");
        }
        elsif ($q->param("geo") eq "city" && $q->param("city")
               && defined $Hebcal::city_dst{$q->param("city")}) {
            $dst = $Hebcal::city_dst{$q->param("city")};
        }
    }

    if ($greg_year1 > 1969 && $greg_year2 < 2038 &&
        (!defined($dst) || $dst eq "usa" || $dst eq "none")) {
        my $dba_href = Hebcal::download_href($q, $filename, 'dba');
        my $palm_dba_btn = download_button_html($q, "$filename.dba", $dba_href, "dl-dba", "$filename.dba", 1);
        $palm_dba = <<EOHTML;
<h5>Palm Desktop 4.1.4 - Date Book Archive</h5>
<p>$palm_dba_btn</p>
<p>Step-by-step: <a title="Palm Desktop - import Hebcal Jewish calendar"
href="http://www.hebcal.com/home/87/palm-desktop-import-hebcal-jewish-calendar">Import DBA file into Palm Desktop 4.1.4</a></p>
EOHTML
;
    }

    my $href_vcs = Hebcal::download_href($q, $filename, "vcs");
    my $palm_vcs_btn = download_button_html($q, "$filename.vcs", $href_vcs, "dl-vcs", "$filename.vcs", 1);
    my $palm = <<EOHTML;
<h5>Palm Desktop 6.2 by ACCESS - vCal (.vcs format)</h5>
<p>$palm_vcs_btn</p>
<p>Step-by-step: <a title="Palm Desktop 6.2 - import Hebcal Jewish calendar"
href="http://www.hebcal.com/home/188/palm-desktop-62">Import VCS file into Palm Desktop 6.2 for Windows</a></p>
$palm_dba
EOHTML
;

    my $pdf_title = "Print PDF (formatted for 8.5\"x11\" paper)";
    my $href_pdf = Hebcal::download_href($q, $filename, "pdf");
    my $pdf_btn = download_button_html($q, "$filename.pdf", $href_pdf, "dl-pdf", "PDF Calendar", 1);
    $pdf_btn =~ s/icon-download-alt/icon-print/;
    my $pdf = "<p>$pdf_btn</p>\n";

    my @nav_tabs = (
        ["iPhone", $ios_title, "ios", $ios],
        ["Outlook", $ol_ics_title, "ol-ics", $ol_ics],
        ["Google", $gcal_title, "gcal", $gcal],
        ["Mac OS X", $ical_title, "ical", $ical],
        ["Outlook.com", $wlive_title, "wlive", $wlive],
        ["Outlook Mac", $ol_mac_title, "ol-mac", $ol_mac],
        ["Yahoo!", $ycal_title, "ycal", $ycal],
        ["CSV", $ol_csv_title, "ol-csv", $ol_csv],
        ["Palm", $palm_title, "palm", $palm],
    );

    unless ($yahrzeit_mode) {
        push(@nav_tabs, ["PDF", $pdf_title, "pdf", $pdf]);
    }

    my $s = qq{<ul class="nav nav-pills" id="download-tabs">\n};
    foreach my $tab (@nav_tabs) {
        my($short_title,$long_title,$slug,$content) = @{$tab};
        my $class = $slug eq "ios" ? qq{ class="active"} : "";
        $s .= qq{<li$class><a href="#${slug}-body" data-toggle="tab">$short_title</a></li>\n};
    }
    $s .= qq{</ul><!-- #download-tabs -->\n<hr style="margin:0 0 12px 0">\n<div class="tab-content">\n};
    foreach my $tab (@nav_tabs) {
        $s .= tab_body($tab);
    }
    $s .= qq{</div><!-- .tab-content -->\n};

    return $s;
}

sub download_html_modal {
    my($q,$filename,$events,$title,$yahrzeit_mode,$bootstrap3) = @_;

    my $outer_class = $bootstrap3 ? "modal fade" : "modal hide fade";

    my $html = download_html_bootstrap($q,$filename,$events,$title,$yahrzeit_mode);
    my $s = <<EOHTML;
<div class="$outer_class" id="hcdl-modal" tabindex="-1" role="dialog" aria-labelledby="hcdl-modalLabel" aria-hidden="true">
 <div class="modal-dialog">
  <div class="modal-content">
 <div class="modal-header">
  <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
  <h3 class="modal-title" id="hcdl-modalLabel">Download</h3>
 </div>
 <div class="modal-body">
<p>Export <strong>$title Calendar</strong> to your calendar app.</p>
$html
 </div><!-- .modal-body -->
 <div class="modal-footer">
   <button class="btn btn-primary" data-dismiss="modal" aria-hidden="true">Close</button>
 </div>
  </div><!-- .modal-content -->
 </div><!-- .modal-dialog -->
</div><!-- .modal -->
EOHTML
;
    return $s;
}

sub download_html_modal_button {
    my($className) = @_;
    $className ||= "";
    return qq{<a href="#hcdl-modal" role="button" class="btn btn-default$className" data-toggle="modal" data-target="#hcdl-modal">Download ...</a>};
}

my $HTML_MENU_ITEMS_V2 =
    [
     [ "/holidays/",    "Holidays",     "Jewish Holidays" ],
     [ "/converter/",   "Date Converter", "Hebrew Date Converter" ],
     [ "/shabbat/",     "Shabbat",      "Shabbat Times" ],
     [ "/sedrot/",      "Torah",        "Torah Readings" ],
     [ "http://www.hebcal.com/home/about",      "About",        "About" ],
     [ "http://www.hebcal.com/home/help",       "Help",         "Help" ],
    ];

sub html_menu_item_bootstrap {
    my($path,$title,$tooltip,$selected) = @_;
    my $class = undef;
    if ($path eq $selected) {
        $class = "active";
    }
    my $str = qq{<li};
    if ($class) {
        $str .= qq{ class="$class"};
    }
    $str .= qq{><a href="$path" title="$tooltip">$title</a>};
    return $str;
}

sub html_menu_bootstrap {
    my($selected,$menu_items) = @_;
    my $str = qq{<ul class="nav navbar-nav">};
    foreach my $item (@{$menu_items}) {
        my $path = $item->[0];
        my $title = $item->[1];
        my $tooltip = $item->[2];
        if (defined $item->[3]) {
            $str .= "<li class=\"dropdown\">";
            $str .= "<a href=\"#\" class=\"dropdown-toggle\" data-toggle=\"dropdown\">$title <b class=\"caret\"></b></a>";
            $str .= "<ul class=\"dropdown-menu\">";
            for (my $i = 3; defined $item->[$i]; $i++) {
                $str .= html_menu_item_bootstrap($item->[$i]->[0], $item->[$i]->[1], $item->[$i]->[2], $selected);
                $str .= qq{</li>};
            }
            $str .= qq{</ul>};
        } else {
            $str .= html_menu_item_bootstrap($path, $title, $tooltip, $selected);
        }
        $str .= qq{</li>};
    }
    $str .= qq{</ul>};
    return $str;
}


sub header_bootstrap3 {
    my($title,$base_href,$body_class,$xtra_head,$suppress_site_title,$hebrew_stylesheet) = @_;
    $xtra_head = "" unless $xtra_head;
    my $menu = html_menu_bootstrap($base_href,$HTML_MENU_ITEMS_V2);
    my $title2 = $suppress_site_title ? $title : "$title | Hebcal Jewish Calendar";
    my $alefhebrew = q"@font-face{font-family:'Alef Hebrew';font-style:normal;font-weight:400;src:url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Regular.eot);src:url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Regular.eot?#iefix) format('embedded-opentype'),url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Regular.woff2) format('woff2'),url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Regular.woff) format('woff'),url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Regular.ttf) format('truetype')}@font-face{font-family:'Alef Hebrew';font-style:normal;font-weight:700;src:url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Bold.eot);src:url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Bold.eot?#iefix) format('embedded-opentype'),url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Bold.woff2) format('woff2'),url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Bold.woff) format('woff'),url(//fonts.gstatic.com/ea/alefhebrew/v4/Alef-Bold.ttf) format('truetype')}";
    my $xtra_stylesheet = $hebrew_stylesheet
        ? "<!-- http://fonts.googleapis.com/earlyaccess/alefhebrew.css -->\n<style type=\"text/css\">\n$alefhebrew\n</style>\n"
        : "";

    my $logo = '<a href="/" class="navbar-brand" id="logo" title="Hebcal Jewish Calendar"><img src="/i/hebcal-logo-1.2.svg" width="77" height="21" alt="Hebcal"></a>';
    my $str = <<EOHTML;
<!DOCTYPE html>
<html><head>
<meta charset="UTF-8">
<title>$title2</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
<link rel="stylesheet" href="//maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap-theme.min.css">
$xtra_stylesheet<script>
  (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
  (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
  m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
  })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  ga('create', 'UA-967247-1', 'auto');
  ga('set', 'anonymizeIp', true);
  ga('send', 'pageview');
</script>
<style type="text/css">
.label{text-transform:none}
:lang(he) {
  font-family:'Alef Hebrew','SBL Hebrew',David,serif;
  font-size:125%;
  direction:rtl;
}
.hebcal-footer {
  padding-top: 40px;
  padding-bottom: 40px;
  margin-top: 40px;
  color: #777;
  text-align: center;
  border-top: 1px solid #e5e5e5;
}
.hebcal-footer p {
  margin-bottom: 2px;
}
.bullet-list-inline {
  padding-left: 0;
  margin-left: -3px;
  list-style: none;
}
.bullet-list-inline > li {
  display: inline-block;
  padding-right: 3px;
  padding-left: 3px;
}
.bullet-list-inline li:after{content:"\\00a0\\00a0\\00b7"}
.bullet-list-inline li:last-child:after{content:""}
\@media print{
 a[href]:after{content:""}
 .sidebar-nav{display:none}
}
\@media (min-width: 768px) {
  input#s {
    width: 132px;
  }
}
</style>
$xtra_head</head>
<body>
<!-- Static navbar -->
<div class="navbar navbar-default navbar-static-top" role="navigation">
  <div class="container-fluid">
    <div class="navbar-header">
      <button type="button" class="navbar-toggle collapsed" data-toggle="collapse" data-target=".navbar-collapse">
        <span class="sr-only">Toggle navigation</span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
        <span class="icon-bar"></span>
      </button>
      $logo
    </div>
    <div class="navbar-collapse collapse">
    $menu
    <form class="navbar-form navbar-right" role="search" method="get" id="searchform" action="http://www.hebcal.com/home/">
     <input name="s" id="s" type="text" class="form-control" placeholder="Search">
    </form>
    </div><!--/.navbar-collapse -->
  </div>
</div>

<div class="container">
<div id="content">
EOHTML
;
    return $str;
}

my $URCHIN = qq{<script type="text/javascript">
(function(){if(document.getElementsByTagName){var b=document.getElementsByTagName("a");if(b&&b.length){for(var a=0;a<b.length;a++){if(b[a]&&b[a].className=="amzn"){if(b[a].id){b[a].onclick=function(){ga("send","event","outbound-amzn",this.id)}}}
if(b[a]&&b[a].className=="outbound"){b[a].onclick=function(){var c=this.href;if(c&&c.indexOf("http://")===0){var d=c.indexOf("/",7);if(d>7){ga("send","event","outbound-article",c.substring(7,d))}}}}
if(b[a]&&b[a].className.indexOf("download")!=-1){if(b[a].id){b[a].onclick=function(){ga("send","event","download",this.id)}}}}}}})();
</script>
};

sub footer_bootstrap3 {
    my($q,$rcsrev,$noclosebody,$xtra_html) = @_;

    my($mtime) = (defined $ENV{'SCRIPT_FILENAME'}) ?
        (stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my $hhmts = strftime("%d %B %Y", localtime($mtime));
    my $dc_date = strftime("%Y-%m-%dT%H:%M:%S", gmtime($mtime)) . "Z";
    my $last_updated_text = qq{<li><time datetime="$dc_date">$hhmts</time></li>};

    my $str = <<EOHTML;
</div><!-- #content -->

<footer role="contentinfo" class="hebcal-footer">
<div class="row">
<div class="col-sm-12">
<p><small>Except where otherwise noted, content on this site is licensed under a <a
rel="license" href="http://creativecommons.org/licenses/by/3.0/deed.en_US">Creative Commons Attribution 3.0 License</a>.</small></p>
<p><small>Some location data comes from <a href="http://www.geonames.org/">GeoNames</a>,
also under a cc-by licence.</small></p>
<ul class="bullet-list-inline">
$last_updated_text
<li><a href="http://www.hebcal.com/home/about">About</a></li>
<li><a href="http://www.hebcal.com/home/about/privacy-policy">Privacy</a></li>
<li><a href="http://www.hebcal.com/home/help">Help</a></li>
<li><a href="http://www.hebcal.com/home/about/contact">Contact</a></li>
<li><a href="http://www.hebcal.com/home/about/donate">Donate</a></li>
<li><a href="http://www.hebcal.com/home/developer-apis">Developer APIs</a></li>
</ul>
</div><!-- .col-sm-12 -->
</div><!-- .row -->
</footer>
</div> <!-- .container -->

<script src="//ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
<script src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.2/js/bootstrap.min.js"></script>
EOHTML
;

    $str .= $URCHIN;
    $str .= $xtra_html if $xtra_html;

    if ($noclosebody) {
        return $str;
    } else {
        return $str . "</body></html>\n";
    }
}

sub html_entify($)
{
    local($_) = @_;

    s/&/&amp;/g;
    s/</&lt;/g;
    s/>/&gt;/g;
    s/"/&quot;/g; #"#
    s/\s+/ /g;

    $_;
}

sub radio_group {
    my($q,@p) = @_;
    my $s = $q->radio_group(@p);
    $s =~ s/<input([^>]+)>([^<]+)/<div class="radio"><label><input$1>$2<\/label><\/div>/g;
    $s;
}


# avoid warnings
if ($^W && 0)
{
    my $unused;
    $unused = $HebcalHtml::usno_warning;
    $unused = $HebcalHtml::gregorian_warning;
    $unused = $HebcalHtml::indiana_warning;
}

1;
