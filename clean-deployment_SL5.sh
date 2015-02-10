#!/bin/bash
trap "exit 1" TERM
set -ex

WGET_OPTIONS="--no-check-certificate"

# use the STORM_REPO env variable for the repo, or default to the develop repo
STORM_REPO=${STORM_REPO:-http://radiohead.cnaf.infn.it:9999/view/REPOS/job/repo_storm_develop_SL5/lastSuccessfulBuild/artifact/storm_develop_sl5.repo}

# install emi-release
wget $WGET_OPTIONS http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl5/x86_64/base/emi-release-3.0.0-2.el5.noarch.rpm
yum localinstall --nogpgcheck -y emi-release-3.0.0-2.el5.noarch.rpm

# install the storm repo
wget $WGET_OPTIONS $STORM_REPO -O /etc/yum.repos.d/storm.repo

# install
yum clean all

# setup storm user
adduser -r storm

# install storm packages
yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp emi-storm-gridhttps-mp

# install yaim configuration
sh ./install-yaim-configuration.sh

# do yaim
/opt/glite/yaim/bin/yaim -c -s /etc/storm/siteinfo/storm.def \
    -n se_storm_backend \
    -n se_storm_frontend \
    -n se_storm_gridftp \
    -n se_storm_gridhttps

# run post-installation config script
sh ./post-config-setup.sh

