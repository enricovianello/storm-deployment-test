#!/bin/bash

fix_yaim () {
  # avoid starting frontend server
  sed -i -e '/\/sbin\/service storm-frontend-server start/c\\#\/sbin\/service storm-frontend-server start' /opt/glite/yaim/functions/local/config_storm_frontend

  # avoid ntp check
  echo "config_ntp () {"> /opt/glite/yaim/functions/local/config_ntp
  echo "return 0">> /opt/glite/yaim/functions/local/config_ntp
  echo "}">> /opt/glite/yaim/functions/local/config_ntp
}

trap "exit 1" TERM
set -ex

source ./../properties

COMMON_PATH="../common"

# install UMD repositories
sh ${COMMON_PATH}/install-umd-repos.sh ${UMD_RELEASE_RPM}

# add some users
adduser -r storm

# install
yum clean all
yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp storm-webdav

fix_yaim

# install yaim configuration
sh ${COMMON_PATH}/install-yaim-configuration.sh "clean"

# Sleep more avoid issues on docker
sed -i 's/sleep 20/sleep 30/' /etc/init.d/storm-backend-server

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# do yaim
/opt/glite/yaim/bin/yaim -c -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav

# install StoRM repository
sh ${COMMON_PATH}/install-storm-repo.sh ${STORM_REPO}

# update
yum clean all
yum update -y

if [ $? != 0 ]; then
    echo "Problem occurred while updating the system!"
    exit 1
fi

sh ${COMMON_PATH}/post-update.sh

fix_yaim

# Sleep more avoid issues on docker
sed -i 's/sleep 20/sleep 30/' /etc/init.d/storm-backend-server

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# re-install yaim configuration
sh ${COMMON_PATH}/install-yaim-configuration.sh "update"

# run post-installation config script
sh ${COMMON_PATH}/post-config-setup.sh "update"

# do yaim
/opt/glite/yaim/bin/yaim -c -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav
