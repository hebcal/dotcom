#!/usr/local/bin/perl -w

require 'cgi-lib.pl';

$cgipath = '/cgi-bin/hebcal';
$rcsrev = '$Revision$'; #'

@MoY_abbrev = ('',
	       'jan','feb','mar','apr','may','jun',
	       'jul','aug','sep','oct','nov','dec');
@MoY = 
    ('',
     'January','Februrary','March','April','May','June',
     'July','August','September','October','November','December');

$html_header = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">
<html> <head>
  <title>hebcal web interface</title>
  <meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true comment \"RSACi North America Server\" by \"michael\@radwin.org\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
  <link rev=\"made\" href=\"mailto:michael\@radwin.org\">
</head>

<body>
";

$html_footer = "<hr noshade size=\"1\">

<!-- mjrsig start -->
  <em><a href=\"/michael/contact.html\">Michael J. Radwin</a></em>
  <br><br>
<!-- mjrsig end -->

<small>
<!-- hhmts start -->
Last modified: Fri Apr  9 17:53:37 PDT 1999
<!-- hhmts end -->
($rcsrev)
</small>

</body> </html>
";

# ------------------------------------------------------------------------
# defaults
$default_tz  = '-8';
$default_zip = '95051';

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime(time);
$year += 1900;

$havdalah = 72;
$candle = $usa = 1;
$roshchodesh = $israel = $none = 0;

for ($i = -12; $i < 13; $i++)
{
    $tz{$i} = '';
}
$tz{$default_tz} = ' selected';

for ($i = 0; $i < 13; $i++)
{
    $month{$i} = '';
}
$month{$mon + 1} = ' selected';
# ------------------------------------------------------------------------

$dbmfile = "zips.db";
$dbmfile =~ s/\.db$//;

&CgiDie("Script Error: No Database", "\nThe database is unreadable.\n" .
	"Please <a href=\"mailto:michael\@radwin.org" .
	"\">e-mail Michael</a>.")
    unless -r "${dbmfile}.db";

if (!&ReadParse())
{
    &form($default_zip, '');
}

if (defined $in{'tz'})
{
    for ($i = -12; $i < 13; $i++)
    {
	if ($in{'tz'} eq $i)
	{
	    $tz{$i} = ' selected';
	}
	else
	{
	    $tz{$i} = '';
	}
    }
}

if (defined $in{'month'})
{
    for ($i = 0; $i < 13; $i++)
    {
	if ($in{'month'} eq $i)
	{
	    $month{$i} = ' selected';
	}
	else
	{
	    $month{$i} = '';
	}
    }

    if ($in{'month'} eq '')
    {
	$month{'0'} = ' selected';
    }
}

$candle = ($in{'c'} eq 'on' || $in{'c'} eq '1') ? 1 : 0;
$roshchodesh = ($in{'x'} eq 'on' || $in{'x'} eq '1') ? 1 : 0;
if (defined $in{'dst'})
{
    $usa = ($in{'dst'} eq 'usa') ? 1 : 0;
    $israel = ($in{'dst'} eq 'israel') ? 1 : 0;
    $none = ($in{'dst'} eq 'none') ? 1 : 0;
}
$year = $in{'year'} if (defined $in{'year'} && $in{'year'} =~ /^\d+$/);
$havdalah = $in{'m'} if (defined $in{'m'} && $in{'m'} =~ /^\d+$/);

&form($default_zip, '') if (!defined $in{'zip'});

&form($in{'zip'},
      "<p><em><font color=\"#ff0000\">Please specify a 5-digit Zip Code.</font></em></p>")
    if $in{'zip'} =~ /^\s*$/;

&form($in{'zip'},
      "<p><em><font color=\"#ff0000\">Sorry, <b>$in{'zip'}</b> does not appear to be a 5-digit Zip Code.</font></em></p>")
    unless $in{'zip'} =~ /^\d\d\d\d\d$/;

dbmopen(%DB, "zips", 0400) ||
    &CgiDie("Script Error: Database Unavailable",
	    "\nThe database is unavailable right now.\n" .
	    "Please <a href=\"${cgipath}?" .
	    $ENV{'QUERY_STRING'} .
	    "\">try again</a>.");

$val = $DB{$in{'zip'}};
dbmclose(%DB);

&form($in{'zip'},
      "<p><em><font color=\"#ff0000\">Sorry, can't find <b>$in{'zip'}</b> in the Zip Code database.</font></em></p>")
    unless defined $val;

($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
($city,$state) = split(/\0/, substr($val,6));

$cmd  = "/home/users/mradwin/bin/hebcal" .
    " -L $long_deg,$long_min -l $lat_deg,$lat_min";
$cmd .= ' -x' if $roshchodesh;
$cmd .= ' -c' if $candle;
$cmd .= ' -r' if defined $ENV{'PATH_INFO'};
$cmd .= " -m $in{'m'}" if (defined $in{'m'} && $in{'m'} =~ /^\d+$/);

if (defined $in{'tz'} && $in{'tz'} ne '')
{
    $cmd .= " -z $in{'tz'}";
}

if (defined $in{'dst'} && $in{'dst'} ne '')
{
    $cmd .= " -Z $in{'dst'}";
}
else
{
    $cmd .= ' -Z usa';
}

if (defined $in{'month'} && $in{'month'} ne '')
{
    $cmd .= " $in{'month'}";
}

$cmd .= " $year";

&download() unless defined $ENV{'PATH_INFO'};

open(HEBCAL,"$cmd |") ||
    &CgiDie("Script Error: can't run hebcal",
	    "\nCommand was \"$cmd\".\n" .
	    "Please <a href=\"mailto:michael\@radwin.org" .
	    "\">e-mail Michael</a>.");

print STDOUT "Content-Type: text/x-csv\015\012\015\012";
print STDOUT "\"Subject\",\"Start Date\",\"Start Time\",\"End Date\",\"End Time\",\"All day event\",\"Description\"\n";

while(<HEBCAL>)
{
    chop;
    ($date,$descr) = split(/\t/);
    if ($descr =~ /^(.+)\s*:\s*(\d+):(\d+)\s*$/)
    {
	($subj,$hr,$min) = ($1,$2,$3);
	$start_time = sprintf("\"%d:%02d PM\"", $hr, $min);
	$min += 15;
	if ($min >= 60)
	{
	    $hr++;
	    $min -= 60;
	}
#	$end_time = sprintf("\"%d:%02d PM\"", $hr, $min);
#	$end_date = $date;
	$end_time = $end_date = '';
	$all_day = '"false"';
    }
    else
    {
	$start_time = $end_time = $end_date = '';
	$all_day = '"true"';
	$subj = $descr;
    }
    
    $subj =~ s/\"/''/g;
    $subj =~ s/\s*:\s*$//g;

    print STDOUT "\"$subj\",\"$date\",$start_time,$end_date,$end_time,$all_day,";
    print STDOUT "\"\"\n";
}
close(HEBCAL);
close(STDOUT);

exit(0);


sub form
{
    local($zip,$message) = @_;

    $candle_chk = $candle ? ' checked' : '';
    $roshchodesh_chk = $roshchodesh ? ' checked' : '';

    $usa_chk = $usa ? ' checked' : '';
    $israel_chk = $israel ? ' checked' : '';
    $none_chk = $none ? ' checked' : '';

    print STDOUT "Content-Type: text/html\015\012\015\012";

    print STDOUT "$html_header
<strong><big>
<a href=\"/\">radwin.org</a> :
hebcal web interface
</big></strong>

$message
<p>This is a beta web interface to Danny Sadinoff's <a
href=\"http://www.sadinoff.com/hebcal/\">hebcal</a> program.</p>

<p>Use the form below to generate a list of Jewish Holidays.  Candle
lighting times are calculated from your latitude/longitude (which is
determined by your Zip Code).</p>

<blockquote>
<form method=\"get\" action=\"${cgipath}\">

<label for=\"year\">Year: </label><input type=\"text\" name=\"year\"
id=\"year\" value=\"$year\" size=\"4\" maxlength=\"4\">

&nbsp;&nbsp;&nbsp;

<label for=\"month\">Month: </label>
<select name=\"month\" id=\"month\">
<option value=\"\"$month{'0'}>- entire year -</option>
";
    for ($i = 1; $i < 13; $i++)
    {
	print STDOUT "<option value=\"$i\"$month{$i}>$MoY[$i]</option>\n";
    }
    print STDOUT "
</select><br><br>

<input type=\"checkbox\" name=\"c\" id=\"c\"$candle_chk><label for=\"c\">
Include candle lighting times</label><br>

<blockquote>
<label for=\"zip\">5-digit Zip Code: </label><input type=\"text\" name=\"zip\"
id=\"zip\" value=\"$zip\" size=\"5\" maxlength=\"5\"><br>

<label for=\"tz\">Time Zone: </label>
<select name=\"tz\" id=\"tz\">
<option value=\"-12\"$tz{'-12'}>GMT -12:00  Dateline</option>
<option value=\"-11\"$tz{'-11'}>GMT -11:00  Samoa</option>
<option value=\"-10\"$tz{'-10'}>GMT -10:00  Hawaiian</option>
<option value=\"-9\"$tz{'-9'}>GMT -09:00  Alaskan</option>
<option value=\"-8\"$tz{'-8'}>GMT -08:00  Pacific</option>
<option value=\"-7\"$tz{'-7'}>GMT -07:00  Mountain</option>
<option value=\"-6\"$tz{'-6'}>GMT -06:00  Central</option>
<option value=\"-5\"$tz{'-5'}>GMT -05:00  Eastern</option>
<option value=\"-4\"$tz{'-4'}>GMT -04:00  Atlantic</option>
<option value=\"-3\"$tz{'-3'}>GMT -03:00  Brasilia, Buenos Aires</option>
<option value=\"-2\"$tz{'-2'}>GMT -02:00  Mid-Atlantic</option>
<option value=\"-1\"$tz{'-1'}>GMT -01:00  Azores</option>
<option value=\"0\"$tz{'0'}>Greenwich Mean Time</option>
<option value=\"1\"$tz{'1'}>GMT +01:00  Western Europe</option>
<option value=\"2\"$tz{'2'}>GMT +02:00  Eastern Europe</option>
<option value=\"3\"$tz{'3'}>GMT +03:00  Russia, Saudi Arabia</option>
<option value=\"4\"$tz{'4'}>GMT +04:00  Arabian</option>
<option value=\"5\"$tz{'5'}>GMT +05:00  West Asia</option>
<option value=\"6\"$tz{'6'}>GMT +06:00  Central Asia</option>
<option value=\"7\"$tz{'7'}>GMT +07:00  Bangkok, Hanoi, Jakarta</option>
<option value=\"8\"$tz{'8'}>GMT +08:00  China, Singapore, Taiwan</option>
<option value=\"9\"$tz{'9'}>GMT +09:00  Korea, Japan</option>
<option value=\"10\"$tz{'10'}>GMT +10:00  E. Australia</option>
<option value=\"11\"$tz{'11'}>GMT +11:00  Central Pacific</option>
<option value=\"12\"$tz{'12'}>GMT +12:00  Fiji, New Zealand</option>
</select><br>

Daylight Savings Time:
<input type=\"radio\" name=\"dst\" id=\"dst_usa\" value=\"usa\"$usa_chk>
<label for=\"dst_usa\">USA</label>

<input type=\"radio\" name=\"dst\" id=\"dst_israel\" value=\"israel\"$israel_chk>
<label for=\"dst_israel\">Israel</label>

<input type=\"radio\" name=\"dst\" id=\"dst_none\" value=\"none\"$none_chk>
<label for=\"dst_none\">none</label><br>

<label for=\"m\">Havdalah minutes past sundown: </label><input
type=\"text\" name=\"m\" id=\"m\" value=\"$havdalah\" size=\"3\"
maxlength=\"3\"><br>

</blockquote>

<input type=\"checkbox\" name=\"x\" id=\"x\"$roshchodesh_chk><label for=\"x\">
Suppress Rosh Chodesh</label><br><br>

<input type=\"submit\" value=\"Submit\">
</form>
</blockquote>

<p><small>
Caveat: this is beta software; my apologies if it doesn't work for you.
A form interface for specifying time zones and precise geographic
positions (latitude, longitude) is coming soon.

Geographic Zip Code information provided by <a
href=\"http://www.census.gov/cgi-bin/gazetteer\">The U.S. Census
Bureau's Gazetteer</a>.  If your Zip Code is missing from their
database, I don't have it either.
</small></p>

$html_footer";

    close(STDOUT);
    exit(0);

    1;
}



sub download
{
    local($date) = sprintf("%s %d", $MoY[$in{'month'}], $year);
    local($filename) = 'hebcal_' . $year;

    $filename .= '_' . $MoY_abbrev[$in{'month'}] if $in{'month'} =~ /^\d+$/;
    $filename .= '_' . $in{'zip'} . '.csv';
    
    print STDOUT "Content-Type: text/html\015\012\015\012";

    @city = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = "\L$_\E";
	$_ = "\u$_";
	$city .= $_;
    }

    print STDOUT "$html_header
<strong><big>
<a href=\"/\">radwin.org</a> :
<a href=\"${cgipath}\">hebcal web interface</a> :
$date
</big></strong>

<p>
$city, $state $in{'zip'}<br>
${lat_deg}d${lat_min}' N latitude<br>
${long_deg}d${long_min}' W longitude<br>
<small>
Daylight Savings Time: $in{'dst'}<br>
Time Zone: GMT $in{'tz'}:00
</small>
</p>

<p><a href=\"${cgipath}/${filename}?$ENV{'QUERY_STRING'}\">Click
here to download as an Outlook CSV file</a></p>

";

    print STDOUT "<!-- $cmd -->\n<pre>";
    open(HEBCAL,"$cmd |") ||
	&CgiDie("Script Error: can't run hebcal",
		"\nCommand was \"$cmd\".\n" .
		"Please <a href=\"mailto:michael\@radwin.org" .
		"\">e-mail Michael</a>.");

    while(<HEBCAL>)
    {
	s/</&lt;/g;
	s/>/&lt;/g;
	s/&/&amp;/g;
	print STDOUT $_;
    }
    close(HEBCAL);

    print STDOUT "</pre>\n\n$html_footer";

    close(STDOUT);
    exit(0);

    1;
}

if ($^W && 0)
{
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time);
}

1;
