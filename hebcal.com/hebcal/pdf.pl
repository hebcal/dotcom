#!/usr/bin/perl

########################################################################
# PDF Jewish holiday calendar generator
#
# Copyright (c) 2013 Michael J. Radwin.
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

use strict;
use warnings;
use utf8;

use PDF::API2;
use Date::Calc;

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";
use lib "/Users/mradwin/dotcom/local/share/perl";
use lib "/Users/mradwin/dotcom/local/share/perl/site_perl";
use Hebcal ();

use constant WIDTH => 792;
use constant HEIGHT => 612;
use constant TMARGIN => 72;
use constant BMARGIN => 36;
use constant LMARGIN => 36;
use constant RMARGIN => 36;
use constant COLUMNS => 7;

my $pdf = PDF::API2->new(-file => "$0.pdf");

$pdf->info(
	   'Author'        => "Hebcal Jewish Calendar",
	   'Title'        => "some Publication",
);

my %font;
$font{'plain'} = $pdf->ttfont('./fonts/Open_Sans/OpenSans-Regular.ttf');
$font{'condensed'} = $pdf->ttfont('./fonts/Open_Sans_Condensed/OpenSans-CondLight.ttf');
$font{'bold'} = $pdf->ttfont('./fonts/Open_Sans/OpenSans-Bold.ttf');
$font{'hebrew'} = $pdf->ttfont('./fonts/SBL_Hebrew/SBL_Hbrw.ttf');

my @events = get_sample_events();
my %cells;
foreach my $evt (@events) {
    my $year = $evt->[$Hebcal::EVT_IDX_YEAR];
    my $mon = $evt->[$Hebcal::EVT_IDX_MON] + 1;
    my $mday = $evt->[$Hebcal::EVT_IDX_MDAY];
    my $cal_id = sprintf("%04d-%02d", $year, $mon);
    push(@{$cells{$cal_id}{$mday}}, $evt);
}

my @DAYS = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
foreach my $year_month (sort keys %cells) {
    my($year,$month) = split(/-/, $year_month);
    $month =~ s/^0//;

    my $month_name = Date::Calc::Month_to_Text($month);
    my $daysinmonth = Date::Calc::Days_in_Month($year,$month);
    my $day = 1;

    # returns "1" for Monday, "2" for Tuesday .. until "7" for Sunday
    my $dow = Date::Calc::Day_of_Week($year,$month,$day);
    $dow = 0 if $dow == 7;	# treat Sunday as day 0 (not day 7 as Date::Calc does)

    my($hspace, $vspace) = (0, 0);   # Space between columns and rows
    my $rows = 5;
    if (($daysinmonth == 31 && $dow >= 5) || ($daysinmonth == 30 && $dow == 6)) {
	$rows = 6;
    }

    my $colwidth = (WIDTH - LMARGIN - RMARGIN - (COLUMNS - 1) * $hspace) / COLUMNS;
    my $rowheight = (HEIGHT - TMARGIN - BMARGIN - ($rows - 1) * $vspace) / $rows;

    my $page = $pdf->page;
    $page->mediabox(WIDTH, HEIGHT);

    my $text = $page->text();	# Add the Text object
    $text->translate(WIDTH / 2, HEIGHT - TMARGIN + 24); # Position the Text object
    $text->font($font{'bold'}, 24); # Assign a font to the Text object
    $text->text_center("$month_name $year"); # Draw the string

    my $g = $page->gfx();
    $g->strokecolor("#aaaaaa");
    $g->linewidth(1);
    $g->rect(LMARGIN, BMARGIN,
	     WIDTH - LMARGIN - RMARGIN,
	     HEIGHT - TMARGIN - BMARGIN);
    $g->stroke();
    $g->endpath(); 

    $text->font($font{'plain'},10);
    for (my $i = 0; $i < scalar(@DAYS); $i++) {
	my $x = LMARGIN + $i * ($colwidth + $hspace) + ($colwidth / 2);
	$text->translate($x, HEIGHT - TMARGIN + 6);
	$text->text_center($DAYS[$i]);
    }

    # Loop through the columns
    foreach my $c (0 .. COLUMNS - 1) {
	my $x = LMARGIN + $c * ($colwidth + $hspace);
	if ($c > 0) {
	    # Print a vertical grid line
	    $g->move($x, BMARGIN);
	    $g->line($x, HEIGHT - TMARGIN);
	    $g->stroke;
	    $g->endpath();
	}
    
	# Loop through the rows
	foreach my $r (0 .. $rows - 1) {
	    my $y = HEIGHT - TMARGIN - $r * ($rowheight + $vspace);
	    if ($r > 0) {
		# Print a horizontal grid line
		$g->move(LMARGIN, $y);
		$g->line(WIDTH - RMARGIN, $y);
		$g->stroke;
		$g->endpath();
	    }
	}
    }

    my $xpos = LMARGIN + $colwidth - 4;
    $xpos += ($dow * $colwidth);
    my $ypos = HEIGHT - TMARGIN - 12;
    for (my $mday = 1; $mday <= $daysinmonth; $mday++) {
	# render day number
	$text->font($font{'plain'}, 11);
	$text->fillcolor("#000000");
	$text->translate($xpos, $ypos);
	$text->text_right($mday);

	# events within day $mday
	if (defined $cells{$year_month}{$mday}) {
	    $text->translate($xpos - $colwidth + 8, $ypos - 18);
	    foreach my $evt (@{$cells{$year_month}{$mday}}) {
		render_event($text, $evt, "s");
	    }
	}

	$xpos += $colwidth;	# move to the right by one cell
	if (++$dow == 7) {
	    $dow = 0;
	    $xpos = LMARGIN + $colwidth - 4;
	    $ypos -= $rowheight; # move down the page
	}
    }

    $text->translate(WIDTH - RMARGIN, BMARGIN - 12);
    $text->font($font{'condensed'}, 8);
    $text->fillcolor("#000000");
    $text->text_right("This Jewish holiday calendar from www.hebcal.com is licensed under Creative Commons Attribution 3.0");
}

$pdf->save;
$pdf->end();

exit(0);

sub render_event {
    my($text,$evt,$lg) = @_;

    my $color = "#000000";
    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
    if (($subj =~ /^\d+\w+.+, \d{4,}$/) || ($subj =~ /^\d+\w+ day of the Omer$/)) {
	$color = "#666666";
    }
    $text->fillcolor($color);

    if ($evt->[$Hebcal::EVT_IDX_UNTIMED] == 0) {
	my $min = $evt->[$Hebcal::EVT_IDX_MIN];
	my $hour = $evt->[$Hebcal::EVT_IDX_HOUR];
	$hour -= 12 if $hour > 12;
	my $time_formatted = sprintf("%d:%02dp ", $hour, $min);
	$text->font($font{'bold'}, 8);
	$text->text($time_formatted);
    }

    my($href,$hebrew,$memo) = Hebcal::get_holiday_anchor($subj,0,undef);
    if ($lg eq "h" && $hebrew) {
	my $str = scalar reverse($hebrew);
	$str =~ s/(\d+)/scalar reverse($1)/ge;
	$str =~ s/\(/\cA/g;
	$str =~ s/\)/\(/g;
	$str =~ s/\cA/\)/g;
	$text->font($font{'hebrew'}, 10);
	$text->text($str);
    } elsif ($evt->[$Hebcal::EVT_IDX_YOMTOV] == 1) {
	$text->font($font{'bold'}, 8);
	$text->text($subj);
    } elsif (length($subj) >= 25) {
	$text->font($font{'condensed'}, 9);
	$text->fillcolor("#000000");
	$text->text($subj);
    } elsif ($subj =~ /^Havdalah \((\d+) min\)$/) {
	my $minutes = $1;
	$text->font($font{'plain'}, 8);
	$text->text("Havdalah");
	$text->font($font{'plain'}, 6);
	$text->text(" ($minutes min)");
    } else {
	$text->font($font{'plain'}, 8);
	$text->text($subj);
    }
    $text->cr(-12);
}

sub get_sample_events {
    my @aa = (['22nd of Tevet, 5773',1,-1,-1,'4',0,'2013',0,'',0],
['Candle lighting',0,'46',16,'4',0,'2013',18,'',0],
['23rd of Tevet, 5773',1,-1,-1,'5',0,'2013',0,'',0],
['Parashat Shemot',1,-1,-1,5,0,'2013',0,'',0],
['Havdalah (42 min)',0,'46',17,5,0,'2013',1,'',0],
['29th of Tevet, 5773',1,-1,-1,'11',0,'2013',0,'',0],
['Candle lighting',0,'52',16,'11',0,'2013',18,'',0],
['1st of Sh\'vat, 5773',1,-1,-1,'12',0,'2013',0,'',0],
['Parashat Vaera',1,-1,-1,'12',0,'2013',0,'',0],
['Rosh Chodesh Sh\'vat',1,-1,-1,12,0,'2013',0,'Beginning of new Hebrew month of Sh\'vat',0],
['Havdalah (42 min)',0,'53',17,12,0,'2013',1,'',0],
['7th of Sh\'vat, 5773',1,-1,-1,'18',0,'2013',0,'',0],
['Candle lighting',0,'59',16,'18',0,'2013',18,'',0],
['8th of Sh\'vat, 5773',1,-1,-1,'19',0,'2013',0,'',0],
['Parashat Bo',1,-1,-1,19,0,'2013',0,'',0],
['Havdalah (42 min)',0,'00',18,19,0,'2013',1,'',0],
['14th of Sh\'vat, 5773',1,-1,-1,'25',0,'2013',0,'',0],
['Candle lighting',0,'07',17,'25',0,'2013',18,'',0],
['15th of Sh\'vat, 5773',1,-1,-1,'26',0,'2013',0,'',0],
['Parashat Beshalach',1,-1,-1,'26',0,'2013',0,'',0],
['Tu BiShvat',1,-1,-1,26,0,'2013',0,'New Year for Trees',0],
['Havdalah (42 min)',0,'08',18,26,0,'2013',1,'',0],
['21st of Sh\'vat, 5773',1,-1,-1,'1',1,'2013',0,'',0],
['Candle lighting',0,'14',17,'1',1,'2013',18,'',0],
['22nd of Sh\'vat, 5773',1,-1,-1,'2',1,'2013',0,'',0],
['Parashat Yitro',1,-1,-1,2,1,'2013',0,'',0],
['Havdalah (42 min)',0,'15',18,2,1,'2013',1,'',0],
['28th of Sh\'vat, 5773',1,-1,-1,'8',1,'2013',0,'',0],
['Candle lighting',0,'22',17,'8',1,'2013',18,'',0],
['29th of Sh\'vat, 5773',1,-1,-1,'9',1,'2013',0,'',0],
['Parashat Mishpatim',1,-1,-1,'9',1,'2013',0,'',0],
['Shabbat Shekalim',1,-1,-1,9,1,'2013',0,'Shabbat before Rosh Chodesh Adar',0],
['Havdalah (42 min)',0,'23',18,9,1,'2013',1,'',0],
['30th of Sh\'vat, 5773',1,-1,-1,'10',1,'2013',0,'',0],
['Rosh Chodesh Adar',1,-1,-1,'10',1,'2013',0,'Beginning of new Hebrew month of Adar',0],
['1st of Adar, 5773',1,-1,-1,'11',1,'2013',0,'',0],
['Rosh Chodesh Adar',1,-1,-1,'11',1,'2013',0,'Beginning of new Hebrew month of Adar',0],
['5th of Adar, 5773',1,-1,-1,'15',1,'2013',0,'',0],
['Candle lighting',0,'29',17,'15',1,'2013',18,'',0],
['6th of Adar, 5773',1,-1,-1,'16',1,'2013',0,'',0],
['Parashat Terumah',1,-1,-1,16,1,'2013',0,'',0],
['Havdalah (42 min)',0,'31',18,16,1,'2013',1,'',0],
['11th of Adar, 5773',1,-1,-1,'21',1,'2013',0,'',0],
['Ta\'anit Esther',1,-1,-1,'21',1,'2013',0,'Fast of Esther',0],
['12th of Adar, 5773',1,-1,-1,'22',1,'2013',0,'',0],
['Candle lighting',0,'37',17,'22',1,'2013',18,'',0],
['13th of Adar, 5773',1,-1,-1,'23',1,'2013',0,'',0],
['Parashat Tetzaveh',1,-1,-1,'23',1,'2013',0,'',0],
['Shabbat Zachor',1,-1,-1,'23',1,'2013',0,'Shabbat before Purim',0],
['Erev Purim',1,-1,-1,23,1,'2013',0,'Purim is one of the most joyous and fun holidays on the Jewish calendar',0],
['Havdalah (42 min)',0,'38',18,23,1,'2013',1,'',0],
['14th of Adar, 5773',1,-1,-1,'24',1,'2013',0,'',0],
['Purim',1,-1,-1,'24',1,'2013',0,'Purim is one of the most joyous and fun holidays on the Jewish calendar',0],
['15th of Adar, 5773',1,-1,-1,'25',1,'2013',0,'',0],
['Shushan Purim',1,-1,-1,'25',1,'2013',0,'Purim celebrated in Jerusalem and walled cities',0],
['19th of Adar, 5773',1,-1,-1,'1',2,'2013',0,'',0],
['Candle lighting',0,'44',17,'1',2,'2013',18,'',0],
['20th of Adar, 5773',1,-1,-1,'2',2,'2013',0,'',0],
['Parashat Ki Tisa',1,-1,-1,'2',2,'2013',0,'',0],
['Shabbat Parah',1,-1,-1,2,2,'2013',0,'Shabbat of the Red Heifer',0],
['Havdalah (42 min)',0,'45',18,2,2,'2013',1,'',0],
['26th of Adar, 5773',1,-1,-1,'8',2,'2013',0,'',0],
['Candle lighting',0,'51',17,'8',2,'2013',18,'',0],
['27th of Adar, 5773',1,-1,-1,'9',2,'2013',0,'',0],
['Parashat Vayakhel-Pekudei',1,-1,-1,'9',2,'2013',0,'',0],
['Shabbat HaChodesh',1,-1,-1,9,2,'2013',0,'Shabbat before Rosh Chodesh Nissan',0],
['Havdalah (42 min)',0,'52',18,9,2,'2013',1,'',0],
['1st of Nisan, 5773',1,-1,-1,'12',2,'2013',0,'',0],
['Rosh Chodesh Nisan',1,-1,-1,'12',2,'2013',0,'Beginning of new Hebrew month of Nisan',0],
['4th of Nisan, 5773',1,-1,-1,'15',2,'2013',0,'',0],
['Candle lighting',0,'57',18,'15',2,'2013',18,'',0],
['5th of Nisan, 5773',1,-1,-1,'16',2,'2013',0,'',0],
['Parashat Vayikra',1,-1,-1,16,2,'2013',0,'',0],
['Havdalah (42 min)',0,'58',19,16,2,'2013',1,'',0],
['11th of Nisan, 5773',1,-1,-1,'22',2,'2013',0,'',0],
['Candle lighting',0,'04',19,'22',2,'2013',18,'',0],
['12th of Nisan, 5773',1,-1,-1,'23',2,'2013',0,'',0],
['Parashat Tzav',1,-1,-1,'23',2,'2013',0,'',0],
['Shabbat HaGadol',1,-1,-1,23,2,'2013',0,'Shabbat before Pesach',0],
['Havdalah (42 min)',0,'05',20,23,2,'2013',1,'',0],
['14th of Nisan, 5773',1,-1,-1,'25',2,'2013',0,'',0],
['Ta\'anit Bechorot',1,-1,-1,'25',2,'2013',0,'Fast of the First Born',0],
['Erev Pesach',1,-1,-1,'25',2,'2013',0,'Passover, the Feast of Unleavened Bread',0],
['Candle lighting',0,'06',19,'25',2,'2013',18,'',0],
['15th of Nisan, 5773',1,-1,-1,'26',2,'2013',0,'',0],
['Pesach I',1,-1,-1,'26',2,'2013',0,'Passover, the Feast of Unleavened Bread',1],
['16th of Nisan, 5773',1,-1,-1,'27',2,'2013',0,'',0],
['Pesach II',1,-1,-1,'27',2,'2013',0,'Passover, the Feast of Unleavened Bread',1],
['1st day of the Omer',1,-1,-1,27,2,'2013',0,'',0],
['Havdalah (42 min)',0,'08',20,27,2,'2013',1,'',0],
['17th of Nisan, 5773',1,-1,-1,'28',2,'2013',0,'',0],
['Pesach III (CH\'\'M)',1,-1,-1,'28',2,'2013',0,'Passover, the Feast of Unleavened Bread',0],
['2nd day of the Omer',1,-1,-1,'28',2,'2013',0,'',0],
['18th of Nisan, 5773',1,-1,-1,'29',2,'2013',0,'',0],
['Pesach IV (CH\'\'M)',1,-1,-1,'29',2,'2013',0,'Passover, the Feast of Unleavened Bread',0],
['3rd day of the Omer',1,-1,-1,'29',2,'2013',0,'',0],
['Candle lighting',0,'10',19,'29',2,'2013',18,'',0],
['19th of Nisan, 5773',1,-1,-1,'30',2,'2013',0,'',0],
['Pesach V (CH\'\'M)',1,-1,-1,'30',2,'2013',0,'Passover, the Feast of Unleavened Bread',0],
['4th day of the Omer',1,-1,-1,30,2,'2013',0,'',0],
['Havdalah (42 min)',0,'11',20,30,2,'2013',1,'',0],
['20th of Nisan, 5773',1,-1,-1,'31',2,'2013',0,'',0],
['Pesach VI (CH\'\'M)',1,-1,-1,'31',2,'2013',0,'Passover, the Feast of Unleavened Bread',0],
['5th day of the Omer',1,-1,-1,'31',2,'2013',0,'',0],
['Candle lighting',0,'12',19,'31',2,'2013',18,'',0],
['21st of Nisan, 5773',1,-1,-1,'1',3,'2013',0,'',0],
['Pesach VII',1,-1,-1,'1',3,'2013',0,'Passover, the Feast of Unleavened Bread',1],
['6th day of the Omer',1,-1,-1,'1',3,'2013',0,'',0],
['22nd of Nisan, 5773',1,-1,-1,'2',3,'2013',0,'',0],
['Pesach VIII',1,-1,-1,'2',3,'2013',0,'Passover, the Feast of Unleavened Bread',1],
['7th day of the Omer',1,-1,-1,2,3,'2013',0,'',0],
['Havdalah (42 min)',0,'14',20,2,3,'2013',1,'',0],
['23rd of Nisan, 5773',1,-1,-1,'3',3,'2013',0,'',0],
['8th day of the Omer',1,-1,-1,'3',3,'2013',0,'',0],
['24th of Nisan, 5773',1,-1,-1,'4',3,'2013',0,'',0],
['9th day of the Omer',1,-1,-1,'4',3,'2013',0,'',0],
['25th of Nisan, 5773',1,-1,-1,'5',3,'2013',0,'',0],
['10th day of the Omer',1,-1,-1,'5',3,'2013',0,'',0],
['Candle lighting',0,'16',19,'5',3,'2013',18,'',0],
['26th of Nisan, 5773',1,-1,-1,'6',3,'2013',0,'',0],
['Parashat Shmini',1,-1,-1,'6',3,'2013',0,'',0],
['11th day of the Omer',1,-1,-1,6,3,'2013',0,'',0],
['Havdalah (42 min)',0,'17',20,6,3,'2013',1,'',0],
['27th of Nisan, 5773',1,-1,-1,'7',3,'2013',0,'',0],
['12th day of the Omer',1,-1,-1,'7',3,'2013',0,'',0],
['28th of Nisan, 5773',1,-1,-1,'8',3,'2013',0,'',0],
['Yom HaShoah',1,-1,-1,'8',3,'2013',0,'Holocaust Memorial Day',0],
['13th day of the Omer',1,-1,-1,'8',3,'2013',0,'',0],
['29th of Nisan, 5773',1,-1,-1,'9',3,'2013',0,'',0],
['14th day of the Omer',1,-1,-1,'9',3,'2013',0,'',0],
['30th of Nisan, 5773',1,-1,-1,'10',3,'2013',0,'',0],
['Rosh Chodesh Iyyar',1,-1,-1,'10',3,'2013',0,'Beginning of new Hebrew month of Iyyar',0],
['15th day of the Omer',1,-1,-1,'10',3,'2013',0,'',0],
['1st of Iyyar, 5773',1,-1,-1,'11',3,'2013',0,'',0],
['Rosh Chodesh Iyyar',1,-1,-1,'11',3,'2013',0,'Beginning of new Hebrew month of Iyyar',0],
['16th day of the Omer',1,-1,-1,'11',3,'2013',0,'',0],
['2nd of Iyyar, 5773',1,-1,-1,'12',3,'2013',0,'',0],
['17th day of the Omer',1,-1,-1,'12',3,'2013',0,'',0],
['Candle lighting',0,'23',19,'12',3,'2013',18,'',0],
['3rd of Iyyar, 5773',1,-1,-1,'13',3,'2013',0,'',0],
['Parashat Tazria-Metzora',1,-1,-1,'13',3,'2013',0,'',0],
['18th day of the Omer',1,-1,-1,13,3,'2013',0,'',0],
['Havdalah (42 min)',0,'23',20,13,3,'2013',1,'',0],
['4th of Iyyar, 5773',1,-1,-1,'14',3,'2013',0,'',0],
['19th day of the Omer',1,-1,-1,'14',3,'2013',0,'',0],
['5th of Iyyar, 5773',1,-1,-1,'15',3,'2013',0,'',0],
['Yom HaZikaron',1,-1,-1,'15',3,'2013',0,'Israeli Memorial Day',0],
['20th day of the Omer',1,-1,-1,'15',3,'2013',0,'',0],
['6th of Iyyar, 5773',1,-1,-1,'16',3,'2013',0,'',0],
['Yom HaAtzma\'ut',1,-1,-1,'16',3,'2013',0,'Israeli Independence Day',0],
['21st day of the Omer',1,-1,-1,'16',3,'2013',0,'',0],
['7th of Iyyar, 5773',1,-1,-1,'17',3,'2013',0,'',0],
['22nd day of the Omer',1,-1,-1,'17',3,'2013',0,'',0],
['8th of Iyyar, 5773',1,-1,-1,'18',3,'2013',0,'',0],
['23rd day of the Omer',1,-1,-1,'18',3,'2013',0,'',0],
['9th of Iyyar, 5773',1,-1,-1,'19',3,'2013',0,'',0],
['24th day of the Omer',1,-1,-1,'19',3,'2013',0,'',0],
['Candle lighting',0,'29',19,'19',3,'2013',18,'',0],
['10th of Iyyar, 5773',1,-1,-1,'20',3,'2013',0,'',0],
['Parashat Achrei Mot-Kedoshim',1,-1,-1,'20',3,'2013',0,'',0],
['25th day of the Omer',1,-1,-1,20,3,'2013',0,'',0],
['Havdalah (42 min)',0,'30',20,20,3,'2013',1,'',0],
['11th of Iyyar, 5773',1,-1,-1,'21',3,'2013',0,'',0],
['26th day of the Omer',1,-1,-1,'21',3,'2013',0,'',0],
['12th of Iyyar, 5773',1,-1,-1,'22',3,'2013',0,'',0],
['27th day of the Omer',1,-1,-1,'22',3,'2013',0,'',0],
['13th of Iyyar, 5773',1,-1,-1,'23',3,'2013',0,'',0],
['28th day of the Omer',1,-1,-1,'23',3,'2013',0,'',0],
['14th of Iyyar, 5773',1,-1,-1,'24',3,'2013',0,'',0],
['Pesach Sheni',1,-1,-1,'24',3,'2013',0,'Second Passover, one month after Passover',0],
['29th day of the Omer',1,-1,-1,'24',3,'2013',0,'',0],
['15th of Iyyar, 5773',1,-1,-1,'25',3,'2013',0,'',0],
['30th day of the Omer',1,-1,-1,'25',3,'2013',0,'',0],
['16th of Iyyar, 5773',1,-1,-1,'26',3,'2013',0,'',0],
['31st day of the Omer',1,-1,-1,'26',3,'2013',0,'',0],
['Candle lighting',0,'35',19,'26',3,'2013',18,'',0],
['17th of Iyyar, 5773',1,-1,-1,'27',3,'2013',0,'',0],
['Parashat Emor',1,-1,-1,'27',3,'2013',0,'',0],
['32nd day of the Omer',1,-1,-1,27,3,'2013',0,'',0],
['Havdalah (42 min)',0,'36',20,27,3,'2013',1,'',0],
['18th of Iyyar, 5773',1,-1,-1,'28',3,'2013',0,'',0],
['Lag B\'Omer',1,-1,-1,'28',3,'2013',0,'33rd day of counting the Omer',0],
['33rd day of the Omer',1,-1,-1,'28',3,'2013',0,'',0],
['19th of Iyyar, 5773',1,-1,-1,'29',3,'2013',0,'',0],
['34th day of the Omer',1,-1,-1,'29',3,'2013',0,'',0],
['20th of Iyyar, 5773',1,-1,-1,'30',3,'2013',0,'',0],
['35th day of the Omer',1,-1,-1,'30',3,'2013',0,'',0],
['21st of Iyyar, 5773',1,-1,-1,'1',4,'2013',0,'',0],
['36th day of the Omer',1,-1,-1,'1',4,'2013',0,'',0],
['22nd of Iyyar, 5773',1,-1,-1,'2',4,'2013',0,'',0],
['37th day of the Omer',1,-1,-1,'2',4,'2013',0,'',0],
['23rd of Iyyar, 5773',1,-1,-1,'3',4,'2013',0,'',0],
['38th day of the Omer',1,-1,-1,'3',4,'2013',0,'',0],
['Candle lighting',0,'42',19,'3',4,'2013',18,'',0],
['24th of Iyyar, 5773',1,-1,-1,'4',4,'2013',0,'',0],
['Parashat Behar-Bechukotai',1,-1,-1,'4',4,'2013',0,'',0],
['39th day of the Omer',1,-1,-1,4,4,'2013',0,'',0],
['Havdalah (42 min)',0,'42',20,4,4,'2013',1,'',0],
['25th of Iyyar, 5773',1,-1,-1,'5',4,'2013',0,'',0],
['40th day of the Omer',1,-1,-1,'5',4,'2013',0,'',0],
['26th of Iyyar, 5773',1,-1,-1,'6',4,'2013',0,'',0],
['41st day of the Omer',1,-1,-1,'6',4,'2013',0,'',0],
['27th of Iyyar, 5773',1,-1,-1,'7',4,'2013',0,'',0],
['42nd day of the Omer',1,-1,-1,'7',4,'2013',0,'',0],
['28th of Iyyar, 5773',1,-1,-1,'8',4,'2013',0,'',0],
['Yom Yerushalayim',1,-1,-1,'8',4,'2013',0,'Jerusalem Day',0],
['43rd day of the Omer',1,-1,-1,'8',4,'2013',0,'',0],
['29th of Iyyar, 5773',1,-1,-1,'9',4,'2013',0,'',0],
['44th day of the Omer',1,-1,-1,'9',4,'2013',0,'',0],
['1st of Sivan, 5773',1,-1,-1,'10',4,'2013',0,'',0],
['Rosh Chodesh Sivan',1,-1,-1,'10',4,'2013',0,'Beginning of new Hebrew month of Sivan',0],
['45th day of the Omer',1,-1,-1,'10',4,'2013',0,'',0],
['Candle lighting',0,'48',19,'10',4,'2013',18,'',0],
['2nd of Sivan, 5773',1,-1,-1,'11',4,'2013',0,'',0],
['Parashat Bamidbar',1,-1,-1,'11',4,'2013',0,'',0],
['46th day of the Omer',1,-1,-1,11,4,'2013',0,'',0],
['Havdalah (42 min)',0,'49',20,11,4,'2013',1,'',0],
['3rd of Sivan, 5773',1,-1,-1,'12',4,'2013',0,'',0],
['47th day of the Omer',1,-1,-1,'12',4,'2013',0,'',0],
['4th of Sivan, 5773',1,-1,-1,'13',4,'2013',0,'',0],
['48th day of the Omer',1,-1,-1,'13',4,'2013',0,'',0],
['5th of Sivan, 5773',1,-1,-1,'14',4,'2013',0,'',0],
['Erev Shavuot',1,-1,-1,'14',4,'2013',0,'Festival of Weeks, commemorates the giving of the Torah at Mount Sinai',0],
['49th day of the Omer',1,-1,-1,'14',4,'2013',0,'',0],
['Candle lighting',0,'51',19,'14',4,'2013',18,'',0],
['6th of Sivan, 5773',1,-1,-1,'15',4,'2013',0,'',0],
['Shavuot I',1,-1,-1,'15',4,'2013',0,'Festival of Weeks, commemorates the giving of the Torah at Mount Sinai',1],
['7th of Sivan, 5773',1,-1,-1,'16',4,'2013',0,'',0],
['Shavuot II',1,-1,-1,16,4,'2013',0,'Festival of Weeks, commemorates the giving of the Torah at Mount Sinai',1],
['Havdalah (42 min)',0,'53',20,16,4,'2013',1,'',0],
['8th of Sivan, 5773',1,-1,-1,'17',4,'2013',0,'',0],
['Candle lighting',0,'54',19,'17',4,'2013',18,'',0],
['9th of Sivan, 5773',1,-1,-1,'18',4,'2013',0,'',0],
['Parashat Nasso',1,-1,-1,18,4,'2013',0,'',0],
['Havdalah (42 min)',0,'55',20,18,4,'2013',1,'',0],
['15th of Sivan, 5773',1,-1,-1,'24',4,'2013',0,'',0],
['Candle lighting',0,'00',20,'24',4,'2013',18,'',0],
['16th of Sivan, 5773',1,-1,-1,'25',4,'2013',0,'',0],
['Parashat Beha\'alotcha',1,-1,-1,25,4,'2013',0,'',0],
['Havdalah (42 min)',0,'00',21,25,4,'2013',1,'',0],
['22nd of Sivan, 5773',1,-1,-1,'31',4,'2013',0,'',0],
['Candle lighting',0,'05',20,'31',4,'2013',18,'',0],
['23rd of Sivan, 5773',1,-1,-1,'1',5,'2013',0,'',0],
['Parashat Sh\'lach',1,-1,-1,1,5,'2013',0,'',0],
['Havdalah (42 min)',0,'05',21,1,5,'2013',1,'',0],
['29th of Sivan, 5773',1,-1,-1,'7',5,'2013',0,'',0],
['Candle lighting',0,'09',20,'7',5,'2013',18,'',0],
['30th of Sivan, 5773',1,-1,-1,'8',5,'2013',0,'',0],
['Parashat Korach',1,-1,-1,'8',5,'2013',0,'',0],
['Rosh Chodesh Tamuz',1,-1,-1,8,5,'2013',0,'Beginning of new Hebrew month of Tamuz',0],
['Havdalah (42 min)',0,'10',21,8,5,'2013',1,'',0],
['1st of Tamuz, 5773',1,-1,-1,'9',5,'2013',0,'',0],
['Rosh Chodesh Tamuz',1,-1,-1,'9',5,'2013',0,'Beginning of new Hebrew month of Tamuz',0],
['6th of Tamuz, 5773',1,-1,-1,'14',5,'2013',0,'',0],
['Candle lighting',0,'12',20,'14',5,'2013',18,'',0],
['7th of Tamuz, 5773',1,-1,-1,'15',5,'2013',0,'',0],
['Parashat Chukat',1,-1,-1,15,5,'2013',0,'',0],
['Havdalah (42 min)',0,'13',21,15,5,'2013',1,'',0],
['13th of Tamuz, 5773',1,-1,-1,'21',5,'2013',0,'',0],
['Candle lighting',0,'15',20,'21',5,'2013',18,'',0],
['14th of Tamuz, 5773',1,-1,-1,'22',5,'2013',0,'',0],
['Parashat Balak',1,-1,-1,22,5,'2013',0,'',0],
['Havdalah (42 min)',0,'15',21,22,5,'2013',1,'',0],
['17th of Tamuz, 5773',1,-1,-1,'25',5,'2013',0,'',0],
['Tzom Tammuz',1,-1,-1,'25',5,'2013',0,'Fast commemorating breaching of the walls of Jerusalem by Nebuchadnezzar',0],
['20th of Tamuz, 5773',1,-1,-1,'28',5,'2013',0,'',0],
['Candle lighting',0,'16',20,'28',5,'2013',18,'',0],
['21st of Tamuz, 5773',1,-1,-1,'29',5,'2013',0,'',0],
['Parashat Pinchas',1,-1,-1,29,5,'2013',0,'',0],
['Havdalah (42 min)',0,'16',21,29,5,'2013',1,'',0],
['27th of Tamuz, 5773',1,-1,-1,'5',6,'2013',0,'',0],
['Candle lighting',0,'15',20,'5',6,'2013',18,'',0],
['28th of Tamuz, 5773',1,-1,-1,'6',6,'2013',0,'',0],
['Parashat Matot-Masei',1,-1,-1,6,6,'2013',0,'',0],
['Havdalah (42 min)',0,'15',21,6,6,'2013',1,'',0],
['1st of Av, 5773',1,-1,-1,'8',6,'2013',0,'',0],
['Rosh Chodesh Av',1,-1,-1,'8',6,'2013',0,'Beginning of new Hebrew month of Av',0],
['5th of Av, 5773',1,-1,-1,'12',6,'2013',0,'',0],
['Candle lighting',0,'13',20,'12',6,'2013',18,'',0],
['6th of Av, 5773',1,-1,-1,'13',6,'2013',0,'',0],
['Parashat Devarim',1,-1,-1,'13',6,'2013',0,'',0],
['Shabbat Chazon',1,-1,-1,13,6,'2013',0,'Shabbat before Tish\'a B\'Av (Shabbat of Prophecy/Shabbat of Vision)',0],
['Havdalah (42 min)',0,'12',21,13,6,'2013',1,'',0],
['8th of Av, 5773',1,-1,-1,'15',6,'2013',0,'',0],
['Erev Tish\'a B\'Av',1,-1,-1,'15',6,'2013',0,'The Ninth of Av, fast commemorating the destruction of the two Temples',0],
['9th of Av, 5773',1,-1,-1,'16',6,'2013',0,'',0],
['Tish\'a B\'Av',1,-1,-1,'16',6,'2013',0,'The Ninth of Av, fast commemorating the destruction of the two Temples',0],
['12th of Av, 5773',1,-1,-1,'19',6,'2013',0,'',0],
['Candle lighting',0,'09',20,'19',6,'2013',18,'',0],
['13th of Av, 5773',1,-1,-1,'20',6,'2013',0,'',0],
['Parashat Vaetchanan',1,-1,-1,'20',6,'2013',0,'',0],
['Shabbat Nachamu',1,-1,-1,20,6,'2013',0,'Shabbat after Tish\'a B\'Av (Shabbat of Consolation)',0],
['Havdalah (42 min)',0,'09',21,20,6,'2013',1,'',0],
['19th of Av, 5773',1,-1,-1,'26',6,'2013',0,'',0],
['Candle lighting',0,'04',20,'26',6,'2013',18,'',0],
['20th of Av, 5773',1,-1,-1,'27',6,'2013',0,'',0],
['Parashat Eikev',1,-1,-1,27,6,'2013',0,'',0],
['Havdalah (42 min)',0,'04',21,27,6,'2013',1,'',0],
['26th of Av, 5773',1,-1,-1,'2',7,'2013',0,'',0],
['Candle lighting',0,'58',19,'2',7,'2013',18,'',0],
['27th of Av, 5773',1,-1,-1,'3',7,'2013',0,'',0],
['Parashat Re\'eh',1,-1,-1,3,7,'2013',0,'',0],
['Havdalah (42 min)',0,'57',20,3,7,'2013',1,'',0],
['30th of Av, 5773',1,-1,-1,'6',7,'2013',0,'',0],
['Rosh Chodesh Elul',1,-1,-1,'6',7,'2013',0,'Beginning of new Hebrew month of Elul',0],
['1st of Elul, 5773',1,-1,-1,'7',7,'2013',0,'',0],
['Rosh Chodesh Elul',1,-1,-1,'7',7,'2013',0,'Beginning of new Hebrew month of Elul',0],
['3rd of Elul, 5773',1,-1,-1,'9',7,'2013',0,'',0],
['Candle lighting',0,'51',19,'9',7,'2013',18,'',0],
['4th of Elul, 5773',1,-1,-1,'10',7,'2013',0,'',0],
['Parashat Shoftim',1,-1,-1,10,7,'2013',0,'',0],
['Havdalah (42 min)',0,'50',20,10,7,'2013',1,'',0],
['10th of Elul, 5773',1,-1,-1,'16',7,'2013',0,'',0],
['Candle lighting',0,'42',19,'16',7,'2013',18,'',0],
['11th of Elul, 5773',1,-1,-1,'17',7,'2013',0,'',0],
['Parashat Ki Teitzei',1,-1,-1,17,7,'2013',0,'',0],
['Havdalah (42 min)',0,'41',20,17,7,'2013',1,'',0],
['17th of Elul, 5773',1,-1,-1,'23',7,'2013',0,'',0],
['Candle lighting',0,'33',19,'23',7,'2013',18,'',0],
['18th of Elul, 5773',1,-1,-1,'24',7,'2013',0,'',0],
['Parashat Ki Tavo',1,-1,-1,24,7,'2013',0,'',0],
['Havdalah (42 min)',0,'32',20,24,7,'2013',1,'',0],
['24th of Elul, 5773',1,-1,-1,'30',7,'2013',0,'',0],
['Candle lighting',0,'23',19,'30',7,'2013',18,'',0],
['25th of Elul, 5773',1,-1,-1,'31',7,'2013',0,'',0],
['Parashat Nitzavim-Vayeilech',1,-1,-1,31,7,'2013',0,'',0],
['Havdalah (42 min)',0,'22',20,31,7,'2013',1,'',0],
['29th of Elul, 5773',1,-1,-1,'4',8,'2013',0,'',0],
['Erev Rosh Hashana',1,-1,-1,'4',8,'2013',0,'The Jewish New Year',0],
['Candle lighting',0,'16',19,'4',8,'2013',18,'',0],
['1st of Tishrei, 5774',1,-1,-1,'5',8,'2013',0,'',0],
['Rosh Hashana 5774',1,-1,-1,'5',8,'2013',0,'The Jewish New Year',1],
['2nd of Tishrei, 5774',1,-1,-1,'6',8,'2013',0,'',0],
['Rosh Hashana II',1,-1,-1,'6',8,'2013',0,'The Jewish New Year',1],
['Candle lighting',0,'13',19,'6',8,'2013',18,'',0],
['3rd of Tishrei, 5774',1,-1,-1,'7',8,'2013',0,'',0],
['Parashat Ha\'Azinu',1,-1,-1,'7',8,'2013',0,'',0],
['Shabbat Shuva',1,-1,-1,7,8,'2013',0,'Shabbat that falls between Rosh Hashanah and Yom Kippur (Shabbat of Returning)',0],
['Havdalah (42 min)',0,'12',20,7,8,'2013',1,'',0],
['4th of Tishrei, 5774',1,-1,-1,'8',8,'2013',0,'',0],
['Tzom Gedaliah',1,-1,-1,'8',8,'2013',0,'Fast of the Seventh Month, commemorates the assassination of the Jewish governor of Judah',0],
['9th of Tishrei, 5774',1,-1,-1,'13',8,'2013',0,'',0],
['Erev Yom Kippur',1,-1,-1,'13',8,'2013',0,'Day of Atonement',0],
['Candle lighting',0,'02',19,'13',8,'2013',18,'',0],
['10th of Tishrei, 5774',1,-1,-1,'14',8,'2013',0,'',0],
['Yom Kippur',1,-1,-1,14,8,'2013',0,'Day of Atonement',1],
['Havdalah (42 min)',0,'01',20,14,8,'2013',1,'',0],
['14th of Tishrei, 5774',1,-1,-1,'18',8,'2013',0,'',0],
['Erev Sukkot',1,-1,-1,'18',8,'2013',0,'Feast of Tabernacles',0],
['Candle lighting',0,'55',18,'18',8,'2013',18,'',0],
['15th of Tishrei, 5774',1,-1,-1,'19',8,'2013',0,'',0],
['Sukkot I',1,-1,-1,'19',8,'2013',0,'Feast of Tabernacles',1],
['16th of Tishrei, 5774',1,-1,-1,'20',8,'2013',0,'',0],
['Sukkot II',1,-1,-1,'20',8,'2013',0,'Feast of Tabernacles',1],
['Candle lighting',0,'52',18,'20',8,'2013',18,'',0],
['17th of Tishrei, 5774',1,-1,-1,'21',8,'2013',0,'',0],
['Sukkot III (CH\'\'M)',1,-1,-1,21,8,'2013',0,'Feast of Tabernacles',0],
['Havdalah (42 min)',0,'50',19,21,8,'2013',1,'',0],
['18th of Tishrei, 5774',1,-1,-1,'22',8,'2013',0,'',0],
['Sukkot IV (CH\'\'M)',1,-1,-1,'22',8,'2013',0,'Feast of Tabernacles',0],
['19th of Tishrei, 5774',1,-1,-1,'23',8,'2013',0,'',0],
['Sukkot V (CH\'\'M)',1,-1,-1,'23',8,'2013',0,'Feast of Tabernacles',0],
['20th of Tishrei, 5774',1,-1,-1,'24',8,'2013',0,'',0],
['Sukkot VI (CH\'\'M)',1,-1,-1,'24',8,'2013',0,'Feast of Tabernacles',0],
['21st of Tishrei, 5774',1,-1,-1,'25',8,'2013',0,'',0],
['Sukkot VII (Hoshana Raba)',1,-1,-1,'25',8,'2013',0,'Feast of Tabernacles',0],
['Candle lighting',0,'44',18,'25',8,'2013',18,'',0],
['22nd of Tishrei, 5774',1,-1,-1,'26',8,'2013',0,'',0],
['Shmini Atzeret',1,-1,-1,'26',8,'2013',0,'Eighth Day of Assembly',1],
['23rd of Tishrei, 5774',1,-1,-1,'27',8,'2013',0,'',0],
['Simchat Torah',1,-1,-1,'27',8,'2013',0,'Day of Celebrating the Torah',1],
['Candle lighting',0,'41',18,'27',8,'2013',18,'',0],
['24th of Tishrei, 5774',1,-1,-1,'28',8,'2013',0,'',0],
['Parashat Bereshit',1,-1,-1,28,8,'2013',0,'',0],
['Havdalah (42 min)',0,'39',19,28,8,'2013',1,'',0],
['30th of Tishrei, 5774',1,-1,-1,'4',9,'2013',0,'',0],
['Rosh Chodesh Cheshvan',1,-1,-1,'4',9,'2013',0,'Beginning of new Hebrew month of Cheshvan',0],
['Candle lighting',0,'30',18,'4',9,'2013',18,'',0],
['1st of Cheshvan, 5774',1,-1,-1,'5',9,'2013',0,'',0],
['Parashat Noach',1,-1,-1,'5',9,'2013',0,'',0],
['Rosh Chodesh Cheshvan',1,-1,-1,5,9,'2013',0,'Beginning of new Hebrew month of Cheshvan',0],
['Havdalah (42 min)',0,'29',19,5,9,'2013',1,'',0],
['7th of Cheshvan, 5774',1,-1,-1,'11',9,'2013',0,'',0],
['Candle lighting',0,'20',18,'11',9,'2013',18,'',0],
['8th of Cheshvan, 5774',1,-1,-1,'12',9,'2013',0,'',0],
['Parashat Lech-Lecha',1,-1,-1,12,9,'2013',0,'',0],
['Havdalah (42 min)',0,'18',19,12,9,'2013',1,'',0],
['14th of Cheshvan, 5774',1,-1,-1,'18',9,'2013',0,'',0],
['Candle lighting',0,'10',18,'18',9,'2013',18,'',0],
['15th of Cheshvan, 5774',1,-1,-1,'19',9,'2013',0,'',0],
['Parashat Vayera',1,-1,-1,19,9,'2013',0,'',0],
['Havdalah (42 min)',0,'09',19,19,9,'2013',1,'',0],
['21st of Cheshvan, 5774',1,-1,-1,'25',9,'2013',0,'',0],
['Candle lighting',0,'01',18,'25',9,'2013',18,'',0],
['22nd of Cheshvan, 5774',1,-1,-1,'26',9,'2013',0,'',0],
['Parashat Chayei Sara',1,-1,-1,26,9,'2013',0,'',0],
['Havdalah (42 min)',0,'00',19,26,9,'2013',1,'',0],
['28th of Cheshvan, 5774',1,-1,-1,'1',10,'2013',0,'',0],
['Candle lighting',0,'53',17,'1',10,'2013',18,'',0],
['29th of Cheshvan, 5774',1,-1,-1,'2',10,'2013',0,'',0],
['Parashat Toldot',1,-1,-1,2,10,'2013',0,'',0],
['Havdalah (42 min)',0,'52',18,2,10,'2013',1,'',0],
['30th of Cheshvan, 5774',1,-1,-1,'3',10,'2013',0,'',0],
['Rosh Chodesh Kislev',1,-1,-1,'3',10,'2013',0,'Beginning of new Hebrew month of Kislev',0],
['1st of Kislev, 5774',1,-1,-1,'4',10,'2013',0,'',0],
['Rosh Chodesh Kislev',1,-1,-1,'4',10,'2013',0,'Beginning of new Hebrew month of Kislev',0],
['5th of Kislev, 5774',1,-1,-1,'8',10,'2013',0,'',0],
['Candle lighting',0,'46',16,'8',10,'2013',18,'',0],
['6th of Kislev, 5774',1,-1,-1,'9',10,'2013',0,'',0],
['Parashat Vayetzei',1,-1,-1,9,10,'2013',0,'',0],
['Havdalah (42 min)',0,'45',17,9,10,'2013',1,'',0],
['12th of Kislev, 5774',1,-1,-1,'15',10,'2013',0,'',0],
['Candle lighting',0,'40',16,'15',10,'2013',18,'',0],
['13th of Kislev, 5774',1,-1,-1,'16',10,'2013',0,'',0],
['Parashat Vayishlach',1,-1,-1,16,10,'2013',0,'',0],
['Havdalah (42 min)',0,'40',17,16,10,'2013',1,'',0],
['19th of Kislev, 5774',1,-1,-1,'22',10,'2013',0,'',0],
['Candle lighting',0,'36',16,'22',10,'2013',18,'',0],
['20th of Kislev, 5774',1,-1,-1,'23',10,'2013',0,'',0],
['Parashat Vayeshev',1,-1,-1,23,10,'2013',0,'',0],
['Havdalah (42 min)',0,'36',17,23,10,'2013',1,'',0],
['24th of Kislev, 5774',1,-1,-1,'27',10,'2013',0,'',0],
['Chanukah: 1 Candle',1,-1,-1,'27',10,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['25th of Kislev, 5774',1,-1,-1,'28',10,'2013',0,'',0],
['Chanukah: 2 Candles',1,-1,-1,'28',10,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['26th of Kislev, 5774',1,-1,-1,'29',10,'2013',0,'',0],
['Chanukah: 3 Candles',1,-1,-1,'29',10,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['Candle lighting',0,'33',16,'29',10,'2013',18,'',0],
['27th of Kislev, 5774',1,-1,-1,'30',10,'2013',0,'',0],
['Parashat Miketz',1,-1,-1,'30',10,'2013',0,'',0],
['Chanukah: 4 Candles',1,-1,-1,30,10,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['Havdalah (42 min)',0,'33',17,30,10,'2013',1,'',0],
['28th of Kislev, 5774',1,-1,-1,'1',11,'2013',0,'',0],
['Chanukah: 5 Candles',1,-1,-1,'1',11,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['29th of Kislev, 5774',1,-1,-1,'2',11,'2013',0,'',0],
['Chanukah: 6 Candles',1,-1,-1,'2',11,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['30th of Kislev, 5774',1,-1,-1,'3',11,'2013',0,'',0],
['Rosh Chodesh Tevet',1,-1,-1,'3',11,'2013',0,'Beginning of new Hebrew month of Tevet',0],
['Chanukah: 7 Candles',1,-1,-1,'3',11,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['1st of Tevet, 5774',1,-1,-1,'4',11,'2013',0,'',0],
['Rosh Chodesh Tevet',1,-1,-1,'4',11,'2013',0,'Beginning of new Hebrew month of Tevet',0],
['Chanukah: 8 Candles',1,-1,-1,'4',11,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['2nd of Tevet, 5774',1,-1,-1,'5',11,'2013',0,'',0],
['Chanukah: 8th Day',1,-1,-1,'5',11,'2013',0,'The Jewish festival of rededication, also known as the Festival of Lights',0],
['3rd of Tevet, 5774',1,-1,-1,'6',11,'2013',0,'',0],
['Candle lighting',0,'32',16,'6',11,'2013',18,'',0],
['4th of Tevet, 5774',1,-1,-1,'7',11,'2013',0,'',0],
['Parashat Vayigash',1,-1,-1,7,11,'2013',0,'',0],
['Havdalah (42 min)',0,'32',17,7,11,'2013',1,'',0],
['10th of Tevet, 5774',1,-1,-1,'13',11,'2013',0,'',0],
['Asara B\'Tevet',1,-1,-1,'13',11,'2013',0,'Fast commemorating the siege of Jerusalem',0],
['Candle lighting',0,'33',16,'13',11,'2013',18,'',0],
['11th of Tevet, 5774',1,-1,-1,'14',11,'2013',0,'',0],
['Parashat Vayechi',1,-1,-1,14,11,'2013',0,'',0],
['Havdalah (42 min)',0,'33',17,14,11,'2013',1,'',0],
['17th of Tevet, 5774',1,-1,-1,'20',11,'2013',0,'',0],
['Candle lighting',0,'35',16,'20',11,'2013',18,'',0],
['18th of Tevet, 5774',1,-1,-1,'21',11,'2013',0,'',0],
['Parashat Shemot',1,-1,-1,21,11,'2013',0,'',0],
['Havdalah (42 min)',0,'36',17,21,11,'2013',1,'',0],
['24th of Tevet, 5774',1,-1,-1,'27',11,'2013',0,'',0],
['Candle lighting',0,'39',16,'27',11,'2013',18,'',0],
['25th of Tevet, 5774',1,-1,-1,'28',11,'2013',0,'',0],
['Parashat Vaera',1,-1,-1,28,11,'2013',0,'',0],
['Havdalah (42 min)',0,'40',17,28,11,'2013',1,'',0]);

return @aa;
}
