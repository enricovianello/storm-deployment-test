#!/bin/bash
set -ex
trap "exit 1" TERM

# Removed no more used stuff
yum remove -y storm-gridhttps-plugin
yum remove -y java-1.6.0-openjdk java-1.7.0-openjdk java-1.7.0-openjdk-devel

# Update namespace schema
cd /etc/storm/backend-server
if [ -a "namespace-1.5.0.xsd.rpmnew" ]; then
    echo "Found namespace-1.5.0.xsd.rpmnew ..."
    mv namespace-1.5.0.xsd namespace-1.5.0.xsd.saved
    mv namespace-1.5.0.xsd.rpmnew namespace-1.5.0.xsd
fi
