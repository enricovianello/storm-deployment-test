#!/bin/bash
set -ex
trap "exit 1" TERM

# install pgp-key
rpm --import http://repository.egi.eu/sw/production/umd/UMD-RPM-PGP-KEY
# get repos
wget http://repository.egi.eu/sw/production/umd/3/repofiles/sl6/UMD-3-base.repo -O /etc/yum.repos.d/UMD-3-base.repo
wget http://repository.egi.eu/sw/production/umd/3/repofiles/sl6/UMD-3-updates.repo -O /etc/yum.repos.d/UMD-3-updates.repo

# clean
yum clean all