#!/bin/sh

########################################################################
#
# $Id: email_list_snapshot.sh 2780 2008-11-28 07:12:27Z mradwin $
#
# Copyright (c) 2020  Michael J. Radwin.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following
# conditions are met:
#
#  * Redistributions of source code must retain the above
#    copyright notice, this list of conditions and the following
#    disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials
#    provided with the distribution.
#
#  * Neither the name of Hebcal.com nor the names of its
#    contributors may be used to endorse or promote products
#    derived from this software without specific prior written
#    permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
########################################################################

BACKUP=/home/hebcal/local/etc/hebcalsubs.sql
INI_FILE=/home/hebcal/local/etc/hebcal-dot-com.ini

DBHOST=`grep ^hebcal.mysql.host $INI_FILE | sed 's/^.*= *//'`
DBUSER=`grep ^hebcal.mysql.user $INI_FILE | sed 's/^.*= *//'`
DBPASS=`grep ^hebcal.mysql.password $INI_FILE | sed 's/^.*= *//'`
DBNAME=`grep ^hebcal.mysql.dbname $INI_FILE | sed 's/^.*= *//'`

/usr/bin/mysqldump \
  --skip-opt \
  --host=$DBHOST --user=$DBUSER --password=$DBPASS \
  $DBNAME hebcal_shabbat_email \
  > $BACKUP.$$ 2>/dev/null && \
nice /usr/bin/co -q -l $BACKUP && \
/bin/mv $BACKUP.$$ $BACKUP && \
nice /usr/bin/ci -q -m'daily checkin' -u $BACKUP

rm -f /tmp/hebcalsubs.sql /tmp/hebcalsubs.sql.bz2 && \
  cp $BACKUP /tmp && \
  bzip2 -9 /tmp/hebcalsubs.sql && \
  aws s3 cp /tmp/hebcalsubs.sql.bz2 s3://hebcal > /dev/null && \
  rm -f /tmp/hebcalsubs.sql.bz2
