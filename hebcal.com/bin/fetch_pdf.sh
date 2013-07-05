#!/bin/sh

set -x

TMPFILE=`mktemp /tmp/tmp.XXXXXXXXXX`
URL="http://www.hebcal.com/hebcal/index.cgi/export.pdf"
ARGS="month=x&yt=H&v=1&nh=on&i=off&lg=s&c=off&geo=none&ny=1&nx=on&mf=on&ss=on&d=on"

year=`date +'%Y'`
for i in {0..9}
do
    hyear=$((year + i + 3759))
    outfile="hebcal-${hyear}.pdf"
    curl -o $TMPFILE "$URL?year=${hyear}&${ARGS}" && cp $TMPFILE $outfile
    chmod 0644 $outfile
done

rm -f $TMPFILE
