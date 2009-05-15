#!/bin/sh

PATH=/bin:/usr/bin
S3SYNCDIR=/home/mradwin/local/s3sync
LOCKFILE=/tmp/mradwin.s3backup.lock
BACKUPDIR=/home/hebcal/local/lib/svn

dotlockfile -r 0 -p $LOCKFILE
if [ $? != 0 ]; then
   echo "s3backup is still running; exiting"
   exit 1
fi

AWS_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxx
AWS_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx 

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY

cd $S3SYNCDIR
ruby s3sync.rb -v -r ${BACKUPDIR} hebcal:

dotlockfile -u $LOCKFILE

