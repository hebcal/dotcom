#!/bin/sh

set -x

nice wget --mirror --no-parent http://tzurl.org/zoneinfo/
find tzurl.org/zoneinfo/ -name 'index.html*' -delete
rsync -av tzurl.org/zoneinfo/ /home/hebcal/web/hebcal.com/zoneinfo/
