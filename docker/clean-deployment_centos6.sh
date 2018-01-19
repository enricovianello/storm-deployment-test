#!/bin/bash
set -ex
trap "exit 1" TERM

source ./../properties

COMMON_PATH="../common"

# install UMD repositories
sh ${COMMON_PATH}/install-umd-repos.sh ${UMD_RELEASE_RPM}

# install StoRM repository
sh ${COMMON_PATH}/install-storm-repo.sh ${STORM_REPO}

# use local repo
if [ -n ${USE_LOCAL_REPO+x} ]; then
   cat << EOF > /etc/yum.repos.d/local-stage-area.repo
[local-stage-area]
name=local-stage-area
baseurl=file:///stage-area/centos6
protect=1
enabled=1
priority=1
gpgcheck=0
EOF 
fi

# add storm user
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
sh ${COMMON_PATH}/install-yaim-configuration.sh "update"

# Sleep more avoid issues on docker
sed -i 's/sleep 20/sleep 30/' /etc/init.d/storm-backend-server

# Sleep more in bdii init script to avoid issues on docker
sed -i 's/sleep 2/sleep 5/' /etc/init.d/bdii

# configure with yaim
/opt/glite/yaim/bin/yaim -c -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_webdav

# run post-installation config script
sh ${COMMON_PATH}/post-config-setup.sh "update"
