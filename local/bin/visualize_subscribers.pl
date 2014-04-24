#!/usr/bin/perl -w

use lib "/home/hebcal/local/share/perl";
use lib "/home/hebcal/local/share/perl/site_perl";

use strict;
use Hebcal ();
use DBI ();
use Log::Log4perl qw(:easy);
use Config::Tiny;

Log::Log4perl->easy_init($INFO);

INFO("Opening Geonames database");
my $GEONAME_SQLITE_FILE = "$Hebcal::WEBDIR/hebcal/geonames.sqlite3";
my $GEONAME_DBH = Hebcal::zipcode_open_db($GEONAME_SQLITE_FILE);
$GEONAME_DBH->{sqlite_unicode} = 1;


INFO("Reading $Hebcal::CONFIG_INI_PATH");
my $Config = Config::Tiny->read($Hebcal::CONFIG_INI_PATH)
    or LOGDIE "$Hebcal::CONFIG_INI_PATH: $!";

my %SUBS;
load_subs();
parse_all_configs();

Hebcal::zipcode_close_db($GEONAME_DBH);

my %countries;
while(my($to,$cfg) = each(%SUBS)) {
    $countries{$cfg->{cc}}++;
}

my $json = qq{[\n["Country", "Subscribers"],\n};
while(my($country,$count) = each(%countries)) {
    $json .= qq{["$country", $count],\n}
}
chop($json);
chop($json);
$json .= "\n]\n";

print $json;


INFO("Success!");
exit(0);

sub load_subs {
    my $dbhost = $Config->{_}->{"hebcal.mysql.host"};
    my $dbuser = $Config->{_}->{"hebcal.mysql.user"};
    my $dbpass = $Config->{_}->{"hebcal.mysql.password"};
    my $dbname = $Config->{_}->{"hebcal.mysql.dbname"};
    my $dsn = "DBI:mysql:database=$dbname;host=$dbhost";
    DEBUG("Connecting to $dsn");
    my $dbh = DBI->connect($dsn, $dbuser, $dbpass)
        or LOGDIE("DB Connection not made: $DBI::errstr");
    $dbh->{'mysql_enable_utf8'} = 1;

    my $sql = <<EOD
SELECT email_address,
       email_id,
       email_candles_zipcode,
       email_candles_city,
       email_candles_geonameid,
       email_candles_havdalah
FROM hebcal_shabbat_email
WHERE hebcal_shabbat_email.email_status = 'active'
AND hebcal_shabbat_email.email_ip IS NOT NULL
EOD
;

    INFO($sql);
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute
        or LOGCROAK "can't execute the query: " . $sth->errstr;
    my $count = 0;
    while (my($email,$id,$zip,$city,$geonameid,$havdalah) = $sth->fetchrow_array) {
        my $cfg = {
            id => $id,
            m => $havdalah,
        };
        if ($zip) {
            $cfg->{zip} = $zip;
        } elsif ($geonameid) {
            $cfg->{geonameid} = $geonameid;
        } elsif ($city) {
            $city =~ s/\+/ /g;
            if (defined($Hebcal::CITIES_OLD{$city})) {
                $city = $Hebcal::CITIES_OLD{$city};
            } elsif (! defined $Hebcal::CITY_LATLONG{$city}) {
                WARN("unknown city $city for id=$id;email=$email");
                next;
            }
            $cfg->{city} = $city;
        }
        $SUBS{$email} = $cfg;
        $count++;
    }

    $dbh->disconnect;

    INFO("Loaded $count users");
    $count;
}


sub parse_all_configs {
    INFO("Parsing all configs");
    while(my($to,$cfg) = each(%SUBS)) {
        my $status = parse_config($to,$cfg);
        delete $SUBS{$to} unless $status;
    }
}

sub parse_config {
    my($to,$cfg) = @_;

    if (defined $cfg->{zip}) {
        $cfg->{cc} = 'US';
    } elsif (defined $cfg->{geonameid}) {
        my $sql = qq{SELECT country FROM geoname WHERE geonameid = ?};
        my $sth = $GEONAME_DBH->prepare($sql)
            or die $GEONAME_DBH->errstr;
        $sth->execute($cfg->{geonameid})
            or die $GEONAME_DBH->errstr;
        ($cfg->{cc}) = $sth->fetchrow_array;
        $sth->finish;
    } elsif (defined $cfg->{city}) {
        $cfg->{cc} = $Hebcal::CITY_COUNTRY{$cfg->{city}};
    } else {
        ERROR("no geographic key in config for to=$to, id=$cfg->{id}");
        return undef;
    }
}

