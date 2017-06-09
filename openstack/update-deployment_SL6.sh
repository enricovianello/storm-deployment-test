#!/bin/bash

COMMON_PATH="../common"
WGET_OPTIONS="--no-check-certificate"

trap "exit 1" TERM
set -ex

# use the STORM_REPO env variable for the repo or use storm official centos6 repo
STORM_REPO=${STORM_REPO:-http://italiangrid.github.io/storm/repo/storm_sl6.repo}

# install UMD repositories
sh ${COMMON_PATH}/install-umd-repos.sh

# add some users
adduser -r storm

# install
yum clean all
yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp storm-webdav

# disable the immutable attribute to avoid system updates issue
chattr -i /lib/udev/rules.d/75-net-description.rules

# install yaim configuration
sh ${COMMON_PATH}/install-yaim-configuration.sh "clean"

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# do yaim
/opt/glite/yaim/bin/yaim -c -d 6 -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav

# install the storm repo
wget $WGET_OPTIONS $STORM_REPO -O /etc/yum.repos.d/storm.repo

# update
yum clean all
yum update -y

sh ${COMMON_PATH}/post-update.sh

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# re-install yaim configuration
sh ${COMMON_PATH}/install-yaim-configuration.sh "update"

# run post-installation config script
sh ${COMMON_PATH}/post-config-setup.sh "update"

# do yaim
/opt/glite/yaim/bin/yaim -c -d 6 -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav
