#!/usr/local/bin/perl5 -w

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use DB_File;
use Time::Local;
use Hebcal;

$author = 'michael@radwin.org';

my($this_mon,$this_year) = (localtime)[4,5];
$this_year += 1900;
$this_mon++;

my($rcsrev) = '$Revision$'; #'
$rcsrev =~ s/\s*\$//g;

my($hhmts) = "<!-- hhmts start -->
Last modified: Wed Sep 13 10:17:58 PDT 2000
<!-- hhmts end -->";

$hhmts =~ s/<!--.*-->//g;
$hhmts =~ s/\n//g;
$hhmts =~ s/Last modified: /Software last updated:\n/g;

$html_footer = "<hr
noshade size=\"1\"><small>$hhmts ($rcsrev)<br><br>Copyright
&copy; $this_year <a href=\"/michael/contact.html\">Michael J. Radwin</a>.
All rights reserved.</small></body></html>
";

# process form params
$q = new CGI;
$q->delete('.s');		# we don't care about submit button

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;
my($server_name) = $q->server_name();
$server_name =~ s/^www\.//;

$q->default_dtd("-//W3C//DTD HTML 4.01 Transitional//EN\"\n" .
		"\t\"http://www.w3.org/TR/html4/loose.dtd");

if (! $q->param('v') &&
    defined $q->raw_cookie() &&
    $q->raw_cookie() =~ /[\s;,]*C=([^\s,;]+)/)
{
    &process_cookie($q,$1);
}

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
my($key);
foreach $key ($q->param())
{
    $val = $q->param($key);
    $val =~ s/[^\w\s-]//g;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

my($now) = time;
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
    localtime($now);
$year += 1900;
$friday = $now + ((4 - $wday) * 60 * 60 * 24);
$saturday = $now + ((6 - $wday) * 60 * 60 * 24);

$sat_year = (localtime($saturday))[5] + 1900;
$cmd  = '/home/users/mradwin/bin/hebcal';

if (defined $q->param('city'))
{
    $q->param('city','New York')
	unless defined($Hebcal::city_tz{$q->param('city')});

    $q->param('geo','city');
    $q->param('tz',$Hebcal::city_tz{$q->param('city')});
    $q->delete('dst');

    $cmd .= " -C '" . $q->param('city') . "'";

    $city_descr = $q->param('city');
}
elsif (defined $q->param('zip'))
{
    $q->param('dst','usa')
	unless $q->param('dst');
    $q->param('tz','auto')
	unless $q->param('tz');
    $q->param('geo','zip');

    if ($q->param('zip') eq '' || $q->param('zip') !~ /^\d{5}$/)
    {
	$q->param('zip','90210');
	$q->param('tz','-8');
	$q->param('dst','usa');
    }

    $dbmfile = 'zips.db';
    tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	|| die "Can't tie $dbmfile: $!\n";

    $val = $DB{$q->param('zip')};
    unless (defined $val)
    {
	$q->param('zip','90210');
	$q->param('tz','-8');
	$q->param('dst','usa');
	$val = $DB{$q->param('zip')};
    }
    untie(%DB);

    die "bad zipcode database\n" unless defined $val;

    ($long_deg,$long_min,$lat_deg,$lat_min) = unpack('ncnc', $val);
    ($city,$state) = split(/\0/, substr($val,6));

    if (($state eq 'HI' || $state eq 'AZ') &&
	$q->param('dst') eq 'usa')
    {
	$q->param('dst','none');
    }

    my(@city) = split(/([- ])/, $city);
    $city = '';
    foreach (@city)
    {
	$_ = lc($_);
	$_ = "\u$_";		# inital cap
	$city .= $_;
    }

    $city_descr = "$city, $state &nbsp;" . $q->param('zip');

    if ($q->param('tz') !~ /^-?\d+$/)
    {
	$ok = 0;
	if (defined $Hebcal::known_timezones{$q->param('zip')})
	{
	    if ($Hebcal::known_timezones{$q->param('zip')} ne '??')
	    {
		$q->param('tz',$Hebcal::known_timezones{$q->param('zip')});
		$ok = 1;
	    }
	}
	elsif (defined $Hebcal::known_timezones{substr($q->param('zip'),0,3)})
	{
	    if ($Hebcal::known_timezones{substr($q->param('zip'),0,3)} ne '??')
	    {
		$q->param('tz',$Hebcal::known_timezones{substr($q->param('zip'),0,3)});
		$ok = 1;
	    }
	}
	elsif (defined $Hebcal::known_timezones{$state})
	{
	    if ($Hebcal::known_timezones{$state} ne '??')
	    {
		$q->param('tz',$Hebcal::known_timezones{$state});
		$ok = 1;
	    }
	}

	die "panic: unknown timezone\n" unless $ok;
    }

    $cmd .= " -L $long_deg,$long_min -l $lat_deg,$lat_min";
}
else
{
    $q->param('city','New York');
    $q->param('geo','city');
    $q->param('tz',$Hebcal::city_tz{$q->param('city')});
    $q->delete('dst');

    $cmd .= " -C '" . $q->param('city') . "'";

    $city_descr = $q->param('city');
}

$cmd .= " -z " . $q->param('tz')
    if (defined $q->param('tz') && $q->param('tz') ne '');

$cmd .= " -Z " . $q->param('dst')
    if (defined $q->param('dst') && $q->param('dst') ne '');

$cmd .= " -m " . $q->param('m')
    if (defined $q->param('m') && $q->param('m') =~ /^\d+$/);

$cmd .= ' -s -h -c ' . $sat_year;

print STDOUT $q->header(),
    $q->start_html(-title => "1-Click Shabbat for $city_descr",
		   -target=>'_top',
		   -head => [
			     "<meta http-equiv=\"PICS-Label\" content='(PICS-1.1 \"http://www.rsac.org/ratingsv01.html\" l gen true by \"$author\" on \"1998.03.10T11:49-0800\" r (n 0 s 0 v 0 l 0))'>",
			     $q->Link({-rel => 'stylesheet',
				       -href => '/style.css',
				       -type => 'text/css'}),
			     ],
		   -meta => {'robots' => 'noindex'});

print STDOUT
    "<table width=\"100%\"\nclass=\"navbar\">",
    "<tr><td><small>",
    "<strong><a\nhref=\"/\">", $server_name, "</a></strong>\n",
    "<tt>-&gt;</tt>\n",
    "1-Click Shabbat</small></td>",
    "<td align=\"right\"><small><a\n",
    "href=\"/search/\">Search</a></small>",
    "</td></tr></table>",
    "<h1>1-Click\nShabbat for $city_descr</h1>\n";

my($cmd_pretty) = $cmd;
$cmd_pretty =~ s,.*/,,; # basename
print STDOUT "<!-- $cmd_pretty -->\n";

my($loc) = (defined $city_descr && $city_descr ne '') ?
    "in $city_descr" : '';
$loc =~ s/\s*&nbsp;\s*/ /g;

my(@events) = &invoke_hebcal($cmd, $loc);

print STDOUT "<pre>";

# header row
my($hdr) = "DoW YYYY/MM/DD  Description";
print STDOUT $hdr, "\n";
print STDOUT '-' x length($hdr), "\n";

my($numEntries) = scalar(@events);
my($i);
for ($i = 0; $i < $numEntries; $i++)
{
    $time = &timelocal(0,0,0,
		       $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		       $events[$i]->[$Hebcal::EVT_IDX_MON],
		       $events[$i]->[$Hebcal::EVT_IDX_YEAR] - 1900,
		       '','','');
    next if $time < $friday || $time > $saturday;

    my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
    my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
    my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
    my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

    my($min) = $events[$i]->[$Hebcal::EVT_IDX_MIN];
    my($hour) = $events[$i]->[$Hebcal::EVT_IDX_HOUR];
    $hour -= 12 if $hour > 12;

    my($dow) = ($year > 1969 && $year < 2038) ?
	$Hebcal::DoW[&get_dow($year - 1900, $mon - 1, $mday)] . ' ' : '';
    printf STDOUT ("%s%04d/%02d/%02d  %s",
		   $dow, $year, $mon, $mday, $subj);
    printf STDOUT (": %d:%02d", $hour, $min)
	if ($events[$i]->[$Hebcal::EVT_IDX_UNTIMED] == 0);
    print STDOUT "\n";
}

print STDOUT "</pre>";
print STDOUT $html_footer;

close(STDOUT);
exit(0);
