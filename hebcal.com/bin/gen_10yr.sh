#!/bin/sh

set -x

TMPFILE=`mktemp`
YEAR=`date +'%Y'`

URL="http://www.hebcal.com/hebcal/index.cgi/export.ics?year=${YEAR};month=x;yt=G;v=1;nh=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10;nx=off;mf=off;ss=off"
curl -o $TMPFILE $URL
perl -pi -e "s/tag=ical/tag=dl-major/g" $TMPFILE
cp $TMPFILE jewish-holidays.ics

URL="http://www.hebcal.com/hebcal/index.cgi/export.ics?year=${YEAR};month=x;yt=G;v=1;nh=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10;nx=on;mf=on;ss=on"
curl -o $TMPFILE $URL
perl -pi -e "s/tag=ical/tag=dl-all/g" $TMPFILE
cp $TMPFILE jewish-holidays-all.ics

URL="http://www.hebcal.com/hebcal/index.cgi/export.ics?year=${YEAR};month=x;yt=G;v=1;i=off;lg=s;vis=on;d=on;c=off;geo=zip;ny=5"
curl -o $TMPFILE $URL && cp $TMPFILE hdate-en.ics

URL="http://www.hebcal.com/hebcal/index.cgi/export.ics?year=${YEAR};month=x;yt=G;v=1;i=off;lg=h;vis=on;d=on;c=off;geo=zip;ny=5"
curl -o $TMPFILE $URL && cp $TMPFILE hdate-he.ics

URL="http://www.hebcal.com/hebcal/index.cgi/export.ics?year=${YEAR};month=x;yt=G;v=1;o=on;i=off;lg=s;vis=on;c=off;geo=zip;ny=10"
curl -o $TMPFILE $URL && cp $TMPFILE omer.ics

rm -f $TMPFILE