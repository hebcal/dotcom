#!/bin/sh

grep hebcal.com /var/log/httpd/vhosts.access | perl -ne 'if (/\s+\"([^\"]+)\"\s+\"[^\"]+\"\s*$/) { $ref = $1; $a{$ref}++ unless ($ref =~ m,http://hebcal\.com, || $ref =~ m,http://www\.hebcal\.com,); }  END{foreach (sort { $a{$b} <=> $a{$a} } keys %a){print "$a{$_}\t$_\n";}}'
