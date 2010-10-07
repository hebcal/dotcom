package Hebcal::SMTP;

use strict;
use vars qw(@ISA);
use Net::SMTP::SSL;

@ISA = qw(Net::SMTP::SSL);

# this should be a class field, not a global
my $debug_txt = "";

# reset our global debug string
sub mail {
    my $self = shift;
    $debug_txt = "";
    $self->SUPER::mail(@_);
}

sub debug_print {
    my $self = shift;
    my($out,$text) = @_;
    $debug_txt .= ($out ? '>>> ' : '<<< ');
    $debug_txt .= $text;
}

sub debug_txt {
    $debug_txt;
}

1;
