#!/bin/sh

# $Id$
# $Source: /Users/mradwin/hebcal-copy/hebcal.com/bin/RCS/cache_cleanup.sh,v $

HEBCAL_WEB=/home/mradwin/web/hebcal.com

if [ -d $HEBCAL_WEB/cache ]; then
    /bin/mv -f $HEBCAL_WEB/cache $HEBCAL_WEB/cache.old
    /bin/rm -rf $HEBCAL_WEB/cache.old
fi
