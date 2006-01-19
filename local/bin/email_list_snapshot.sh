#!/bin/sh

/usr/bin/mysqldump \
  --skip-opt \
  --host=mysql.hebcal.com --user=mradwin_hebcal --password=xxxxxxxx \
  hebcal1 hebcal_shabbat_email \
  > $HOME/local/etc/hebcalsubs.sql.tmp && \
/bin/mv $HOME/local/etc/hebcalsubs.sql.tmp $HOME/local/etc/hebcalsubs.sql && \
nice /usr/bin/ci -q -m'daily checkin' -l $HOME/local/etc/hebcalsubs.sql

