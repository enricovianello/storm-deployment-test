#!/bin/bash

# This script execute StoRM upgrade from emi2 to emi3 of on a Scientific Linux os.
# It needs the following environment variables:
#   ADDITIONAL_REPO             : the URI of the repo to use for StoRM and emi components installation
#   EMI_RELEASE_REMOTE_RPM      : (MANDATORY) the URI of the EMI release rpm
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

get_environment_variables() {
    additional_repo=$ADDITIONAL_REPO
    emi_release_remote_rpm=$EMI_RELEASE_REMOTE_RPM
}

check_environment_variables() {
    # additional_repo
    echo "ADDITIONAL_REPO = $additional_repo"
    # emi-release
    if [ -z "$emi_release_remote_rpm" ]; then
        echo "Please set the EMI_RELEASE_REMOTE_RPM environment variable!"
        exit 1
    fi
    echo "EMI_RELEASE_REMOTE_RPM = $emi_release_remote_rpm"
}

add_repo() {
    local remote_url=$1
    local local_repo_dir="/etc/yum.repos.d"
    local remote_repo_filename=$(basename "$remote_url")
    local local_repo_path="$local_repo_dir/$remote_repo_filename"
    execute "wget -q $remote_url -O $local_repo_path"
}

localinstall_rpm() {
    local remote_url=$1
    local local_name=$(basename $remote_url)
    execute "wget $remote_url -O /tmp/$local_name"
    execute "yum localinstall --nogpgcheck -y /tmp/$local_name"
    execute "rm -f /tmp/$local_name"
    echo "$local_name installed!"
}

update_repositories() {
    localinstall_rpm $emi_release_remote_rpm
    if [ ! -z "$additional_repo" ]; then
        add_repo $additional_repo
    fi
    # refresh yum
    execute "yum clean all"
}

update_all() {
    # StoRM update all
    execute "yum update -y"
}

do_yaim() {
    local siteinfo_dir="/etc/storm/siteinfo"
    local profiles="-n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_gridhttps"
    execute "/opt/glite/yaim/bin/yaim -c -s $siteinfo_dir/storm.def $profiles"
}

# hostname
hostname=$(hostname -f)

echo "StoRM Deployment started on $hostname!"

# init from environment variables
get_environment_variables
check_environment_variables

# add repositories
update_repositories

# update StoRM
update_all

# launch yaim
do_yaim

echo "StoRM Deployment finished!"
exit 0
