#!/usr/local/bin/perl5 -w

# $Id$

use DB_File;
use strict;
use Hebcal;

my(%DB);
my($dbmfile) = '/home/web/hebcal.com/docs/hebcal/zips.db';
tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
    || die "Can't tie $dbmfile: $!\n";
die unless defined $DB{"95051"};

my($apache_date);
if (defined $ARGV[0])
{
    $apache_date = $ARGV[0];
}
else
{
    my($yesterday) = time - (60 * 60 * 24);

    my(undef,undef,undef,$mday,$mon,$year,undef,undef,undef) =
	localtime($yesterday);

    my(@MoY) = ('Jan','Feb','Mar','Apr','May','Jun',
		'Jul','Aug','Sep','Oct','Nov','Dec');

    $apache_date = sprintf("%02d/%s/%4d", $mday, $MoY[$mon], $year + 1900);
}

my($home) = my($faq) = my($holidays) = my($doc_other) = my($queries) =
    my($candle) = my($zip) = my($city) = my($pos) = my($yhoo) =
    my($download) = my($dba) = my($csv) = 0;
my($unk_zip) = my($unk_tz) = 0;
my(%unk_zip) = ();
my(%unk_tz) = ();

while(<STDIN>)
{
    next unless m,\s+\[$apache_date,o;
    next if /^207\.55\.191\.4|www\.radwin\.org|smiles\.yahoo\.com|205\.216\.162\.253|198\.144\.204\.|198\.144\.193\.150/;

    $home++ if m,GET\s+/hebcal/\s+HTTP,;
    if (m,GET\s+/help/,)
    {
	if (m,GET\s+/help/\s+HTTP,)
	{
	    $faq++;
	}
	elsif (m,GET\s+/help/(defaults|holidays).html\s+HTTP,)
	{
	    $holidays++;
	}
	else
	{
	    $doc_other++;
	}
    }

    if (m,GET\s+/hebcal/index.html/.+\.(dba|csv), && /v=1/ && /dl=1/)
    {
	$download++;

	if (m,/index.html/.+\.dba,)
	{
	    $dba++;
	}
	else
	{
	    $csv++;
	}
    }
    elsif (m,GET\s+/hebcal/\?, && /v=1/)
    {
	$queries++;

	if (/\by=(on|1)\b/)
	{
	    $yhoo++;
	}

	if (/\bc=(on|1)\b/)
	{
	    $candle++;
	    if (/geo=city/)
	    {
		$city++;
	    }
	    elsif (/geo=pos/)
	    {
		$pos++;
	    }
	    elsif (/zip=(\d\d\d\d\d)/)
	    {
		my($zipcode) = $1;
		my($val) = $DB{$zipcode};
		$zip++;

		if (!defined $val) {
		    $unk_zip++;
		    $unk_zip{$zipcode}++;
		    $candle--;
		    $queries--;
		    $zip--;
		}
		else
		{
		    my(undef,$state) = split(/\0/, substr($val,6));
		    if (/=auto/)
		    {
			my($tz) = &Hebcal::guess_timezone('auto',
							  $zipcode,$state);
			unless (defined $tz)
			{
			    $unk_tz++;
			    $unk_tz{$zipcode}++;
			    $candle--;
			    $queries--;
			    $zip--;
			}
		    }
		}
	    }
	    else
	    {
		$candle--;
		$queries--;
	    }
	}
    }
}

printf "%4d home\n", $home;
printf "%4d faq\n", $faq;
printf "%4d holidays\n", $holidays;
printf "%4d doc_other\n", $doc_other;
printf "%4d queries\n", $queries;
printf "%4d download (%4d dba, %4d csv, %4d yhoo)\n",
    $download + $yhoo, $dba, $csv, $yhoo;
printf "%4d candle (%4d zip, %4d city, %4d pos)\n",
    $candle, $zip, $city, $pos;

if ($unk_zip + $unk_tz > 0) {
    printf "\n%4d zips unk, %4d timezone unk\n", $unk_zip, $unk_tz;

    foreach (sort keys %unk_zip) {
	printf "%s %4d\n", $_, $unk_zip{$_};
    }

    foreach (sort keys %unk_tz) {
	my($zip_city,$state) = split(/\0/, substr($DB{$_},6));
	printf "%s, %s %s (%d pv)\n", $zip_city, $state, $_, $unk_tz{$_};
    }
}
untie(%DB);
exit(0);
