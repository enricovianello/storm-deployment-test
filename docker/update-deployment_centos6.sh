#!/bin/bash

fix_yaim () {
  # avoid starting frontend server
  sed -i -e '/\/sbin\/service storm-frontend-server start/c\\#\/sbin\/service storm-frontend-server start' /opt/glite/yaim/functions/local/config_storm_frontend

  # avoid ntp check
  echo "config_ntp () {"> /opt/glite/yaim/functions/local/config_ntp
  echo "return 0">> /opt/glite/yaim/functions/local/config_ntp
  echo "}">> /opt/glite/yaim/functions/local/config_ntp
}

# This script execute a clean deployment of StoRM
WGET_OPTIONS="--no-check-certificate"

trap "exit 1" TERM
set -ex

FROM_VERSION=${FROM_VERSION:-"production"}
TO_VERSION=${TO_VERSION:-"production"}

# use the STORM_REPO env variable for the repo or exit with error
if [ -n "${STORM_REPO}" ]; then
  STORM_REPO=${STORM_REPO}
else
  echo "ERROR: STORM_REPO not found. Please check your environment variables."
  exit 1
fi

# install UMD repositories
rpm --import http://repository.egi.eu/sw/production/umd/UMD-RPM-PGP-KEY
yum install -y http://repository.egi.eu/sw/production/umd/3/sl6/x86_64/updates/umd-release-3.14.3-1.el6.noarch.rpm

# add some users
adduser -r storm

# install
yum clean all
yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp storm-webdav

fix_yaim

# install yaim configuration
sh ./install-yaim-configuration.sh ${FROM_VERSION}

# Sleep more avoid issues on docker
sed -i 's/sleep 20/sleep 30/' /etc/init.d/storm-backend-server

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# do yaim
/opt/glite/yaim/bin/yaim -c -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav

# install the storm repo
wget $WGET_OPTIONS  $STORM_REPO -O /etc/yum.repos.d/storm.repo

# update
yum clean all
yum update -y

if [ $? != 0 ]; then
    echo "Problem occurred while updating the system!"
    exit 1
fi

sh ./post-update.sh

fix_yaim

# Sleep more avoid issues on docker
sed -i 's/sleep 20/sleep 30/' /etc/init.d/storm-backend-server

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# re-install yaim configuration
sh ./install-yaim-configuration.sh ${TO_VERSION}

# run post-installation config script
sh ./post-config-setup.sh ${TO_VERSION}

# do yaim
/opt/glite/yaim/bin/yaim -c -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav
