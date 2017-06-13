#!/bin/bash
set -ex
trap "exit 1" TERM

chmod +x clean-cdmi-deployment_centos6.sh
./clean-cdmi-deployment_centos6.sh $1 $2 $3