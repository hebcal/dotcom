#!/bin/bash

set -x

TMPFILE=`mktemp /tmp/tmp.XXXXXXXXXX`
URL="http://127.0.0.1:8080/hebcal/index.cgi/export.pdf"
ARGS="month=x&v=1&nh=on&i=off&lg=s&c=off&geo=none&ny=1&nx=on&mf=on&ss=on&d=on"

year=`date +'%Y'`
for i in {0..9}
do
    hyear=$((year + i + 3759))
    outfile="hebcal-${hyear}.pdf"
    curl -o $TMPFILE "$URL?year=${hyear}&yt=H&${ARGS}" && cp $TMPFILE $outfile
    chmod 0644 $outfile

    gyear=$((year + i - 1))
    outfile="hebcal-${gyear}.pdf"
    curl -o $TMPFILE "$URL?year=${gyear}&yt=G&${ARGS}" && cp $TMPFILE $outfile
    chmod 0644 $outfile
done

rm -f $TMPFILE
