#!/usr/bin/perl -w

########################################################################
#
# Copyright (c) 2016  Michael J. Radwin.
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
use Carp;
use Log::Log4perl qw(:easy);
use File::Basename;
use Config::Tiny;

my $opt_help;
my $opt_verbose = 0;
my $opt_shabbat;
my $opt_daily;
my $opt_dryrun = 0;
my $opt_randsleep;
my $opt_twitter = 1;
my $opt_facebook = 1;

if (!Getopt::Long::GetOptions
    ("help|h" => \$opt_help,
     "verbose|v" => \$opt_verbose,
     "dryrun|n" => \$opt_dryrun,
     "facebook!" => \$opt_facebook,
     "twitter!" => \$opt_twitter,
     "daily" => \$opt_daily,
     "shabbat" => \$opt_shabbat,
     "randsleep=i" => \$opt_randsleep)) {
    usage();
}

$opt_help && usage();

Log::Log4perl->easy_init($opt_verbose ? $INFO : $WARN);

# don't post anything on yontiff
exit_if_yomtov();

INFO("Reading $Hebcal::CONFIG_INI_PATH");
my $Config = Config::Tiny->read($Hebcal::CONFIG_INI_PATH)
    or LOGDIE "$Hebcal::CONFIG_INI_PATH: $!\n";

my $EMAIL_FROM = $Config->{_}->{"hebcal.email.facebook.from"};
my $EMAIL_TO = $Config->{_}->{"hebcal.email.facebook.to"};
my $EMAIL_CC = "michael\@radwin.org";
my $HEBCAL = $Hebcal::HEBCAL_BIN;

my $email_subj;			# will be populated if there's an email to send
my $slug;			# if we want to link to URL on Twitter

if ($opt_shabbat) {
  # get the date for this upcoming saturday
  my($sat_year,$sat_month,$sat_day) = Hebcal::upcoming_dow(6);
  DEBUG("Shabbat is $sat_year,$sat_month,$sat_day");

  my @ev2 = Hebcal::invoke_hebcal_v2("$HEBCAL -s -x $sat_year", "", 0, $sat_month);
  my $parasha;
  my $special_shabbat;
  for my $evt (@ev2) {
    next unless $evt->{mday} == $sat_day;
    my $subj = $evt->{subj};
    INFO("Found $subj");
    if ($subj =~ /^Parashat/) {
	$parasha = $subj;
	$slug = get_twitter_slug($subj);
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
  my @events = Hebcal::invoke_hebcal_v2($HEBCAL, "", 0);
  my @today = Date::Calc::Today();
  my @tomorrow = Date::Calc::Add_Delta_Days(@today, 1);
  my $today_subj = "";
  for my $evt (@events) {
    my $subj = $evt->{subj};
    if (Hebcal::event_date_matches($evt, $today[0], $today[1], $today[2])) {
      INFO("Today is $subj");
      $today_subj = $subj;
      if ($subj =~ /^Erev (.+)$/) {
	my $holiday = $1;
	$email_subj = "$holiday begins tonight at sundown.";
	$slug = get_twitter_slug($subj);
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
	$slug = get_twitter_slug($subj);
      }
    } elsif (Hebcal::event_date_matches($evt, $tomorrow[0], $tomorrow[1], $tomorrow[2])) {
      INFO("Tomorrow is $subj");
      if ($subj =~ /^Rosh Chodesh/ && $subj ne $today_subj) {
	$email_subj = "$subj begins tonight at sundown. Chodesh Tov!";
	$slug = get_twitter_slug($subj);
      } elsif ($subj eq "Shmini Atzeret") {
	$email_subj = "$subj begins tonight at sundown. Chag Sameach!";
	$slug = get_twitter_slug($subj);
      } elsif ($subj =~ /^(Tzom|Asara|Ta\'anit) /) {
	$email_subj = "$subj begins tomorrow at dawn. Tzom Kal. We wish you an easy fast.";
	$slug = get_twitter_slug($subj);
      }
    }
  }
}

if ($email_subj) {
    INFO("STATUS=$email_subj");

    if ($opt_randsleep) {
      my $sleep = int(rand($opt_randsleep));
      INFO("Sleeping for $sleep seconds before posting");
      sleep($sleep) unless $opt_dryrun;
    }

    my %headers = (
	   "From" => "Hebcal <$EMAIL_FROM>",
	   "To" => $EMAIL_TO,
	   "Cc" => $EMAIL_CC,
	   "MIME-Version" => "1.0",
	   "Content-Type" => "text/plain",
	   "Subject" => $email_subj,
	 );

    if ($opt_facebook) {
	INFO("Sending mail from $EMAIL_FROM to $EMAIL_TO...");
	if (! $opt_dryrun) {
	    Hebcal::sendmail_v2($EMAIL_FROM, \%headers, "", $opt_verbose)
		    or croak "Can't send mail!";
	}
    }

    if ($opt_twitter) {
	my $twitter_subj = $email_subj;
	$twitter_subj =~ s/Torah/\#Torah/;
	if ($slug) {
	    if (index($slug, "/") == 0) {
		$slug = "http://www.hebcal.com${slug}";
                $slug = Hebcal::shorten_anchor($slug);
	    }
	    $twitter_subj .= " " . $slug;
	}
	INFO("Twitter status: $twitter_subj");
	if (! $opt_dryrun) {
	    my $cmd = dirname($0) . "/post_twitter.py";
	    system($cmd, $twitter_subj) == 0
		or LOGDIE("system $cmd failed: $?");
	}
    }
}

INFO("Done");
exit(0);

sub get_twitter_slug {
    my($subj) = @_;
    my($slug,undef,undef) = Hebcal::get_holiday_anchor($subj,0,undef);
    $slug;
}

sub exit_if_yomtov {
    my $subj = Hebcal::get_today_yomtov();
    if ($subj) {
	INFO("Today is yomtov: $subj");
	exit(0);
    }
    1;
}

sub usage {
    die "usage: $0 [--help] [--verbose] [--randsleep=MAXSECS] [--dryrun]\n";
}
