#!/usr/local/bin/perl5 -w

use DB_File;
use CGI;
use strict;

my($zip) = '';
if (defined $ENV{'HTTP_X_UP_SUBNO'})
{
    my $dbmfile = 'shabbat/wap.db';
    my %DB;
    tie(%DB, 'DB_File', $dbmfile, O_RDONLY, 0444, $DB_File::DB_HASH)
	|| die "Can't tie $dbmfile: $!\n";

    my($q) = new CGI;

    my($user) = $ENV{'HTTP_X_UP_SUBNO'};
    my($val) = $DB{$user};
    untie(%DB);

    if (defined $val)
    {
	my($c) = new CGI($val);
	$zip = $c->param('zip');
    }
}

print STDOUT "Content-Type: text/vnd.wap.wml\015\012\015\012";
print STDOUT <<EOF;
<?xml version="1.0"?>
<!DOCTYPE wml PUBLIC "-//WAPFORUM//DTD WML 1.1//EN"
  "http://www.wapforum.org/DTD/wml_1.1.xml">
<wml>
 <card id="main" title="1-Click Shabbat">
  <do type="accept" label="OK">
   <go href="/shabbat/" method="get">
    <postfield name="zip" value="\$(zip)"/>
    <postfield name="cfg" value="w"/>
   </go>
  </do>
  <p>Enter Zip: <input name="zip" format="5N" size="5" value="$zip"/></p>
 </card>
</wml>
EOF
