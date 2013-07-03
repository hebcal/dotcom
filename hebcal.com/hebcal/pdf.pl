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
#$font{'plain'} = $pdf->corefont('Helvetica', -encoding => 'latin1');
#$font{'bold'} = $pdf->corefont('Helvetica-Bold', -encoding => 'latin1');
$font{'plain'} = $pdf->ttfont('/Users/mradwin/Desktop/SourceSansPro_FontsOnly-1.050/TTF/SourceSansPro-Regular.ttf');
$font{'bold'} = $pdf->ttfont('/Users/mradwin/Desktop/SourceSansPro_FontsOnly-1.050/TTF/SourceSansPro-Bold.ttf');
$font{'hebrew'} = $pdf->ttfont('/Users/mradwin/Downloads/SBL_Hbrw.ttf');

my @DAYS = qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday);
my $year = 2013;
foreach my $month (1 .. 12) {
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
    $text->font($font{'bold'}, 36); # Assign a font to the Text object
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
            
#	    my $textx = $x + $colwidth - 4;#
#	    $text->translate($textx, $y-12);
#	    $text->font($font{'plain'}, 12);
#	    $text->text_right("c$c r$r");
	}
    }

    # render month numbers
    $text->font($font{'plain'}, 12);
    my $xpos = LMARGIN + $colwidth - 4;
    $xpos += ($dow * $colwidth);
    my $ypos = HEIGHT - TMARGIN - 12; # start at row 0, then subtract $rowheight from $ypos
    for (my $i = 1; $i <= $daysinmonth; $i++) {
	$text->translate($xpos, $ypos);
	$text->text_right($i);

	if ($i == 13) {
	    $text->font($font{'plain'}, 9);
	    $text->translate($xpos - $colwidth + 8, $ypos - 12);
	    $text->text("Hello, world!");
	    $text->font($font{'plain'}, 12);
	}

	$xpos += $colwidth;
	if (++$dow == 7) {
	    $dow = 0;
	    $xpos = LMARGIN + $colwidth - 4;
	    $ypos -= $rowheight;
	}
    }

    $text->translate(WIDTH - RMARGIN, BMARGIN - 12);
    $text->font($font{'hebrew'}, 8);
    $text->text_right("Copyright (c) ט״ז בְּתָּמוּז תשע״ג Hebcal.com - Licensed under a Creative Commons Attribution 3.0 License");
}

$pdf->save;
$pdf->end();

