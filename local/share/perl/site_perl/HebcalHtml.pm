########################################################################
# Copyright (c) 2014 Michael J. Radwin.
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
use CGI qw(-no_xhtml);

$HebcalHtml::gregorian_warning = qq{<div class="alert alert-block">
<button type="button" class="close" data-dismiss="alert">&times;</button>
<strong>Warning!</strong>
Results for year 1752 C.E. and earlier may be inaccurate.
<p>Hebcal does not take into account a correction of ten days that
was introduced by Pope Gregory XIII known as the Gregorian
Reformation.<sup><a
href="http://en.wikipedia.org/wiki/Gregorian_calendar#Adoption_in_Europe">[1]</a></sup></p>
</div><!-- .alert -->
};

$HebcalHtml::indiana_warning = qq{<div class="alert alert-block">
<button type="button" class="close" data-dismiss="alert">&times;</button>
<strong>Warning!</strong>
Indiana has confusing time zone &amp; Daylight Saving Time
rules.</span><br>Please check <a
href="http://en.wikipedia.org/wiki/Time_in_Indiana">What time is it in
Indiana?</a> to make sure the above settings are correct.
</div><!-- .alert -->
};

$HebcalHtml::usno_warning =  qq{<div class="alert alert-block">
<button type="button" class="close" data-dismiss="alert">&times;</button>
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

    my $class = $button_and_icon ? "btn download" : "download";
    my $icon = $button_and_icon ? qq{<i class="icon-download-alt"></i> } : "";

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
<ul class="unstyled">
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
    my($q,$filename,$events,$title,$yahrzeit_mode) = @_;

    my $html = download_html_bootstrap($q,$filename,$events,$title,$yahrzeit_mode);
    my $s = <<EOHTML;
<div class="modal fade" id="hcdl-modal" tabindex="-1" role="dialog" aria-labelledby="hcdl-modalLabel" aria-hidden="true">
 <div class="modal-dialog">
  <div class="modal-content">
 <div class="modal-header">
  <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
  <h3 id="hcdl-modalLabel">Download</h3>
 </div>
 <div class="modal-body">
<p>Export <strong>$title Calendar</strong> to your calendar app.</p>
$html
 </div><!-- .modal-body -->
 <div class="modal-footer">
   <button class="btn btn-primary" data-dismiss="modal" aria-hidden="true">Close</button>
 </div>
</div><!-- #hcdl-modal -->
EOHTML
;
    return $s;
}

sub download_html_modal_button {
    return qq{<a href="#hcdl-modal" role="button" class="btn btn-default btn-small" data-toggle="modal">Download ...</a>};
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
