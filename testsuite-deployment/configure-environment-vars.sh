#!/bin/bash

userid=$(id -u $(whoami))
export X509_USER_PROXY=/tmp/x509up_u$userid
export SRM_PATH=/opt/d-cache/srm
export PATH=$PATH:/opt/d-cache/srm

echo "X509_USER_PROXY=$X509_USER_PROXY"
echo "SRM_PATH=$SRM_PATH"
echo "PATH=$PATH"

exit 0
