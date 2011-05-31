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

FILE="jewish-holidays"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;nh=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10;nx=off;mf=off;ss=off"
perl -pi -e "s/tag=ical/tag=dl-major/g" "${FILE}.ics"

FILE="jewish-holidays-all"
fetch_urls $FILE "year=${YEAR};month=x;yt=G;v=1;nh=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10;nx=on;mf=on;ss=on"
perl -pi -e "s/tag=ical/tag=dl-all/g" "${FILE}.ics"

fetch_urls "hdate-en" "year=${YEAR};month=x;yt=G;v=1;i=off;lg=s;vis=on;d=on;c=off;geo=zip;ny=5"

fetch_urls "hdate-he" "year=${YEAR};month=x;yt=G;v=1;i=off;lg=h;vis=on;d=on;c=off;geo=zip;ny=5"

fetch_urls "omer" "year=${YEAR};month=x;yt=G;v=1;o=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10"

rm -f $TMPFILE
