#!/usr/bin/perl -w

########################################################################
#
# Copyright (c) 2011  Michael J. Radwin.
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

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use Hebcal ();
use Getopt::Long ();
use Log::Message::Simple qw[:STD :CARP];

my $Config = Config::Tiny->read($Hebcal::CONFIG_INI_PATH)
    or die "$Hebcal::CONFIG_INI_PATH: $!\n";

my $EMAIL_FROM = $Config->{_}->{"hebcal.email.facebook.from"};
my $EMAIL_TO = $Config->{_}->{"hebcal.email.facebook.to"};
my $EMAIL_CC = "michael\@radwin.org";
my $WEBDIR = "/home/hebcal/web/hebcal.com";
my $HEBCAL = "$WEBDIR/bin/hebcal";

my $opt_help;
my $opt_verbose = 0;
my $opt_shabbat;
my $opt_daily;
my $opt_randsleep;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "verbose|v" => \$opt_verbose,
     "daily" => \$opt_daily,
     "shabbat" => \$opt_shabbat,
     "randsleep=i" => \$opt_randsleep)) {
    usage();
}

$opt_help && usage();

my $email_subj;			# will be populated if there's an email to send

if ($opt_shabbat) {
  # get the date for this upcoming saturday
  my($sat_year,$sat_month,$sat_day) = Hebcal::upcoming_dow(6);
  msg("Shabbat is $sat_year,$sat_month,$sat_day", $opt_verbose);

  my @events = Hebcal::invoke_hebcal("$HEBCAL -s -x $sat_year", "", 0, $sat_month);
  my $parasha;
  my $special_shabbat;
  for my $evt (@events) {
    next unless $evt->[$Hebcal::EVT_IDX_MDAY] == $sat_day;
    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
    msg("Found $subj", $opt_verbose);
    if ($subj =~ /^Parashat/) {
	$parasha = $subj;
    } elsif ($subj =~ /^Shabbat/) {
	$special_shabbat = $subj;
    }
  }

  if ($parasha) {
    $email_subj = "This week's Torah portion is $parasha";
    if ($special_shabbat) {
	$email_subj .= " ($special_shabbat)";
    }
    $email_subj .= ". Shabbat Shalom!";
  }
}

if ($opt_daily) {
  my @events = Hebcal::invoke_hebcal("$HEBCAL", "", 0);
  my @today = Date::Calc::Today();
  my @tomorrow = Date::Calc::Add_Delta_Days(@today, 1);
  my $today_subj = "";
  for my $evt (@events) {
    my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
    if (event_date_matches($evt, @today)) {
      msg("Today is $subj", $opt_verbose);
      $today_subj = $subj;
      if ($subj =~ /^Erev (.+)$/) {
	my $holiday = $1;
	$email_subj = "$holiday begins tonight at sundown.";
	if ($holiday eq "Tish'a B'Av") {
	  $email_subj .= " Tzom Kal. We wish you an easy fast.";
	} elsif ($holiday eq "Yom Kippur") {
	  $email_subj .= " G'mar Chatimah Tovah! We wish you a good inscription in the Book of Life.";
	} elsif ($holiday eq "Pesach") {
	  $email_subj .= " Chag Kasher v'Sameach! We wish you a happy Passover.";
	} else {
	  $email_subj .= " Chag Sameach!";
	}
      } elsif ($subj eq "Chanukah: 1 Candle") {
	$email_subj = "Light the first Chanukah candle tonight at sundown. Chag Urim Sameach!";
      }
    } elsif (event_date_matches($evt, @tomorrow)) {
      msg("Tomorrow is $subj", $opt_verbose);
      if ($subj =~ /^Rosh Chodesh/ && $subj ne $today_subj) {
	$email_subj = "$subj begins tonight at sundown. Chodesh Tov!";
      } elsif ($subj eq "Shmini Atzeret") {
	$email_subj = "$subj begins tonight at sundown. Chag Sameach!";
      } elsif ($subj =~ /^(Tzom|Asara|Ta\'anit) /) {
	$email_subj = "$subj begins tomorrow at dawn. Tzom Kal. We wish you an easy fast.";
      }
    }
  }
}

if ($email_subj) {
    msg("Email subject is $email_subj", $opt_verbose);

    if ($opt_randsleep) {
      my $sleep = int(rand($opt_randsleep));
      msg("Sleeping for $sleep seconds before posting", $opt_verbose);
      sleep($sleep);
    }

    my %headers = (
	   "From" => "Hebcal <$EMAIL_FROM>",
	   "To" => $EMAIL_TO,
	   "Cc" => $EMAIL_CC,
	   "MIME-Version" => "1.0",
	   "Content-Type" => "text/plain",
	   "Subject" => $email_subj,
	 );

    msg("Sending mail from $EMAIL_FROM to $EMAIL_TO...", $opt_verbose);
    Hebcal::sendmail_v2($EMAIL_FROM, \%headers, "", $opt_verbose)
	or croak "Can't send mail!";
}

msg("Done", $opt_verbose);
exit(0);

sub event_date_matches {
  my($evt,$gy,$gm,$gd) = @_;
  return ($evt->[$Hebcal::EVT_IDX_YEAR] == $gy
	  && $evt->[$Hebcal::EVT_IDX_MON] + 1 == $gm
	  && $evt->[$Hebcal::EVT_IDX_MDAY] == $gd);
}

sub usage {
    die "usage: $0 [--help] [--verbose] [--randsleep=MAXSECS]\n";
}
