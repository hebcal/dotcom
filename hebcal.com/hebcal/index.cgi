#!/usr/local/bin/perl -w

require 'cgi-lib.pl';

$dbmfile = "zips.db";
$dbmfile =~ s/\.db$//;

&CgiDie("Script Error: No Database", "\nThe database is unreadable.\n" .
	"Please <a href=\"mailto:michael\@radwin.org" .
	"\">e-mail Michael</a>.")
    unless -r "${dbmfile}.db";

if (!&ReadParse())
{
    $candle =  $roshchodesh = $usa = 1;
    &form('11565');
}

$candle = ($in{'c'} eq 'on' || $in{'c'} eq '1') ? 1 : 0;
$roshchodesh = ($in{'x'} eq 'on' || $in{'x'} eq '1') ? 1 : 0;
$usa = ($in{'dst'} eq 'usa') ? 1 : 0;
$israel = ($in{'dst'} eq 'israel') ? 1 : 0;
$none = ($in{'dst'} eq 'none') ? 1 : 0;

&form('11565') if (!defined $in{'zip'});

&form($in{'zip'},
      "<em>Please specify a 5-digit Zip Code.</em><br><br>")
    if $in{'zip'} =~ /^\s*$/;

&form($in{'zip'},
      "<em>Sorry, <b>$in{'zip'}</b> does not appear to be a 5-digit Zip Code.</em><br><br>")
    unless $in{'zip'} =~ /^\d\d\d\d\d$/;

dbmopen(%DB, "zips", 0400) ||
    &CgiDie("Script Error: Database Unavailable",
	    "\nThe database is unavailable right now.\n" .
	    "Please <a href=\"/cgi-bin/hebcal?" .
	    $ENV{'QUERY_STRING'} .
	    "\">try again</a>.");

$val = $DB{$in{'zip'}};
dbmclose(%DB);

&form($in{'zip'},
      "<em>Sorry, can't find <b>$in{'zip'}</b> in the Zip Code database.</em><br><br>")
    unless defined $val;

($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
($city,$state) = split(/\0/, substr($val,6));

&download() unless defined $ENV{'PATH_INFO'};

$cmd  = "/home/users/mradwin/bin/hebcal" .
    " -L $long_deg,$long_min -l $lat_deg,$lat_min -r";
$cmd .= ' -x' if $roshchodesh;
$cmd .= ' -c' if $candle;
if (defined $in{'dst'} && $in{'dst'} ne '')
{
    $cmd .= " -Z $in{'dst'}";
}
else
{
    $cmd .= ' -Z usa';
}

open(HEBCAL,"$cmd |") ||
    &CgiDie("Script Error: can't run hebcal",
	    "\nCommand was \"$cmd\".\n" .
	    "Please <a href=\"mailto:michael\@radwin.org" .
	    "\">e-mail Michael</a>.");

print STDOUT "Content-Type: text/x-csv\015\012\015\012";
print STDOUT "\"Subject\",\"Start Date\",\"Start Time\",\"End Date\",\"End Time\",\"All day event\",\"Description\"\015\012";

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
    print STDOUT "\"\"\015\012";
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

    print STDOUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">
<html> <head>
  <title>hebcal web interface</title>
  <meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true comment \"RSACi North America Server\" by \"michael\@radwin.org\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
  <link rev=\"made\" href=\"mailto:michael\@radwin.org\">
</head>

<body>
<!-- mjrhead start -->
  <a href=\"/michael/\"><img width=60 height=59 src=\"/michael/face.gif\"
  border=1 align=right alt=\"\"></a><tt><strong><a
  href=\"/cgi-bin/hebcal\"><font size=\"+3\" color=\"#000000\">hebcal web interface</font></a></strong></tt>
  <br><br><small>mjr:&nbsp;<a
  href=\"/michael/\">home</a>&nbsp;||&nbsp;<a
  href=\"/michael/contact.html\">contact</a>&nbsp;||&nbsp;<a
  href=\"/michael/projects/\">projects</a>&nbsp;||&nbsp;<a
  href=\"/mvhs-alumni/\">mvhs&nbsp;alumni</a>&nbsp;||&nbsp;<a
  href=\"/michael/about.html\">about&nbsp;me</a></small>
  <br clear=all>
  <hr noshade size=1>
<!-- mjrhead end -->

<p>
$message
This is a web interface to Danny Sadinoff's <a
href=\"http://www.sadinoff.com/hebcal/\">hebcal</a> program.
<br>
Download an Outlook CSV file with Jewish Holidays:
</p>

<p>
<form method=\"get\" action=\"/cgi-bin/hebcal\">

<label for=\"zip\">5-digit Zip Code: </label><input type=\"text\" name=\"zip\"
id=\"zip\" value=\"$zip\" size=\"5\" maxlength=\"5\"><br>

Daylight Savings Time rule:
<input type=\"radio\" name=\"dst\" id=\"dst_usa\" value=\"usa\"$usa_chk>
<label for=\"dst_usa\">USA</label>

<input type=\"radio\" name=\"dst\" id=\"dst_israel\" value=\"israel\"$israel_chk>
<label for=\"dst_israel\">Israel</label>

<input type=\"radio\" name=\"dst\" id=\"dst_none\" value=\"none\"$none_chk>
<label for=\"dst_none\">none</label>
<br>

<input type=\"checkbox\" name=\"x\" id=\"x\"$roshchodesh_chk><label for=\"x\">
Include Rosh Chodesh</label><br>

<input type=\"checkbox\" name=\"c\" id=\"c\"$candle_chk><label for=\"c\">
Include Candle Lighting Times</label><br>

<input type=\"submit\" value=\"Next &gt;\">
</form>
</p>

<p><small>This is beta software.  My apologies if it doesn't work for
you.  Currently the time zone information is incorrect (all times are
relative to U.S. Eastern).  A form interface for specifying time zones
and precise geographic positions (latitude, longitude) is coming
soon.</small></p>

<p><small>Geographic Zip Code information provided by <a
href=\"http://www.census.gov/cgi-bin/gazetteer\">The U.S. Census
Bureau's Gazetteer</a>.  If your Zip Code is missing from their
database, I don't have it either.</small></p>

<hr noshade size=1>

<!-- mjrsig start -->
  <em><a href=\"/michael/contact.html\">Michael J. Radwin</a></em>
  <br><br>
<!-- mjrsig end -->

<small>
<!-- hhmts start -->
Last modified: Tue Apr  6 16:52:52 PDT 1999
<!-- hhmts end -->
</small>

</body> </html>
";

    close(STDOUT);
    exit(0);

    1;
}



sub download
{
    print STDOUT "Content-Type: text/html\015\012\015\012";

    print STDOUT "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2 Final//EN\">
<html> <head>
  <title>hebcal web interface</title>
  <meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true comment \"RSACi North America Server\" by \"michael\@radwin.org\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>
  <link rev=\"made\" href=\"mailto:michael\@radwin.org\">
</head>

<body>
<!-- mjrhead start -->
  <a href=\"/michael/\"><img width=60 height=59 src=\"/michael/face.gif\"
  border=1 align=right alt=\"\"></a><tt><strong><a
  href=\"/cgi-bin/hebcal\"><font size=\"+3\" color=\"#000000\">hebcal web interface</font></a></strong></tt>
  <br><br><small>mjr:&nbsp;<a
  href=\"/michael/\">home</a>&nbsp;||&nbsp;<a
  href=\"/michael/contact.html\">contact</a>&nbsp;||&nbsp;<a
  href=\"/michael/projects/\">projects</a>&nbsp;||&nbsp;<a
  href=\"/mvhs-alumni/\">mvhs&nbsp;alumni</a>&nbsp;||&nbsp;<a
  href=\"/michael/about.html\">about&nbsp;me</a></small>
  <br clear=all>
  <hr noshade size=1>
<!-- mjrhead end -->

<p>
$city, $state $in{'zip'}<br>
${lat_deg}d${lat_min}' N latitude<br>
${long_deg}d${long_min}' W longitude<br>
<small>Daylight Savings Time rule: $in{'dst'}</small>

<br><br>
<a href=\"/cgi-bin/hebcal/$in{'zip'}.csv?$ENV{'QUERY_STRING'}\">Click
Here to Download Outlook CSV file</a>
</p>

<p><small>(This is a web interface to Danny Sadinoff's <a
href=\"http://www.sadinoff.com/hebcal/\">hebcal</a> program.)</small></p>

<hr noshade size=1>

<!-- mjrsig start -->
  <em><a href=\"/michael/contact.html\">Michael J. Radwin</a></em>
  <br><br>
<!-- mjrsig end -->

<small>
<!-- hhmts start -->
Last modified: Tue Apr  6 16:52:52 PDT 1999
<!-- hhmts end -->
</small>

</body> </html>
";

    close(STDOUT);
    exit(0);

    1;
}

1;
