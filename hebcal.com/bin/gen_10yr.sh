#!/bin/sh

set -x

TMPFILE=`mktemp`
YEAR=`date +'%Y'`
ICS_URL="http://www.hebcal.com/hebcal/index.cgi/export.ics"
CSV_URL="http://www.hebcal.com/hebcal/index.cgi/hebcal_usa.csv"

fetch_urls () {
    file=$1
    args=$2
    curl -o $TMPFILE "${ICS_URL}?${args}" && cp $TMPFILE "${file}.ics"
    curl -o $TMPFILE "${CSV_URL}?${args}" && cp $TMPFILE "${file}.csv"
}

update_ics_name() {
    file=$1
    name=$2
    desc=$3
    perl -pi -e "s/^X-WR-CALNAME:.*/X-WR-CALNAME:${name}\r/" "${file}.ics"
    perl -pi -e "s/^X-WR-CALDESC:.*/X-WR-CALDESC:${desc}\r/" "${file}.ics"
}


FILE="jewish-holidays"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;nh=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10;nx=off;mf=off;ss=off"
perl -pi -e "s/tag=ical/tag=dl-major/g" "${FILE}.ics"
update_ics_name $FILE \
    "Jewish Holidays" \
    "http:\\/\\/www.hebcal.com\\/"

FILE="jewish-holidays-all"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;nh=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10;nx=on;mf=on;ss=on"
perl -pi -e "s/tag=ical/tag=dl-all/g" "${FILE}.ics"
update_ics_name $FILE \
    "Jewish Holidays" \
    "http:\\/\\/www.hebcal.com\\/"

FILE="hdate-en"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;i=off;lg=s;vis=on;d=on;c=off;geo=zip;ny=3"
update_ics_name $FILE \
    "Hebrew calendar dates (en)" \
    "Displays the Hebrew date every day of the week in English transliteration"

FILE="hdate-he"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;i=off;lg=h;vis=on;d=on;c=off;geo=zip;ny=3"
update_ics_name $FILE \
    "Hebrew calendar dates (he)" \
    "Displays the Hebrew date every day of the week in Hebrew"

FILE="omer"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;o=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=3"
update_ics_name $FILE \
    "Hebcal Days of the Omer" \
    "7 weeks from the second night of Pesach to the day before Shavuot"

rm -f $TMPFILE
