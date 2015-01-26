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

package HebcalExport;

use strict;
use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";
use Date::Calc ();
use Hebcal ();
use Encode qw(encode_utf8 decode_utf8);
use Digest::MD5 ();
use POSIX qw(strftime);

########################################################################
# export to vCalendar
########################################################################

my %VTIMEZONE =
(
"US/Eastern" =>
"BEGIN:VTIMEZONE
TZID:US/Eastern
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0500
TZOFFSETFROM:-0400
TZNAME:EST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0400
TZOFFSETFROM:-0500
TZNAME:EDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Central" =>
"BEGIN:VTIMEZONE
TZID:US/Central
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0600
TZOFFSETFROM:-0500
TZNAME:CST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0500
TZOFFSETFROM:-0600
TZNAME:CDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Mountain" =>
"BEGIN:VTIMEZONE
TZID:US/Mountain
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0700
TZOFFSETFROM:-0600
TZNAME:MST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0600
TZOFFSETFROM:-0700
TZNAME:MDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Pacific" =>
"BEGIN:VTIMEZONE
TZID:US/Pacific
X-MICROSOFT-CDO-TZID:13
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETFROM:-0700
TZOFFSETTO:-0800
TZNAME:PST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETFROM:-0800
TZOFFSETTO:-0700
TZNAME:PDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Alaska" =>
"BEGIN:VTIMEZONE
TZID:US/Alaska
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-0900
TZOFFSETFROM:+0000
TZNAME:AKST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0800
TZOFFSETFROM:-0900
TZNAME:AKDT
END:DAYLIGHT
END:VTIMEZONE
",
"US/Hawaii" =>
"BEGIN:VTIMEZONE
TZID:US/Hawaii
LAST-MODIFIED:20060309T044821Z
BEGIN:DAYLIGHT
DTSTART:19330430T123000
TZOFFSETTO:-0930
TZOFFSETFROM:+0000
TZNAME:HDT
END:DAYLIGHT
BEGIN:STANDARD
DTSTART:19330521T020000
TZOFFSETTO:-1030
TZOFFSETFROM:-0930
TZNAME:HST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19420209T020000
TZOFFSETTO:-0930
TZOFFSETFROM:-1030
TZNAME:HWT
END:DAYLIGHT
BEGIN:DAYLIGHT
DTSTART:19450814T133000
TZOFFSETTO:-0930
TZOFFSETFROM:-0930
TZNAME:HPT
END:DAYLIGHT
BEGIN:STANDARD
DTSTART:19450930T020000
TZOFFSETTO:-1030
TZOFFSETFROM:-0930
TZNAME:HST
END:STANDARD
BEGIN:STANDARD
DTSTART:19470608T020000
TZOFFSETTO:-1000
TZOFFSETFROM:-1030
TZNAME:HST
END:STANDARD
END:VTIMEZONE
",
"US/Aleutian" =>
"BEGIN:VTIMEZONE
TZID:US/Aleutian
BEGIN:STANDARD
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
TZOFFSETTO:-1000
TZOFFSETFROM:-0900
TZNAME:HAST
END:STANDARD
BEGIN:DAYLIGHT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
TZOFFSETTO:-0900
TZOFFSETFROM:-1000
TZNAME:HADT
END:DAYLIGHT
END:VTIMEZONE
",
"America/Phoenix" =>
"BEGIN:VTIMEZONE
TZID:America/Phoenix
BEGIN:STANDARD
DTSTART:19700101T000000
TZOFFSETTO:-0700
TZOFFSETFROM:-0700
END:STANDARD
END:VTIMEZONE
",
 );

my $cache = undef;
sub cache_begin {
    my($cache_webpath) = @_;

    # update the global variable
    $cache = join("", $ENV{"DOCUMENT_ROOT"}, $cache_webpath, ".", $$);
    my $dir = $cache;
    $dir =~ s,/[^/]+$,,;    # dirname
    unless ( -d $dir ) {
        system( "/bin/mkdir", "-p", $dir );
    }
    if ( open( CACHE, ">$cache" ) ) {
        binmode( CACHE, ":utf8" );
    } else {
        $cache = undef;
    }
    $cache;
}

sub cache_end {
    if ($cache)
    {
        close(CACHE);
        my $fn = $cache;
        my $newfn = $fn;
        $newfn =~ s/\.\d+$//;   # no pid
        rename($fn, $newfn);
        $cache = undef;
    }

    1;
}

sub out_html
{
    my($cfg,@args) = @_;

    if (defined $cfg && $cfg eq 'j')
    {
        print STDOUT "document.write(\"";
        print CACHE "document.write(\"" if $cache;
        foreach (@args)
        {
            s/\"/\\\"/g;
            s/\n/\\n/g;
            print STDOUT;
            print CACHE if $cache;
        }
        print STDOUT "\");\n";
        print CACHE "\");\n" if $cache;
    }
    else
    {
        foreach (@args)
        {
            print STDOUT;
            print CACHE if $cache;
        }
    }

    1;
}

sub export_http_header($$) {
    my($q,$mime) = @_;

    my($time) = defined $ENV{'SCRIPT_FILENAME'} ?
        (stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

    my $path_info = decode_utf8($q->path_info());
    $path_info =~ s,^.*/,,;

    print $q->header(-type => "$mime; filename=\"$path_info\"",
                     -content_disposition =>
                     "attachment; filename=$path_info",
                     -last_modified => Hebcal::http_date($time));
}

sub ical_write_line {
    foreach (@_, "\015\012") {
        print STDOUT;
        print CACHE if $cache;
    }
}

my $OMER_TODO = 0;

sub ical_write_evt {
    my($q, $evt, $is_icalendar, $dtstamp, $cconfig, $tzid, $dbh, $sth) = @_;

    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];

    if ( $OMER_TODO && $subj =~ /^(\d+)\w+ day of the Omer$/ ) {
        my $omer_day = $1;
        my ( $year, $mon, $mday ) = Hebcal::event_ymd($evt);
        my ( $gy, $gm, $gd ) = Date::Calc::Add_Delta_Days( $year, $mon, $mday, -1 );
        my $dtstart = sprintf( "%04d%02d%02dT204500", $gy, $gm, $gd );
        my $uid = sprintf( "hebcal-omer-%04d%02d%02d-%02d", $year, $mon, $mday, $omer_day);
        ical_write_line(qq{BEGIN:VTODO});
        ical_write_line(qq{SUMMARY:}, $subj);
        ical_write_line(qq{STATUS:NEEDS-ACTION});
        ical_write_line(qq{DTSTART:}, $dtstart);
        ical_write_line(qq{DUE:}, $dtstart);
        ical_write_line(qq{DTSTAMP:}, $dtstamp);
        ical_write_line(qq{UID:}, $uid);
        ical_write_line("BEGIN:VALARM");
        ical_write_line("ACTION:DISPLAY");
        ical_write_line("DESCRIPTION:REMINDER");
        ical_write_line("TRIGGER;VALUE=DATE-TIME:", $dtstart);
        ical_write_line("END:VALARM");
        ical_write_line(qq{END:VTODO});
        return 1;
    }

    ical_write_line(qq{BEGIN:VEVENT});
    ical_write_line(qq{DTSTAMP:}, $dtstamp);

    my $category = $is_icalendar ? "Holiday" : "HOLIDAY";
    ical_write_line(qq{CATEGORIES:}, $category);

    my ( $href, $hebrew, $dummy_memo ) = Hebcal::get_holiday_anchor( $subj, 0, $q );

    $subj =~ s/,/\\,/g;

    if ($is_icalendar) {
        $subj = Hebcal::translate_subject( $q, $subj, $hebrew );
    }

    ical_write_line(qq{CLASS:PUBLIC});
    ical_write_line(qq{SUMMARY:}, $subj);

    my $memo = "";
    if (   $evt->[$Hebcal::EVT_IDX_UNTIMED] == 0
        && defined $cconfig
        && defined $cconfig->{"city"} )
    {
        ical_write_line(qq{LOCATION:}, $cconfig->{"city"});
    }
    elsif ( $evt->[$Hebcal::EVT_IDX_MEMO] ) {
        $memo = $evt->[$Hebcal::EVT_IDX_MEMO];
    }
    elsif ( defined $dbh && $subj =~ /^(Parshas|Parashat)\s+/ ) {
        my ( $year, $mon, $mday ) = Hebcal::event_ymd($evt);
        $memo = Hebcal::torah_calendar_memo( $dbh, $sth, $year, $mon, $mday );
    }

    if ($href) {
        if ( $href =~ m,/sedrot/(.+)$, ) {
            $href = "http://hebcal.com/s/$1";
        }
        elsif ( $href =~ m,/holidays/(.+)$, ) {
            $href = "http://hebcal.com/h/$1";
        }
        ical_write_line(qq{URL:}, $href) if $is_icalendar;
        $memo .= "\\n\\n" if $memo;
        $memo .= $href;
    }

    if ($memo) {
        $memo =~ s/,/\\,/g;
        $memo =~ s/;/\\;/g;
        ical_write_line(qq{DESCRIPTION:}, $memo);
    }

    my ( $year, $mon, $mday ) = Hebcal::event_ymd($evt);
    my $date = sprintf( "%04d%02d%02d", $year, $mon, $mday );
    my $end_date = $date;

    if ( $evt->[$Hebcal::EVT_IDX_UNTIMED] == 0 ) {
        my $hour = $evt->[$Hebcal::EVT_IDX_HOUR];
        my $min  = $evt->[$Hebcal::EVT_IDX_MIN];

        $hour += 12 if $hour < 12;
        $date .= sprintf( "T%02d%02d00", $hour, $min );

        $min += $evt->[$Hebcal::EVT_IDX_DUR];
        if ( $min >= 60 ) {
            $hour++;
            $min -= 60;
        }

        $end_date .= sprintf( "T%02d%02d00", $hour, $min );
    }
    else {
        my ( $year, $mon, $mday ) = Hebcal::event_ymd($evt);
        my ( $gy, $gm, $gd ) = Date::Calc::Add_Delta_Days( $year, $mon, $mday, 1 );
        $end_date = sprintf( "%04d%02d%02d", $gy, $gm, $gd );

        # for vCalendar Palm Desktop and Outlook 2000 seem to
        # want midnight to midnight for all-day events.
        # Midnight to 23:59:59 doesn't seem to work as expected.
        if ( !$is_icalendar ) {
            $date     .= "T000000";
            $end_date .= "T000000";
        }
    }

    # for all-day untimed, use DTEND;VALUE=DATE intsead of DURATION:P1D.
    # It's more compatible with everthing except ancient versions of
    # Lotus Notes circa 2004
    my $dtstart = "DTSTART";
    my $dtend = "DTEND";
    if ($is_icalendar) {
        if ( $evt->[$Hebcal::EVT_IDX_UNTIMED] ) {
            $dtstart .= ";VALUE=DATE";
            $dtend .= ";VALUE=DATE";
        }
        elsif ($tzid) {
            $dtstart .= ";TZID=$tzid";
            $dtend .= ";TZID=$tzid";
        }
    }
    ical_write_line($dtstart, ":", $date);
    ical_write_line($dtend, ":", $end_date);

    if ($is_icalendar) {
        if (   $evt->[$Hebcal::EVT_IDX_UNTIMED] == 0
            || $evt->[$Hebcal::EVT_IDX_YOMTOV] == 1 )
        {
            ical_write_line("TRANSP:OPAQUE");    # show as busy
            ical_write_line("X-MICROSOFT-CDO-BUSYSTATUS:OOF");
        }
        else {
            ical_write_line("TRANSP:TRANSPARENT");    # show as free
            ical_write_line("X-MICROSOFT-CDO-BUSYSTATUS:FREE");
        }

        my $date_copy = $date;
        $date_copy =~ s/T\d+$//;

        my $subj_utf8 = encode_utf8( $evt->[$Hebcal::EVT_IDX_SUBJ] );
        my $digest    = Digest::MD5::md5_hex($subj_utf8);
        my $uid       = "hebcal-$date_copy-$digest";

        if ( $evt->[$Hebcal::EVT_IDX_UNTIMED] == 0
            && defined $cconfig )
        {
            my $loc;
            if ( defined $cconfig->{"zip"} ) {
                $loc = $cconfig->{"zip"};
            }
            elsif ( defined $cconfig->{"geonameid"} ) {
                $loc = "g" . $cconfig->{"geonameid"};
            }
            elsif ( defined $cconfig->{"city"} ) {
                $loc = lc( $cconfig->{"city"} );
                $loc =~ s/[^\w]/-/g;
                $loc =~ s/-+/-/g;
                $loc =~ s/-$//g;
            }
            elsif (defined $cconfig->{"long_deg"}
                && defined $cconfig->{"long_min"}
                && defined $cconfig->{"lat_deg"}
                && defined $cconfig->{"lat_min"} )
            {
                $loc = join( "-",
                    "pos",                  $cconfig->{"long_deg"},
                    $cconfig->{"long_min"}, $cconfig->{"lat_deg"},
                    $cconfig->{"lat_min"} );
            }

            if ($loc) {
                $uid .= "-" . $loc;
            }

            if ( defined $cconfig->{"latitude"} ) {
                ical_write_line(qq{GEO:}, $cconfig->{"latitude"},
                    ";", $cconfig->{"longitude"});
            }
        }

        ical_write_line(qq{UID:$uid});

        my $alarm;
        if ( $evt->[$Hebcal::EVT_IDX_SUBJ] =~ /^(\d+)\w+ day of the Omer$/ ) {
            $alarm = "3H";    # 9pm Omer alarm evening before
        }
        elsif ($evt->[$Hebcal::EVT_IDX_SUBJ] =~ /^Yizkor \(.+\)$/
            || $evt->[$Hebcal::EVT_IDX_SUBJ]
            =~ /\'s (Hebrew Anniversary|Hebrew Birthday|Yahrzeit)/ )
        {
            $alarm = "12H";    # noon the day before
        }
        elsif ( $evt->[$Hebcal::EVT_IDX_SUBJ] eq 'Candle lighting' ) {
            $alarm = "10M";    # ten minutes
        }

        if ( defined $alarm ) {
            ical_write_line("BEGIN:VALARM");
            ical_write_line("ACTION:DISPLAY");
            ical_write_line("DESCRIPTION:REMINDER");
            ical_write_line("TRIGGER;RELATED=START:-PT${alarm}");
            ical_write_line("END:VALARM");
        }
    }

    ical_write_line("END:VEVENT");
}

sub vcalendar_write_contents {
    my($q,$events,$title,$cconfig) = @_;

    my $is_icalendar = ( $q->path_info() =~ /\.ics$/ ) ? 1 : 0;

    my $cache_webpath;
    if ($is_icalendar) {
        $cache_webpath = Hebcal::get_vcalendar_cache_fn();
        cache_begin($cache_webpath);
        export_http_header( $q, 'text/calendar; charset=UTF-8' );
    }
    else {
        export_http_header( $q, 'text/x-vCalendar' );
    }

    my $tzid;
    if ( $is_icalendar && defined $cconfig && defined $cconfig->{"tzid"} ) {
        $tzid = $cconfig->{"tzid"};
    }

    my @gmtime_now = gmtime( time() );
    my $dtstamp = strftime( "%Y%m%dT%H%M%SZ", @gmtime_now );

    ical_write_line("BEGIN:VCALENDAR");

    if ($is_icalendar) {
        if ( defined $cconfig && defined $cconfig->{"city"} ) {
            $title = $cconfig->{"city"} . " " . $title;
        }

        $title =~ s/,/\\,/g;

        ical_write_line(qq{VERSION:2.0});
        ical_write_line(qq{PRODID:-//hebcal.com/NONSGML Hebcal Calendar v5.2//EN});
        ical_write_line(qq{CALSCALE:GREGORIAN});
        ical_write_line(qq{METHOD:PUBLISH});
        ical_write_line(qq{X-LOTUS-CHARSET:UTF-8});
        ical_write_line(qq{X-PUBLISHED-TTL:PT7D});
        ical_write_line(qq{X-WR-CALNAME:Hebcal $title});

        if (   defined $cache_webpath
            && defined $ENV{"REQUEST_URI"}
            && $ENV{"REQUEST_URI"} =~ /\?(.+)$/ )
        {
            my $qs = $1;
            $qs =~ s/;/&/g;
            ical_write_line(qq{X-ORIGINAL-URL:http://download.hebcal.com$cache_webpath?$qs});
        }

        # include an iCal description
        if ( defined $q->param("v") ) {
            my $desc;
            if ( $q->param("v") eq "yahrzeit" ) {
                $desc = "Yahrzeits + Anniversaries from www.hebcal.com";
            }
            else {
                $desc = "Jewish Holidays from www.hebcal.com";
            }
            ical_write_line(qq{X-WR-CALDESC:$desc});
        }
    }
    else {
        ical_write_line(qq{VERSION:1.0});
        ical_write_line(qq{METHOD:PUBLISH});
    }

    if ($tzid) {
        ical_write_line(qq{X-WR-TIMEZONE;VALUE=TEXT:$tzid});
        my $vtimezone_ics
            = $ENV{"DOCUMENT_ROOT"} . "/zoneinfo/" . $tzid . ".ics";
        if ( defined $VTIMEZONE{$tzid} ) {
            my $vt = $VTIMEZONE{$tzid};
            $vt =~ s/\n/\015\012/g;
            print STDOUT $vt;
            print CACHE $vt if $cache;
        }
        elsif ( open( VTZ, $vtimezone_ics ) ) {
            my $in_vtz = 0;
            while (<VTZ>) {
                $in_vtz = 1 if /^BEGIN:VTIMEZONE/;
                if ($in_vtz) {
                    print STDOUT $_;
                    print CACHE $_ if $cache;
                }
                $in_vtz = 0 if /^END:VTIMEZONE/;
            }
            close(VTZ);
        }
    }

    unless ($Hebcal::eval_use_DBI) {
        eval("use DBI");
        $Hebcal::eval_use_DBI = 1;
    }

    # don't raise error if we can't open DB
    my $dbh = DBI->connect( "dbi:SQLite:dbname=$Hebcal::LUACH_SQLITE_FILE", "", "" );
    my $sth;
    if ( defined $dbh ) {
        $sth = $dbh->prepare("SELECT num,reading FROM leyning WHERE dt = ?");
        if ( !defined $sth ) {
            $dbh = undef;
        }
    }

    foreach my $evt ( @{$events} ) {
        ical_write_evt( $q, $evt, $is_icalendar, $dtstamp, $cconfig, $tzid,
            $dbh, $sth );
    }

    ical_write_line("END:VCALENDAR");

    if ( defined $dbh ) {
        undef $sth;
        $dbh->disconnect();
    }

    cache_end();
    1;
}

########################################################################
# export to Outlook CSV
########################################################################

sub csv_write_contents($$$)
{
    my($q,$events,$euro) = @_;

    export_http_header($q, 'text/x-csv');
    my $endl = "\015\012";

    print STDOUT
        qq{"Subject","Start Date","Start Time","End Date",},
        qq{"End Time","All day event","Description","Show time as",},
        qq{"Location"$endl};

    foreach my $evt (@{$events}) {
        my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
        my $memo = $evt->[$Hebcal::EVT_IDX_MEMO];

        my $date;
        my($year,$mon,$mday) = Hebcal::event_ymd($evt);
        if ($euro) {
            $date = sprintf("\"%d/%d/%04d\"",
                            $mday, $mon, $year);
        } else {
            $date = sprintf("\"%d/%d/%04d\"",
                            $mon, $mday, $year);
        }

        my($start_time) = '';
        my($end_time) = '';
        my($end_date) = '';
        my($all_day) = '"true"';

        if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0)
        {
            my $hour = $evt->[$Hebcal::EVT_IDX_HOUR];
            my $min = $evt->[$Hebcal::EVT_IDX_MIN];

            $start_time = '"' . Hebcal::format_hebcal_event_time($hour, $min, " PM") . '"';

            $min += $evt->[$Hebcal::EVT_IDX_DUR];

            if ($min >= 60)
            {
                $hour++;
                $min -= 60;
            }

            $end_time = '"' . Hebcal::format_hebcal_event_time($hour, $min, " PM") . '"';
            $end_date = $date;
            $all_day = '"false"';
        }

        $subj =~ s/,//g;
        $memo =~ s/,/;/g;

        $subj =~ s/\"/''/g;
        $memo =~ s/\"/''/g;

        my $loc = 'Jewish Holidays';
        if ($memo =~ /^in (.+)\s*$/)
        {
            $memo = '';
            $loc = $1;
        }

        print STDOUT
            qq{"$subj",$date,$start_time,$end_date,$end_time,},
            qq{$all_day,"$memo",};

        if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0 ||
            $evt->[$Hebcal::EVT_IDX_YOMTOV] == 1)
        {
            print STDOUT qq{"4"};
        }
        else
        {
            print STDOUT qq{"3"};
        }

        print STDOUT qq{,"$loc"$endl};
    }

    1;
}

1;
