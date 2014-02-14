#!/bin/sh

CACHEDIR=/var/www/cache/shabbat

PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH

if [ -d $CACHEDIR ]; then
    mv -f $CACHEDIR $CACHEDIR.$$
    find $HCACHEDIR.$$ -type f -delete
    rm -rf $CACHEDIR.$$
fi
