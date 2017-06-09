#!/bin/bash
set -ex
trap "exit 1" TERM

yum remove -y storm-gridhttps-plugin
yum remove -y java-1.6.0-openjdk java-1.7.0-openjdk java-1.7.0-openjdk-devel

# update namespace schema

cd /etc/storm/backend-server
mv namespace-1.5.0.xsd namespace-1.5.0.xsd.old
mv namespace-1.5.0.xsd.rpmnew namespace-1.5.0.xsd