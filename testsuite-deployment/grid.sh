#!/bin/bash

userid=$(id -u $(whoami))
export X509_USER_PROXY=/tmp/x509up_u$userid
export JAVA_HOME="/usr/bin/java"
export SRM_PATH=/opt/d-cache/srm
export PATH=$PATH:/opt/d-cache/srm/bin
export LD_LIBRARY_PATH=/opt/d-cache/dcap/lib64
