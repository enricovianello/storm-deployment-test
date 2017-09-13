#!/bin/bash
set -ex
trap "exit 1" TERM

# install the storm repo
wget --no-check-certificate $STORM_REPO -O /etc/yum.repos.d/storm.repo

# clean
yum clean all