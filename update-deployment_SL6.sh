#!/bin/bash

# This script execute a clean deployment of StoRM
WGET_OPTIONS="--no-check-certificate"

trap "exit 1" TERM
set -ex

# use the STORM_REPO env variable for the repo, or default to the develop repo
if [ -n "${STORM_REPO}" ]; then
  STORM_REPO=${STORM_REPO}
else
  echo "ERROR: STORM_REPO not found. Please check your environment variables."
  exit 1
fi

# install UMD repositories
rpm --import http://repository.egi.eu/sw/production/umd/UMD-RPM-PGP-KEY
wget $WGET_OPTIONS http://repository.egi.eu/sw/production/umd/3/sl6/x86_64/updates/umd-release-3.14.3-1.el6.noarch.rpm
yum localinstall -y umd-release-3.14.3-1.el6.noarch.rpm

# add some users
adduser -r storm

# install
yum clean all
yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp storm-webdav

# disable the immutable attribute to avoid system updates issue
chattr -i /lib/udev/rules.d/75-net-description.rules

# install yaim configuration
sh ./install-yaim-configuration.sh

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# do yaim
/opt/glite/yaim/bin/yaim -c -d 6 -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav

# install the storm repo
wget $WGET_OPTIONS  $STORM_REPO -O /etc/yum.repos.d/storm.repo

# update
yum clean all
sh ./pre-update.sh
yum update -y

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# run post-installation config script
sh ./post-config-setup.sh

# do yaim
/opt/glite/yaim/bin/yaim -c -d 6 -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav
