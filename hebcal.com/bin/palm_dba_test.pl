#!/usr/bin/perl -w

use Palm::DBA;
use strict;

my @events = (
	      ["Michael's Birthday", 1, -1, -1, 2, 5, 1975, 0, ""],
	      ["Dinner with Ariella", 0, 30, 19, 13, 7, 2002, 120, ""],
	     );

Palm::DBA::write_header('calendar_2002.dba');
Palm::DBA::write_contents(\@events, 'America/New_York');
exit(0);
