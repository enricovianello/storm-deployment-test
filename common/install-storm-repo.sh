#!/bin/bash
set -ex
trap "exit 1" TERM

REPO_URL=$1

# install the storm repo
wget --no-check-certificate $REPO_URL -O /etc/yum.repos.d/storm.repo

# clean
yum clean all