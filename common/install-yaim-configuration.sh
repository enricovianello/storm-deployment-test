#!/bin/bash
set -ex
trap "exit 1" TERM

VERSION=$1

rm -rf /etc/storm/siteinfo
mkdir -p /etc/storm/siteinfo

cp -r ../siteinfo/${VERSION}/* /etc/storm/siteinfo
