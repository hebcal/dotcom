#!/bin/sh

# Copyright (c) 2002  Michael John Radwin.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

grep hebcal.com /var/log/httpd/vhosts.access | \
perl -ne 'if (/\s+\"([^\"]+)\"\s+\"[^\"]+\"\s*$/) { $ref = $1; $a{$ref}++ unless ($ref =~ m,http://hebcal\.com, || $ref =~ m,http://www\.hebcal\.com,); }  END{foreach (sort { $a{$b} <=> $a{$a} } keys %a){print "$a{$_}\t$_\n";}}'
