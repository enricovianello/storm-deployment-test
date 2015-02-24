#!/bin/bash
set -x
trap "exit 1" TERM

# add SAs links
cd /storage/testers.eu-emi.eu/
ln -s ../dteam dteam
ln -s ../noauth noauth_sa

cd /storage/noauth/
ln -s ../testers.eu-emi.eu testers

# fix db grants for root@'fqdn' if needed
HOSTNAME=`hostname -f`

mysql -h ${HOSTNAME} -u root -p${STORM_DB_PASSWORD} -e"use storm_db;" > /dev/null 2> /dev/null
if [ "$?" -ne 0 ]; then
    mysql -u root -p${STORM_DB_PASSWORD} -e"GRANT ALL PRIVILEGES ON *.* TO 'root'@'${HOSTNAME}' IDENTIFIED BY '${STORM_DB_PASSWORD}' WITH GRANT OPTION; FLUSH PRIVILEGES" > /dev/null 2> /dev/null
fi

