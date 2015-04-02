#!/bin/sh

set -x

nice wget --mirror --no-parent --limit-rate=40k http://tzurl.org/zoneinfo/
find tzurl.org/zoneinfo/ -name 'index.html*' -delete
rsync -av tzurl.org/zoneinfo/ /var/www/zoneinfo/
