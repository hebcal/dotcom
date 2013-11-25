#!/bin/sh

set -x

MYTMPDIR=`mktemp -d /tmp/tmp.XXXXXXXXXX`
ZIPDATA="zip-codes-database-STANDARD-sql.zip"
DBFILE=$MYTMPDIR/zips.sqlite3

if [ ! -f $ZIPDATA ]; then
    echo "missing $ZIPDATA"
    exit 1
fi

unzip $ZIPDATA -d $MYTMPDIR

sqlite3 -echo $DBFILE < ./zips_create.sql

echo "BEGIN TRANSACTION;" > $MYTMPDIR/load.sql
echo ".read '$MYTMPDIR/zip-codes-database-STANDARD.sql'" >> $MYTMPDIR/load.sql
echo "COMMIT;" >> $MYTMPDIR/load.sql

sqlite3 $DBFILE < $MYTMPDIR/load.sql

sqlite3 -echo $DBFILE < ./zips_finish.sql

sqlite3 -echo $DBFILE < ./zips_merge.sql

rm zips.sqlite3
mv $DBFILE .

rm -rf $MYTMPDIR
