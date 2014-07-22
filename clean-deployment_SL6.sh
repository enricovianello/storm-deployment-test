#!/bin/bash

WGET_OPTIONS="--no-check-certificate"

# This script execute a clean deployment of StoRM

trap "exit 1" TERM
set -ex

# use the STORM_REPO env variable for the repo, or default to the develop repo
STORM_REPO=${STORM_REPO:-http://radiohead.cnaf.infn.it:9999/view/REPOS/job/repo_storm_develop_SL6/lastSuccessfulBuild/artifact/storm_develop_sl6.repo}

# use the STORM_DEF env variable for the site configuration file, or default
STORM_DEF=${STORM_DEF:-https://raw.github.com/italiangrid/storm-deployment-test/master/siteinfo/storm.def}

# use the STORM_DEPLOYMENT_TEST_BRANCH env variable, or default
STORM_DEPLOYMENT_TEST_BRANCH=${STORM_DEPLOYMENT_TEST_BRANCH:-master}

# install emi-release
wget $WGET_OPTIONS http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl6/x86_64/base/emi-release-3.0.0-2.el6.noarch.rpm
yum localinstall --nogpgcheck -y emi-release-3.0.0-2.el6.noarch.rpm

# install the storm repo
wget $WGET_OPTIONS $STORM_REPO -O /etc/yum.repos.d/storm.repo

# install
yum clean all
yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp emi-storm-gridhttps-mp

# add some users
adduser -r storm

# download siteinfo file
mkdir -p /etc/storm/siteinfo/vo.d
wget $WGET_OPTIONS $STORM_DEF -O /etc/storm/siteinfo/storm.def
wget $WGET_OPTIONS https://raw.github.com/italiangrid/storm-deployment-test/$STORM_DEPLOYMENT_TEST_BRANCH/siteinfo/vo.d/testers.eu-emi.eu -O /etc/storm/siteinfo/vo.d/testers.eu-emi.eu
wget $WGET_OPTIONS https://raw.github.com/italiangrid/storm-deployment-test/$STORM_DEPLOYMENT_TEST_BRANCH/siteinfo/vo.d/dteam -O /etc/storm/siteinfo/vo.d/dteam
wget $WGET_OPTIONS https://raw.github.com/italiangrid/storm-deployment-test/$STORM_DEPLOYMENT_TEST_BRANCH/siteinfo/storm-users.conf -O /etc/storm/siteinfo/storm-users.conf
wget $WGET_OPTIONS https://raw.github.com/italiangrid/storm-deployment-test/$STORM_DEPLOYMENT_TEST_BRANCH/siteinfo/storm-groups.conf -O /etc/storm/siteinfo/storm-groups.conf
wget $WGET_OPTIONS https://raw.github.com/italiangrid/storm-deployment-test/$STORM_DEPLOYMENT_TEST_BRANCH/siteinfo/storm-wn-list.conf -O /etc/storm/siteinfo/storm-wn-list.conf

# do yaim
/opt/glite/yaim/bin/yaim -c -d 6 -s /etc/storm/siteinfo/storm.def -n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_gridhttps
