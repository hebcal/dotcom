#!/usr/local/bin/perl -w

########################################################################
# compute yahrzeit dates based on gregorian calendar based on Hebcal
#
# Copyright (c) 2002  Michael J. Radwin.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
########################################################################

use lib "/pub/m/r/mradwin/private/lib/perl5/site_perl";

use CGI qw(-no_xhtml);
use CGI::Carp qw(fatalsToBrowser);
use Time::Local;
use Hebcal;
use Palm::DBA;
use POSIX;
use Date::Calc;
use strict;

my($this_year) = (localtime)[5];
$this_year += 1900;

my($rcsrev) = '$Revision$'; #'

# process form params
my($q) = new CGI;

my($script_name) = $q->script_name();
$script_name =~ s,/index.html$,/,;

# sanitize input to prevent people from trying to hack the site.
# remove anthing other than word chars, white space, or hyphens.
my($key);
foreach $key ($q->param())
{
    next if $key =~ /^ref_(url|text)$/;
    my($val) = $q->param($key);
    $val = '' unless defined $val;
    $val =~ s/[^\w\s\.-]//g
	unless $key =~ /^n\d+$/;
    $val =~ s/^\s*//g;		# nuke leading
    $val =~ s/\s*$//g;		# and trailing whitespace
    $q->param($key,$val);
}

my(%yahrzeits) = ();
my(%ytype) = ();
foreach $key (1 .. 5)
{
    if (defined $q->param("m$key") &&
	defined $q->param("d$key") &&
	defined $q->param("y$key") &&
	$q->param("m$key") =~ /^\d{1,2}$/ &&
	$q->param("d$key") =~ /^\d{1,2}$/ &&
	$q->param("y$key") =~ /^\d{2,4}$/)
    {
	$q->param("y$key", "19" . $q->param("y$key"))
	    if $q->param("y$key") =~ /^\d{2}$/;
	$q->param("n$key", "Person$key") unless $q->param("n$key");

	my $gm = $q->param("m$key");
	my $gd = $q->param("d$key");
	my $gy = $q->param("y$key");

	# after sunset?
	if ($q->param("s$key"))
	{
	    ($gy,$gm,$gd) = Date::Calc::Add_Delta_Days($gy,$gm,$gd,1);
	}

	$yahrzeits{$q->param("n$key")} =
	    sprintf("%02d %02d %4d %s",
		    $gm,
		    $gd,
		    $gy,
		    $q->param("n$key"));
	$ytype{$q->param("n$key")} = 
	    ($q->param("t$key") eq 'Yahrzeit') ?
		$q->param("t$key") : 'Hebrew ' . $q->param("t$key");
    }
}

my($cfg) = $q->param('cfg');
if (! defined $q->path_info())
{
    &results_page();
}
elsif ($q->path_info() =~ /[^\/]+.csv$/)
{
    &csv_display();
}
elsif ($q->path_info() =~ /[^\/]+.dba$/)
{
    &dba_display();
}
elsif ($q->path_info() =~ /[^\/]+\.tsv$/)
{
    &macintosh_datebook_display();
}
elsif ($q->path_info() =~ /[^\/]+\.vcs$/)
{
    # text/x-vCalendar
    &vcalendar_display();
}
else
{
    &results_page();
}

close(STDOUT);
exit(0);

sub macintosh_datebook_display {
    my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

    Hebcal::macintosh_datebook($q, \@events);
}

sub vcalendar_display() {
    my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

    Hebcal::vcalendar_write_contents($q, \@events);
}

sub dba_display
{
    my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

    Hebcal::export_http_header($q, 'application/x-palm-dba');

    my($path_info) = $q->path_info();
    $path_info =~ s,^.*/,,;

    &Palm::DBA::write_header($path_info);
    &Palm::DBA::write_contents(\@events, 0, 0);
}

sub csv_display
{
    my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);

    my $euro = defined $q->param('euro') ? 1 : 0;
    Hebcal::csv_write_contents($q, \@events, $euro);
}

sub my_invoke_hebcal {
    my($this_year,$y,$t) = @_;
    my(@events2) = ();

    my($tmpfile) = POSIX::tmpnam();
    open(T, ">$tmpfile") || die "$tmpfile: $!\n";
    foreach $key (keys %{$y})
    {
	print T $y->{$key}, "\n";
    }
    close(T);

    my($cmd) = "./hebcal -D -x -Y $tmpfile";

    my(%greg2heb) = ();
    my($year);

    foreach $year ($this_year .. ($this_year + 10))
    {
	my(@events) = &Hebcal::invoke_hebcal("$cmd $year", '');
	my($numEntries) = scalar(@events);
	my($i);
	for ($i = 0; $i < $numEntries; $i++)
	{
	    my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
	    my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
	    my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
	    my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];
	
	    if ($subj =~ /,\s+\d{4}\s*$/)
	    {
		$greg2heb{sprintf("%04d%02d%02d", $year, $mon, $mday)} = $subj;
		next;
	    }

	    if (defined $y->{$subj})
	    {
		my($subj2) = "${subj}'s " . $t->{$subj};
		my($isodate) = sprintf("%04d%02d%02d", $year, $mon, $mday);

		$subj2 .= " ($greg2heb{$isodate})"
		    if (defined $greg2heb{$isodate});

		push(@events2,
		     [$subj2,
		      $events[$i]->[$Hebcal::EVT_IDX_UNTIMED],
		      $events[$i]->[$Hebcal::EVT_IDX_MIN],
		      $events[$i]->[$Hebcal::EVT_IDX_HOUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		      $events[$i]->[$Hebcal::EVT_IDX_MON],
		      $events[$i]->[$Hebcal::EVT_IDX_YEAR],
		      $events[$i]->[$Hebcal::EVT_IDX_DUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MEMO],
		      $events[$i]->[$Hebcal::EVT_IDX_YOMTOV],
		      ]);
	    }
	    elsif ($subj eq 'Pesach VIII' || $subj eq 'Shavuot II' ||
		   $subj eq 'Yom Kippur' || $subj eq 'Shmini Atzeret')
	    {
		next unless defined $q->param('yizkor') &&
		    ($q->param('yizkor') eq 'on' ||
		     $q->param('yizkor') eq '1');

		my($subj2) = "Yizkor ($subj)";

		push(@events2,
		     [$subj2,
		      $events[$i]->[$Hebcal::EVT_IDX_UNTIMED],
		      $events[$i]->[$Hebcal::EVT_IDX_MIN],
		      $events[$i]->[$Hebcal::EVT_IDX_HOUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MDAY],
		      $events[$i]->[$Hebcal::EVT_IDX_MON],
		      $events[$i]->[$Hebcal::EVT_IDX_YEAR],
		      $events[$i]->[$Hebcal::EVT_IDX_DUR],
		      $events[$i]->[$Hebcal::EVT_IDX_MEMO],
		      $events[$i]->[$Hebcal::EVT_IDX_YOMTOV],
		      ]);
	    }
	}
    }

    unlink($tmpfile);
    @events2;
}

sub results_page {
    my($target) = (defined $cfg && $cfg eq 'i')
	? '' : '_top';
    my($type) =  (defined $cfg && $cfg eq 'j')
	? 'application/x-javascript' : 'text/html';

    print STDOUT $q->header(-type => $type);

    if (defined $cfg && $cfg eq 'j')
    {
	# nothing
    }
    else
    {
	&Hebcal::out_html
	    ($cfg, &Hebcal::start_html
	     ($q,
	      'Hebcal Yahrzeit, Birthday and Anniversary Calendar',
	      [],
	      { 'keywords' => 'yahzeit,yahrzeit,yohrzeit,yohrtzeit,yartzeit,yarzeit,yortzeit,yorzeit,yizkor,yiskor,kaddish' },
	      $target)
	     );
    }

    if (defined $cfg && $cfg =~ /^[ij]$/)
    {
	my($self_url) = join('', "http://", $q->virtual_host(), $script_name);
	if (defined $ENV{'HTTP_REFERER'} && $ENV{'HTTP_REFERER'} !~ /^\s*$/)
	{
	    $self_url .= "?.from=" . &Hebcal::url_escape($ENV{'HTTP_REFERER'});
	}
	elsif ($q->param('.from'))
	{
	    $self_url .= "?.from=" . &Hebcal::url_escape($q->param('.from'));
	}

	&Hebcal::out_html
	    ($cfg,
	     "<h3><a target=\"_top\"\nhref=\"$self_url\">Yahrzeit,\n",
	     "Birthday and Anniversary\nCalendar</a></h3>\n");
    }
    else
    {
	&Hebcal::out_html
	    ($cfg,
	     &Hebcal::navbar2($q,
			      "Yahrzeit, Birthday and Anniversary\nCalendar",
			      1, undef, undef),
	     "<h1>Yahrzeit,\nBirthday and Anniversary Calendar</h1>\n");
    }

    if ($q->param('ref_url'))
    {
	my($ref_text) = $q->param('ref_text') ? $q->param('ref_text') : 
	    $q->param('ref_url');
	&Hebcal::out_html($cfg,
			  "<center><big><a href=\"", $q->param('ref_url'),
			  "\">Click\nhere to return to $ref_text",
			  "</a></big></center>\n");
    }

&form(1,'','') unless keys %yahrzeits;

my(@events) = &my_invoke_hebcal($this_year, \%yahrzeits, \%ytype);
my($numEntries) = scalar(@events);

if ($numEntries > 0) {
    &Hebcal::out_html($cfg,
		      qq{<p class="goto"><span class="sm-grey">&gt;</span>
<a href="#export">Export calendar to Palm &amp; Outlook</a></p>\n});

    &Hebcal::out_html($cfg,
		      qq{<p>All yahrzeits, birthdays and anniversaries
begin the evening before the date specified. This is because the Jewish
day actually begins at sundown on the previous night.</p>\n});
}

for (my $i = 0; $i < $numEntries; $i++)
{
    if ($events[$i]->[$Hebcal::EVT_IDX_SUBJ] =~ / of Adar/) {
	&Hebcal::out_html($cfg,
"<p><em>Note: the results below contain one ore more anniversary in Adar.\n",
"To learn more about how Hebcal handles these dates, read <a\n",
"href=\"http://www.hebcal.com/help/anniv.html#adar\">How\n",
"does Hebcal determine an anniversary occurring in Adar?</a></em></p>\n",
			  );
	last;
    }
}

&Hebcal::out_html($cfg, "<pre>") unless ($q->param('yizkor'));

for (my $i = 0; $i < $numEntries; $i++)
{
    my($subj) = $events[$i]->[$Hebcal::EVT_IDX_SUBJ];
    my($year) = $events[$i]->[$Hebcal::EVT_IDX_YEAR];
    my($mon) = $events[$i]->[$Hebcal::EVT_IDX_MON] + 1;
    my($mday) = $events[$i]->[$Hebcal::EVT_IDX_MDAY];

    if ($year != $events[$i - 1]->[$Hebcal::EVT_IDX_YEAR] &&
	$q->param('yizkor'))
    {
	&Hebcal::out_html($cfg, "</pre>") unless $i == 0;
	&Hebcal::out_html($cfg, "<h3>$year</h3><pre>");
    }

    my($dow) = $Hebcal::DoW[&Hebcal::get_dow($year, $mon, $mday)] . ' ';

    &Hebcal::out_html
	($cfg,
	 sprintf("%s%02d-%s-%04d  %s\n",
		 $dow, $mday, $Hebcal::MoY_short[$mon-1], $year,
		 &Hebcal::html_entify($subj)));
}

&Hebcal::out_html($cfg, "</pre>\n");

if ($numEntries > 0) {
    &Hebcal::out_html($cfg, Hebcal::download_html($q, 'yahrzeit', \@events));
}

&Hebcal::out_html($cfg, "<hr>\n");

&form(0,'','');
}

sub form
{
    my($head,$message,$help) = @_;

    my(%months) = %Hebcal::MoY_long;

    if ($message ne '')
    {
	$help = '' unless defined $help;
	$message = "<hr noshade size=\"1\"><p><font\ncolor=\"#ff0000\">" .
	    $message . "</font></p>" . $help . "<hr noshade size=\"1\">\n";
    }

    &Hebcal::out_html
	($cfg, qq{$message},
	 "<p>Enter dates (and optionally names) in the form below to\n",
	 "generate a list of Yahrzeit dates, Hebrew Birthdays,\n",
	 "or Hebrew Anniversaries.\n",
	 "After clicking the <b>Compute Calendar</b> button, you\n",
	 "will also be able to download the results.</p>",
	 "<p>For example, you might enter <b>October 20, 1994</b>\n",
	 "to calculate <b>Reb Shlomo Carlebach</b>'s yahrzeit.</p>\n");

    &Hebcal::out_html
	($cfg, qq{<form name="f1" id="f1"\naction="$script_name">});

    my($i_max) = (defined $cfg && $cfg =~ /^[ij]$/)
	? 2 : 6;
    for (my $i = 1; $i < $i_max; $i++)
    {
	&show_row($q,$cfg,$i,\%months);
    }

    &Hebcal::out_html($cfg, "<label\nfor=\"yizkor\">",
    $q->checkbox(-name => 'yizkor',
		 -id => 'yizkor',
		 -label => "\nInclude Yizkor dates"),
    "</label><br>",
    $q->hidden(-name => 'ref_url'),
    $q->hidden(-name => 'ref_text'),
#    $q->hidden(-name => 'cfg'),
#    $q->hidden(-name => 'rand',-value => time(),-override => 1),
    qq{<input\ntype="submit" value="Compute Calendar"></form>\n});

    if (defined $cfg && $cfg eq 'i')
    {
	&Hebcal::out_html($cfg, "</body></html>\n");
    }
    elsif (defined $cfg && $cfg eq 'j')
    {
	# nothing
    }
    else
    {
	&Hebcal::out_html
	    ($cfg, qq{<hr noshade size=\"1\">\n});

	&Hebcal::out_html($cfg,
	qq{<p><a href="/help/link.html#yahrzeit-tags">How\n},
	qq{can my synagogue link to the Yahrzeit, Birthday and Anniversary\n},
	qq{Calendar from its own website?</a></p>});

	&Hebcal::out_html($cfg, &Hebcal::html_footer($q,$rcsrev));
    }

    exit(0);
}

sub show_row {
    my($q,$cfg,$i,$months) = @_;

    &Hebcal::out_html
	($cfg,
	 $q->popup_menu(-name => "t$i",
			-id => "t$i",
			-values => ['Yahrzeit','Birthday','Anniversary']),
	 "\n<small>Month:</small>\n",
	 $q->popup_menu(-name => "m$i",
			-id => "m$i",
			-values => [1..12],
			-labels => $months),
	 "\n<small>Day:</small>\n",
	 $q->textfield(-name => "d$i",
		       -id => "d$i",
		       -maxlength => 2,
		       -size => 2),
	 "\n<small>Year:</small>\n",
	 $q->textfield(-name => "y$i",
		       -id => "y$i",
		       -maxlength => 4,
		       -size => 4),
	 "&nbsp;&nbsp;&nbsp;",
	 "\n<small>Name:</small>\n",
	 $q->textfield(-name => "n$i",
		       -id => "n$i"),
	 qq{\n<small><label for="s$i">},
	 $q->checkbox(-name => "s$i",
		      -id => "s$i",
		      -label => "\nAfter sunset"),
	 qq{</label></small>},
	 "<br>\n",
	 );
}

# local variables:
# mode: perl
# end:
