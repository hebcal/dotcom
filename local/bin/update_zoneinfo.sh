#!/bin/sh

set -x

MYTMPDIR=`mktemp -d /tmp/tmp.XXXXXXXXXX`

cd $MYTMPDIR

nice wget --quiet --mirror --no-parent --limit-rate=40k http://tzurl.org/zoneinfo/
find tzurl.org/zoneinfo/ -name 'index.html*' -delete
rsync -av tzurl.org/zoneinfo/ /var/www/html/zoneinfo/

cd /
rm -rf $MYTMPDIR
