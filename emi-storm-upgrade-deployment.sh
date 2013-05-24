#!/bin/bash

# This script executes an upgrade deployment of StoRM. It is supposed to run on a machine
# with a working StoRM deployment.
# It needs the following environment variables:
#   PLATFORM : available values SL5 or SL6
#   ADDITIONAL_REPO : the URI of the repo to use for StoRM and emi components installation
#
trap "exit 1" TERM
export TOP_PID=$$

execute_no_check(){
	echo "[root@`hostname` ~]# $1"
	eval "$1"
}

execute() {
	echo "[root@`hostname` ~]# $1"
	eval "$1"
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "Deployment failed";
		kill -s TERM $TOP_PID
	fi
}

# check env variables
platform=$PLATFORM
if [ -z "$platform" ]; then
	echo "Please set the PLATFORM env variable! Available values: SL5 or SL6"
	exit 1
fi
if [ ! \( $platform == "SL5" -o $platform == "SL6" \) ]; then
	echo "PLATFORM value '$platform' not valid"
	exit 1
fi

echo "PLATFORM=$platform"

extra_repo=$ADDITIONAL_REPO

# emi-release paths
emi_release="emi-release-3.0.0-2"
if [ $platform == "SL5" ]; then
	emi_release_rpm="$emi_release.el5.noarch.rpm"
	emi_release_remote_rpm="http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl5/x86_64/base/$emi_release.el5.noarch.rpm"
else
	emi_release_rpm="$emi_release.el6.noarch.rpm"
	emi_release_remote_rpm="http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl6/x86_64/base/$emi_release.el6.noarch.rpm"
fi

# storm.def locations
local_storm_def="/etc/storm/siteinfo/storm.def"

update_storm() {
    execute "yum update -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp emi-storm-gridhttps-mp"
}

configure_storm() {
    # download configuration files
    local storm_deployment_repo="https://raw.github.com/italiangrid/storm-deployment-test"
    local branch="master"
    local siteinfo_dir="/etc/storm/siteinfo"
    execute "mkdir -p $siteinfo_dir/vo.d"
    execute "wget $storm_deployment_repo/$branch/siteinfo/vo.d/testers.eu-emi.eu -O $siteinfo_dir/vo.d/testers.eu-emi.eu"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm.def -O $siteinfo_dir/storm.def"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm-users.conf -O $siteinfo_dir/storm-users.conf"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm-groups.conf -O $siteinfo_dir/storm-groups.conf"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm-wn-list.conf -O $siteinfo_dir/storm-wn-list.conf"
    # set java location on SL6
    if [ $platform == "SL6" ]; then
        local java_location="\/usr\/lib\/jvm\/java"
        replace_file_key_value $local_storm_def "JAVA_LOCATION" $java_location
        echo "set JAVA_LOCATION as $java_location"
    fi
}

replace_file_key_value() {
    local CONFIG_FILE=$1
    local TARGET_KEY=$2
    local REPLACEMENT_VALUE=$3
    execute "sed -c -i \"s/\($TARGET_KEY *= *\).*/\1$REPLACEMENT_VALUE/\" $CONFIG_FILE"
}

do_yaim() {
    local profiles="-n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_gridhttps"
    execute "/opt/glite/yaim/bin/yaim -c -d 6 -s $local_storm_def $profiles"
}

# hostname
hostname=$(hostname -f)

echo "StoRM upgrade deployment started on $hostname!"

# install StoRM
update_storm

# base configuration
configure_storm

# execute yaim
do_yaim

echo "StoRM Deployment finished!"
exit 0
