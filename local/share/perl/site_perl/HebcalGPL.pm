# This package is derived from Danny Sadinoff's hebcal-perl-3.2.2, which
# is licensed under GPL. His original licensing notice follows:

# #
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

#    Danny Sadinoff can be reached at 
#    1 Cove La.
#    Great Neck, NY
#    11024

#    sadinoff@pobox.com 
#  */

package HebcalGPL;

my $NISAN = 1;
my $IYYAR = 2;
my $SIVAN = 3;
my $TAMUZ = 4;
my $AV = 5;
my $ELUL = 6;
my $TISHREI = 7;
my $CHESHVAN = 8;
my $KISLEV = 9;
my $TEVET = 10;
my $SHVAT = 11;
my $ADAR_I = 12;
my $ADAR_II = 13;

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

1;
