#!/usr/bin/perl -w

$ENV{"LANG"} = "he_IL.UTF-8";

use strict;
use Locale::gettext;
use POSIX;     # Needed for setlocale()

#textdomain("hebcal");
bindtextdomain("hebcal", ".");

setlocale(LC_MESSAGES, "he_IL.UTF-8");

print dgettext("hebcal", "Bamidbar"), "\n";
