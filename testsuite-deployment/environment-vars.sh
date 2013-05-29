#!/bin/bash
userid=$(id -u $(whoami))
export X509_USER_PROXY=/tmp/x509up_u$userid
export SRM_PATH=/opt/d-cache/srm
export PATH=$PATH:SRM_PATH
