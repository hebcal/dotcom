
#grep .from= /var/log/httpd/hebcal.com-access_log | perl -ne 'if (/\.from=([^;&\s]+)/) { $a{$1}++; }  END{foreach (sort { $a{$b} <=> $a{$a} } keys %a){print "$a{$_}\t$_\n";}}'

#grep hebcal.com /var/log/httpd/access_log.vhosts | grep .from= | perl -ne 'if (/\.from=([^;&\s\"]+)/) { $a{$1}++; }  END{foreach (sort { $a{$b} <=> $a{$a} } keys %a){print "$a{$_}\t$_\n";}}'

grep hebcal.com /var/log/httpd/vhosts.access | perl -ne 'if (/\s+\"([^\"]+)\"\s+\"[^\"]+\"\s*$/) { $ref = $1; $a{$ref}++ unless ($ref =~ m,http://hebcal\.com, || $ref =~ m,http://www\.hebcal\.com,); }  END{foreach (sort { $a{$b} <=> $a{$a} } keys %a){print "$a{$_}\t$_\n";}}'
