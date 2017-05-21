#!/bin/sh

set -x

TMPFILE=`mktemp /tmp/hebcal.XXXXXX`
YEAR=`date +'%Y'`
DOWNLOAD_URL="http://download.hebcal.com"
ICS_URL="${DOWNLOAD_URL}/hebcal/index.cgi/export.ics"
CSV_URL="${DOWNLOAD_URL}/hebcal/index.cgi/hebcal_usa.csv"

fetch_urls () {
    file=$1
    args=$2
    rm -f "${file}.ics" "${file}.csv"
    curl -o $TMPFILE "${ICS_URL}?${args}" && cp $TMPFILE "${file}.ics"
    curl -o $TMPFILE "${CSV_URL}?${args}" && cp $TMPFILE "${file}.csv"
    chmod 0644 "${file}.ics" "${file}.csv"
}

update_ics_name() {
    file=$1
    name=$2
    desc=$3
    perl -pi -e "s/^X-WR-CALNAME:.*/X-WR-CALNAME:${name}\r/" "${file}.ics"
    perl -pi -e "s/^X-WR-CALDESC:.*/X-WR-CALDESC:${desc}\r/" "${file}.ics"
    perl -pi -e "s/^X-PUBLISHED-TTL:PT7D/X-PUBLISHED-TTL:PT30D/" "${file}.ics"
    perl -pi -e "s,^X-ORIGINAL-URL:.*,X-ORIGINAL-URL:${DOWNLOAD_URL}/ical/${file}.ics\r," "${file}.ics"
}


FILE="jewish-holidays"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;maj=on;min=off;mod=off;i=off;lg=s;c=off;geo=none;ny=10;nx=off;mf=off;ss=off"
update_ics_name $FILE \
    "Jewish Holidays" \
    "http:\\/\\/www.hebcal.com\\/"

FILE="jewish-holidays-all"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;maj=on;min=on;mod=on;i=off;lg=s;c=off;geo=none;ny=10;nx=on;mf=on;ss=on"
update_ics_name $FILE \
    "Jewish Holidays" \
    "http:\\/\\/www.hebcal.com\\/"

FILE="hdate-en"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;i=off;lg=s;d=on;c=off;geo=none;ny=2"
update_ics_name $FILE \
    "Hebrew calendar dates (en)" \
    "Displays the Hebrew date every day of the week in English transliteration"

FILE="hdate-he"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;i=off;lg=h;d=on;c=off;geo=none;ny=2"
update_ics_name $FILE \
    "Hebrew calendar dates (he)" \
    "Displays the Hebrew date every day of the week in Hebrew"

FILE="omer"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;o=on;i=off;lg=s;c=off;geo=none;ny=2"
update_ics_name $FILE \
    "Days of the Omer" \
    "7 weeks from the second night of Pesach to the day before Shavuot"

FILE="torah-readings-diaspora"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;s=on;i=off;lg=s;c=off;geo=none;ny=3"
update_ics_name $FILE \
    "Torah Readings (Diaspora)" \
    "Parashat ha-Shavua - Weekly Torah Portion from Hebcal"

FILE="torah-readings-israel"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;s=on;i=on;lg=s;c=off;geo=none;ny=3"
update_ics_name $FILE \
    "Torah Readings (Israel English)" \
    "Parashat ha-Shavua - Weekly Torah Portion from Hebcal"

FILE="torah-readings-israel-he"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;s=on;i=on;lg=h;c=off;geo=none;ny=3"
update_ics_name $FILE \
    "Torah Readings (Israel Hebrew)" \
    "Parashat ha-Shavua - Weekly Torah Portion from Hebcal"

FILE="daf-yomi"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;F=on;i=off;lg=s;c=off;geo=none;ny=2"
update_ics_name $FILE \
    "Daf Yomi" \
    "Daily regimen of learning the Talmud"

rm -f $TMPFILE
