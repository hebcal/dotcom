# This package is derived from Danny Sadinoff's hebcal-perl-3.2.2, which
# is licensed under GPL. His original licensing notice follows:

# /*
#    Hebcal - A Jewish Calendar Generator
#    Copyright (C) 1994  Danny Sadinoff

#    This program is free software; you can redistribute it and/or
#    modify it under the terms of the GNU General Public License
#    as published by the Free Software Foundation; either version 2
#    of the License, or (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

#    Danny Sadinoff can be reached at hebcal@sadinoff.com
#  */

package HebcalGPL;

use strict;
use Date::Calc ();

our $NISAN = 1;
our $IYYAR = 2;
our $SIVAN = 3;
our $TAMUZ = 4;
our $AV = 5;
our $ELUL = 6;
our $TISHREI = 7;
our $CHESHVAN = 8;
our $KISLEV = 9;
our $TEVET = 10;
our $SHVAT = 11;
our $ADAR_I = 12;
our $ADAR_II = 13;

our @HEB_MONTH_NAME =
(
  [
    "VOID", "Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
    "Cheshvan", "Kislev", "Tevet", "Sh'vat", "Adar", "Nisan"
  ],
  [
    "VOID", "Nisan", "Iyyar", "Sivan", "Tamuz", "Av", "Elul", "Tishrei",
    "Cheshvan", "Kislev", "Tevet", "Sh'vat", "Adar I", "Adar II",
    "Nisan"
  ]
);

sub MONTHS_IN_HEB ($) {
    LEAP_YR_HEB($_[0]) ? 13 :12;
}

sub LEAP_YR_HEB ($) {
    (1 + ($_[0] * 7)) % 19 < 7 ? 1 : 0;
}

sub max_days_in_heb_month ($$) {
    my($month,$year) = @_;

    if ($month == $IYYAR || $month == $TAMUZ ||
	$month == $ELUL || $month == $TEVET ||
	$month == $ADAR_II ||
	($month == $ADAR_I && !LEAP_YR_HEB($year)) ||
	($month == $CHESHVAN && !long_cheshvan($year)) ||
	($month == $KISLEV && short_kislev($year)))
    {
	return 29;
    }
    else
    {
	return 30;
    }
}


sub greg2hebrew ($$$) {
    my($gregy,$gregm,$gregd) = @_;

    my $d = Date::Calc::Date_to_Days($gregy,$gregm,$gregd);
    my @mmap = (9,10,11,12,1,2,3,4,7,7,7,8);

    my $month = $mmap[$gregm - 1];
    my $year = 3760 + $gregy;

    my $hebdate = {dd => 1, mm => 7, yy => $year + 1};
    while ($d >= hebrew2abs($hebdate)) {
	$year++;
	$hebdate->{yy} = $year + 1,
    }

    while ($hebdate->{mm} = $month,
	   $hebdate->{dd} = max_days_in_heb_month($month,$year),
	   $hebdate->{yy} = $year,
	   $d > hebrew2abs($hebdate)) {
	$month = ($month % MONTHS_IN_HEB($year)) + 1;
    }

    $hebdate->{dd} = 1;

    my $day = int($d - hebrew2abs($hebdate) + 1);
    $hebdate->{dd} = $day;

    return $hebdate;
}

sub abs2hebrew( $ ){
   my $d = shift;
   my @mmap = (9, 10, 11, 12, 1, 2, 3, 4, 7, 7, 7, 8);
   my $hebdate = {};

   my $gregdate = abs2greg($d);
   $hebdate->{dd} = 1;
   $hebdate->{mm} = 7;
   my $month = $mmap[$gregdate->{mm} - 1];
   my $year = 3760 + $gregdate->{yy};

   $hebdate->{yy} = $year + 1;
   while ( $d >= hebrew2abs($hebdate)){
     $year++;
     $hebdate->{yy} = $year + 1,
  }

  while ($hebdate->{mm} = $month,
	 $hebdate->{dd} = max_days_in_heb_month ($month,$year),
	 $hebdate->{yy} = $year,
	 $d > hebrew2abs ($hebdate)){
     $month = ($month % MONTHS_IN_HEB ($year)) + 1;
  }

  $hebdate->{dd} = 1;

  my $day = int($d - hebrew2abs($hebdate) + 1);
  $hebdate->{dd} = $day;

  return $hebdate;
}



# Days from sunday prior to start of hebrew calendar to mean
# conjunction of tishrei in hebrew YEAR 
#  
sub hebrew_elapsed_days ($) {
    my $year = shift;

    my $yearl = $year;
    my $m_elapsed = (235 * int(($yearl - 1) / 19) +
		     12 * (($yearl - 1) % 19) +
		     int((((($yearl - 1) % 19) * 7) + 1) / 19));
    
    my $p_elapsed = 204 + (793 * ($m_elapsed % 1080));
    
    my $h_elapsed = (5 + (12 * $m_elapsed) +
		     793 * int ($m_elapsed / 1080) +
		     int($p_elapsed / 1080));
    
    my $parts = ($p_elapsed % 1080) + 1080 * ($h_elapsed % 24);
    
    my $day = 1 + 29 * $m_elapsed + int($h_elapsed / 24);
    my $alt_day;

    if (($parts >= 19440) ||
	((2 == ($day % 7)) && ($parts >= 9924) && !(LEAP_YR_HEB($year))) ||
	((1 == ($day % 7)) && ($parts >= 16789) && LEAP_YR_HEB($year - 1))) {
	$alt_day = $day + 1;}
    else{
	$alt_day = $day;}
    
    if (($alt_day % 7) == 0 ||
	($alt_day % 7) == 3 ||
	($alt_day % 7) == 5) {
	return $alt_day + 1;
    }
    else{
	return $alt_day;
    }
}


# convert hebrew date to absolute date 
# Absolute date of Hebrew DATE.
#    The absolute date is the number of days elapsed since the (imaginary)
#    Gregorian date Sunday, December 31, 1 BC. 
sub hebrew2abs ($) {
    my $d = shift;
    my $m;
    my $tempabs = $d->{dd};

    # FIX: These loops want to be optimized with table-lookup
    if ($d->{mm} < $TISHREI) {
	for ($m = $TISHREI; $m <= MONTHS_IN_HEB($d->{yy}); $m++) {
	    $tempabs +=  max_days_in_heb_month($m, $d->{yy});
	}
	
	for ($m = $NISAN; $m < $d->{mm}; $m++) {
	    $tempabs +=  max_days_in_heb_month($m, $d->{yy});
	}
    }
    else {
	for ($m = $TISHREI; $m < $d->{mm}; $m++) {
	    $tempabs +=  max_days_in_heb_month($m, $d->{yy});
	}
    }
    my $days = hebrew_elapsed_days($d->{yy}) - 1373429 + $tempabs;
#    croak Dumper($d)if $days < 0;
    return $days;
}

# Number of days in the hebrew YEAR 
sub days_in_heb_year ($) {
    my $year = shift;
    return hebrew_elapsed_days($year + 1) - hebrew_elapsed_days($year);
}

# true if Cheshvan is long in hebrew YEAR 
sub long_cheshvan ($) {
    (days_in_heb_year($_[0]) % 10) == 5;
}

# true if Cheshvan is long in hebrew YEAR 
sub short_kislev ($) {
    (days_in_heb_year($_[0]) % 10) == 3;
}



########################################################################

my $MonthLengths= [
		   [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31],
		   [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
		  ];


sub LEAP( $ ){
#    my $yr = shift;
   return (( 0 == $_[0] % 4) 
	   && ( (0 != $_[0] % 100) 
		|| (0 == $_[0] % 400)));
}
sub DAYS_IN( $ ){
   LEAP( $_[0] ) ? 366 : 365;
}

sub DAYS_IN_MONTH( $$ ){
   my ($month, $year) = @_;
   return $MonthLengths->[LEAP ($year)+0][$month]   
}


# /*
#  *Return the day number within the year of the date DATE.
#  *For example, dayOfYear({1,1,1987}) returns the value 1
#  *while dayOfYear({12,31,1980}) returns 366.
#  
#int 
sub dayOfYear( $ ) {
   my $d = shift;
   my $dOY = $d->{dd} + 31 * ($d->{mm} - 1);
   if ($d->{mm} > 2) {
      $dOY -= int((4 * $d->{mm} + 23) / 10);
      if (LEAP( $d->{yy} )){
	 $dOY++;
      }
   }
   return $dOY;
}


# /*
#  * The number of days elapsed between the Gregorian date 12/31/1 BC and DATE.
#  * The Gregorian date Sunday, December 31, 1 BC is imaginary.
#  
sub greg2abs( $ )#			/* "absolute date" 
{
 my $d = shift;
 return ( dayOfYear($d)	#/* days this year 
	  + 365 *  ($d->{yy} - 1)#	/* + days in prior years 
	  +  int(($d->{yy} - 1) / 4)#	/* + Julian Leap years 
	  -  int(($d->{yy} - 1) / 100)#	/* - century years 
	  +  int(($d->{yy} - 1) / 400));#	/* + Gregorian leap years 
}
# /*
#  * See the footnote on page 384 of ``Calendrical Calculations, Part II:
#  * Three Historical Calendars'' by E. M. Reingold,  N. Dershowitz, and S. M.
#  * Clamen, Software--Practice and Experience, Volume 23, Number 4
#  * (April, 1993), pages 383-404 for an explanation.
#  

sub abs2greg ($)
{
   my $theDate = shift;
#     day, year, month, mlen;
#    date_t d;
#    long int d0, n400, d1, n100, d2, n4, d3, n1;
   
   my $d0 = $theDate - 1;
   my $n400 = int($d0 / 146097);
   my $d1 = $d0 % 146097;
   my $n100 = int($d1 / 36524);
   my $d2 = $d1 % 36524;
   my $n4 = int ($d2 / 1461);
   my $d3 = $d2 % 1461;
   my $n1 = int ($d3 / 365);

   my $day =  ($d3 % 365) + 1;
   my $year =  (400 * $n400 + 100 * $n100 + 4 * $n4 + $n1);
   
   my $d = {};
   if (4 == $n100 || 4 == $n1) {
      $d->{mm} = 12;
      $d->{dd} = 31;
      $d->{yy} = $year;
      return $d;
   }
   else {
      $year++;
      my $month = 1;
      my $mlen;

      while (($mlen = $MonthLengths->[LEAP ($year)+0][$month]) < $day) {
	 $day -= $mlen;
	 $month++;
      }
      $d->{yy} = $year;
      $d->{mm} = $month;
      $d->{dd} = $day;
      return $d;
   }
}

sub numSuffix($ ){
   my $num = shift;
   if ( $num >9 && $num <20 ){
      return 'th';
   }
   my $rem = $num %10;
   $rem == 1 and return 'st';
   $rem == 2 and return 'nd';
   $rem == 3 and return 'rd';
   return 'th';
}

1;
