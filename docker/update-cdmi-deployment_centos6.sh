#!/bin/bash
set -ex
trap "exit 1" TERM

./clean-cdmi-deployment_centos6.sh $1 $2 $3