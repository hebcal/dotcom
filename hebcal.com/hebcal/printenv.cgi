#!/usr/bin/perl
 
print "P3P: CP=\"TST\"\r\n";

print "Content-type: text/plain\r\n\r\n";
while (($key, $val) = each %ENV) {
        print "$key=\"$val\"\n";
}

while (($key, $val) = each %ENV) {
    print "export $key\n";
}
