#!/usr/local/bin/perl5 -w

require 'cgi-lib.pl';
require 'ctime.pl';
require 'timelocal.pl';

$dbmfile = 'zips.db';
$dbmfile =~ s/\.db$//;

&CgiDie("Script Error: No Database", "\nThe database is unreadable.\n" .
	"Please <a href=\"mailto:michael\@radwin.org" .
	"\">e-mail Michael</a> to tell him that hebcal is broken.")
    unless -r "${dbmfile}.db";

$now = $ARGV[0] ? $ARGV[0] : time;
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;
$friday = $now + ((4 - $wday) * 60 * 60 * 24);
$saturday = $now + ((6 - $wday) * 60 * 60 * 24);

$sat_year = (localtime($saturday))[5] + 1900;

$cmd  = '/home/users/mradwin/bin/hebcal';

$rcsrev = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

$hhmts = "<!-- hhmts start -->
Last modified: Thu Sep 30 14:32:18 PDT 1999
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated: /g;
$hhmts = 'This page generated: ' . &ctime(time) . '<br>' . $hhmts;

$html_footer = "<hr noshade size=\"1\">
<small>$hhmts ($rcsrev)
<p>Copyright &copy; $year Michael John Radwin. All rights
reserved.</small>
</body></html>
";

if (defined $ENV{'HTTP_COOKIE'} &&
    $ENV{'HTTP_COOKIE'} =~ /[\s;,]*C=([^\s,;]+)/)
{
    &process_cookie($1);
}

@opts = ('c','x','o','s','i','h','a','d','usa','israel','none','set');
%valid_cities =
    (
     'Atlanta', 1,
     'Austin', 1,
     'Berlin', 1,
     'Baltimore', 1,
     'Bogota', 1,
     'Boston', 1,
     'Buenos Aires', 1,
     'Buffalo', 1,
     'Chicago', 1,
     'Cincinnati', 1,
     'Cleveland', 1,
     'Dallas', 1,
     'Denver', 1,
     'Detroit', 1,
     'Gibraltar', 1,
     'Hawaii', 1,
     'Houston', 1,
     'Jerusalem', 1,
     'Johannesburg', 1,
     'London', 1,
     'Los Angeles', 1,
     'Miami', 1,
     'Mexico City', 1,
     'New York', 1,
     'Omaha', 1,
     'Philadelphia', 1,
     'Phoenix', 1,
     'Pittsburgh', 1,
     'Saint Louis', 1,
     'San Francisco', 1,
     'Seattle', 1,
     'Toronto', 1,
     'Vancouver', 1,
     'Washington DC', 1,
     );

if (defined $in{'city'} && $in{'city'} !~ /^\s*$/)
{
    &CgiDie("Invalid City: $in{'city'}", "\nBogus!")
	unless defined($valid_cities{$in{'city'}});

    $cmd .= " -C '$in{'city'}'";
    $city_descr = $in{'city'};

    delete $in{'tz'};
    delete $in{'dst'};
}
elsif (defined $in{'zip'})
{
    $in{'dst'} = 'usa' unless defined $in{'dst'};

    &CgiDie("No timezone for zip code: $in{'zip'}", "\nBogus!")
	unless $in{'tz'} !~ /^\s*$/;

    &CgiDie("Bad zip code: $in{'zip'}", "\nBogus!")
	if $in{'zip'} =~ /^\s*$/;

    &CgiDie("Bad zip code: $in{'zip'}", "\nBogus!")
	unless $in{'zip'} =~ /^\d\d\d\d\d$/;

    dbmopen(%DB,$dbmfile, 0400) ||
	&CgiDie("Script Error: Database Unavailable",
		"\nThe database is unavailable right now.\n" .
		"Please <a href=\"${cgipath}?" .
		$ENV{'QUERY_STRING'} . "\">try again</a>.");

    $val = $DB{$in{'zip'}};
    dbmclose(%DB);

    &CgiDie("Zip code not in DB: $in{'zip'}", "\nBogus!")
	unless defined $val;

    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));

    @city = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = "\L$_\E";
	$_ = "\u$_";
	$city .= $_;
    }
    undef(@city);

    $city_descr = "$city, $state &nbsp;$in{'zip'}";
    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}
else
{
    $in{'city'} = 'New York';
    $cmd .= " -C '$in{'city'}'";
    $city_descr = $in{'city'};
}

if (defined $in{'tz'} && $in{'tz'} ne '')
{
    $cmd .= " -z $in{'tz'}";
}

if (defined $in{'dst'} && $in{'dst'} ne '')
{
    $cmd .= " -Z $in{'dst'}";
}

$cmd .= ' -s -h -c -m 72 ' . $sat_year;

@DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
local($time) = defined $ENV{'SCRIPT_FILENAME'} ?
(stat($ENV{'SCRIPT_FILENAME'}))[9] : time;

#  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
#      localtime($saturday);
#  $date = sprintf("%04d-%02d-%02d", $year + 1900, $mon + 1, $mday);

print STDOUT "Content-Type: text/html\015\012\015\012";

    print STDOUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\"
\t\"http://www.w3.org/TR/REC-html40/loose.dtd\">
<html><head>
<title>1-Click Shabbat for $city_descr</title>
<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"michael\@radwin.org\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
</head>
<body>
<table border=\"0\" width=\"100%\" cellpadding=\"0\" class=\"navbar\">
<tr valign=\"top\"><td><small>
<a href=\"/\">radwin.org</a> <tt>-&gt;</tt>
1-Click Shabbat</small></td>
<td align=\"right\"><small><a href=\"/search/\">Search</a></small>
</td></tr></table>
<h1>1-Click Shabbat for $city_descr</h1>
";

print STDOUT "<!-- $cmd -->\n<pre>\n";

open(HEBCAL,"$cmd |") || die;
while(<HEBCAL>)
{
    chop;
    ($date,$descr) = split(/ /, $_, 2);

    ($subj,$date,$start_time,$end_date,$end_time,$all_day,
     $hr,$min,$month,$day,$year) = &parse_date_descr($date,$descr);

    $mon = $month - 1;
    $mday = $day;
    $year -= 1900;
    $time = &timelocal(0,0,0,$mday,$mon,$year,'','','');
    next if $time < $friday || $time > $saturday;

    $year += 1900;
    $dow = ($year > 1969 && $year < 2038) ? 
	$DoW[&get_dow($year - 1900, $month - 1, $day)] . ' ' :
	    '';
    printf STDOUT "%s%04d-%02d-%02d  %s\n",
    $dow, $year, $month, $day, $descr;
}
close(HEBCAL);

print STDOUT "</pre>", $html_footer;

close(STDOUT);
exit(0);

sub get_dow
{
    local($year,$mon,$mday) = @_;
    local($sec,$min,$hour,$wday,$yday,$isdst);
    local($time);

    $wday = $yday = $isdst = '';
    $sec = $min = $hour = 0;
    $time = &timelocal($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);

    (localtime($time))[6];
}

sub parse_date_descr
{
    local($date,$descr) = @_;

    ($month,$day,$year) = split(/\//, $date);
    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hr,$min) = ($1,$2,$3);
	$start_time = sprintf("\"%d:%02d PM\"", $hr, $min);
#	$min += 15;
#	if ($min >= 60)
#	{
#	    $hr++;
#	    $min -= 60;
#	}
#	$end_time = sprintf("\"%d:%02d PM\"", $hr, $min);
#	$end_date = $date;
	$end_time = $end_date = '';
	$all_day = '"false"';
    }
    else
    {
	$hr = $min = -1;
	$start_time = $end_time = $end_date = '';
	$all_day = '"true"';
	$subj = $descr;
    }
    
    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    ($subj,$date,$start_time,$end_date,$end_time,$all_day,
     $hr,$min,$month,$day,$year);
}

#  sub http_date
#  {
#      local($time) = @_;
#      local(@MoY);
#      local($sec,$min,$hour,$mday,$mon,$year,$wday) =
#  	gmtime($time);

#      @MoY = ('Jan','Feb','Mar','Apr','May','Jun',
#  	    'Jul','Aug','Sep','Oct','Nov','Dec');
#      $year += 1900;

#      sprintf("%s, %02d %s %4d %02d:%02d:%02d GMT",
#  	    $DoW[$wday],$mday,$MoY[$mon],$year,$hour,$min,$sec);
#  }



sub process_cookie {
    local($cookieval) = @_;
    local(%cookie);
    local($status);
    local(%ENV);

    $ENV{'QUERY_STRING'} = $cookieval;
    $ENV{'REQUEST_METHOD'} = 'GET';
    $status = &ReadParse(*cookie);

    if (defined $status && $status > 0) {
	if (! defined $in{'c'} || $in{'c'} eq 'on' || $in{'c'} eq '1') {
	    if (defined $cookie{'zip'} && $cookie{'zip'} =~ /^\d\d\d\d\d$/ &&
		(! defined $in{'geo'} || $in{'geo'} eq 'zip')) {
		$in{'zip'} = $cookie{'zip'};
		$in{'geo'} = 'zip';
		$in{'c'} = 'on';
		$in{'dst'} = $cookie{'dst'}
		    if (defined $cookie{'dst'} && ! defined $in{'dst'});
		$in{'tz'} = $cookie{'tz'}
		    if (defined $cookie{'tz'} && ! defined $in{'tz'});
	    } elsif (defined $cookie{'city'} && $cookie{'city'} !~ /^\s*$/ &&
		(! defined $in{'geo'} || $in{'geo'} eq 'city')) {
		$in{'city'} = $cookie{'city'};
		$in{'geo'} = 'city';
		$in{'c'} = 'on';
	    }
	}

	$in{'m'} = $cookie{'m'}
	   if (defined $cookie{'m'} && ! defined $in{'m'});

	foreach (@opts)
	{
	    next if $_ eq 'c';
	    $in{$_} = $cookie{$_}
	        if (! defined $in{$_} && defined $cookie{$_});
	}
    }

    $status;
}

