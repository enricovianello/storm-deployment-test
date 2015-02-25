#!/bin/bash
set -ex
trap "exit 1" TERM

pushd .

# add SAs links
cd /storage/testers.eu-emi.eu/
ln -s ../dteam dteam
ln -s ../noauth noauth_sa

cd /storage/noauth/
ln -s ../testers.eu-emi.eu testers

# fix db grants for root@'fqdn' if needed
HOSTNAME=`hostname -f`

popd
source ./siteinfo/storm.def

mysql -u root -p${MYSQL_PASSWORD} -e"GRANT ALL PRIVILEGES ON *.* TO 'root'@'${HOSTNAME}' IDENTIFIED BY '${MYSQL_PASSWORD}' WITH GRANT OPTION; FLUSH PRIVILEGES" > /dev/null 2> /dev/null


