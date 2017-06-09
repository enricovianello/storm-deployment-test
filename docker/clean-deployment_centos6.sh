#!/bin/bash
set -ex
trap "exit 1" TERM

COMMON_PATH="../common"
WGET_OPTIONS="--no-check-certificate"

# use the STORM_REPO env variable for the repo or use storm official centos6 repo
STORM_REPO=${STORM_REPO:-http://italiangrid.github.io/storm/repo/storm_sl6.repo}

# install UMD repositories
sh ${COMMON_PATH}/install-umd-repos.sh

# install the storm repo
wget $WGET_OPTIONS $STORM_REPO -O /etc/yum.repos.d/storm.repo

# install
yum clean all

# add some users
adduser -r storm

# install storm packages
yum install -y --enablerepo=centosplus emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp storm-webdav

# avoid starting frontend server
sed -i -e '/\/sbin\/service storm-frontend-server start/c\\#\/sbin\/service storm-frontend-server start' /opt/glite/yaim/functions/local/config_storm_frontend

# avoid ntp check
echo "config_ntp () {"> /opt/glite/yaim/functions/local/config_ntp
echo "return 0">> /opt/glite/yaim/functions/local/config_ntp
echo "}">> /opt/glite/yaim/functions/local/config_ntp

# install yaim configuration
sh ${COMMON_PATH}/install-yaim-configuration.sh "clean"

# Sleep more avoid issues on docker
sed -i 's/sleep 20/sleep 30/' /etc/init.d/storm-backend-server

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# configure with yaim
/opt/glite/yaim/bin/yaim -c -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav

# run post-installation config script
sh ${COMMON_PATH}/post-config-setup.sh "clean"
