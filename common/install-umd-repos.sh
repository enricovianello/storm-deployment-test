#!/bin/bash
set -ex
trap "exit 1" TERM

# install pgp-key
rpm --import http://repository.egi.eu/sw/production/umd/UMD-RPM-PGP-KEY
# install UMD repos
yum install -y ${UMD_RELEASE_RPM}

# We want to give more priority to the StoRM Repository than UMD
sed -i "s/priority=1/priority=2/" /etc/yum.repos.d/UMD-4-base.repo /etc/yum.repos.d/UMD-4-updates.repo

# clean
yum clean all