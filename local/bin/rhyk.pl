#!/usr/bin/perl -w

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use Hebcal ();

my $prev_rh;

for (my $yr = 1800; $yr < 2200; $yr++) {
    my $cmd = "./hebcal -x $yr";
    my @events = Hebcal::invoke_hebcal($cmd, "", 0);
    my %seen;
    my $rh_evt;
    foreach my $evt (@events) {
        my $subj = $evt->[$Hebcal::EVT_IDX_SUBJ];
#        next if $subj =~ /^Erev /;
#        next if $subj eq 'Erev Rosh Hashana';
#        next if $subj eq 'Erev Yom Kippur';
        my $subj_copy = Hebcal::get_holiday_basename($subj);
#        next if defined $seen{$subj_copy};
        if ($subj eq "Erev Rosh Hashana") {
            $rh_evt = $evt;
            next;
        } elsif ($subj eq "Yom Kippur") {
            my($gy,$gm,$gd) = Hebcal::event_ymd($evt);
            my($gy0,$gm0,$gd0) = Hebcal::event_ymd($prev_rh);
#            print "Comparing YK $gm/$gd/$gy with RH $gm0/$gd0/$gy0\n";
            if ($gm0 == $gm && $gd0 == $gd) {
                print "Erev RH $gy0 and YK $gy are both on $gm/$gd\n";
            }
        }
        $seen{$subj_copy} = 1;
    }
    $prev_rh = $rh_evt;
}
