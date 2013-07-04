#!/bin/sh

HEBCAL_WEB=/home/hebcal/web/hebcal.com

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

if [ -d $HEBCAL_WEB/cache ]; then
    mv -f $HEBCAL_WEB/cache $HEBCAL_WEB/cache.$$
    find $HEBCAL_WEB/cache.$$ -type f -delete
    rm -rf $HEBCAL_WEB/cache.$$
fi
