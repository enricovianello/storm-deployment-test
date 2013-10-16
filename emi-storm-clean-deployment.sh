#!/bin/bash

# This script execute a clean deployment of the StoRM on a Scientific Linux os.
# It needs the following environment variables:
#   ADDITIONAL_REPO             : the URI of the repo to use for StoRM and emi components installation
#   EMI_RELEASE_REMOTE_RPM      : (MANDATORY) the URI of the EMI release rpm
#   EPEL_RELEASE_REMOTE_RPM     : (MANDATORY) the URI of the EPEL release rpm
#   YAIM_CONFIGURATION_FILE     : the URI of the 'storm.def' file with yaim configuration values
#   REQUIRED_STORM_UID          : the required user-id for storm user
#   REQUIRED_STORM_GID          : the required user-gid for storm user
#   JAVA_LOCATION               : specify a different java location
#   FS_TYPE                     : values: DISK or GPFS (default: DISK)
#   ENABLE_GRIDHTTPS_SERVER     : values: true|false (default: true)
#
trap "exit 1" TERM
export TOP_PID=$$

remote_siteinfo_dir="https://raw.github.com/italiangrid/storm-deployment-test/master/siteinfo/"

DEFAULT_ENABLE_GRIDHTTPS_SERVER="true"
DEFAULT_YAIM_CONFIGURATION_FILE="$remote_siteinfo_dir/storm.def"
DEFAULT_FS_TYPE="DISK"

egi_trustanchors_repo="http://repository.egi.eu/sw/production/cas/1/current/repo-files/EGI-trustanchors.repo"
gpfs_repo="http://radiohead.cnaf.infn.it:9999/job/repo_gpfs/3/artifact/gpfs.repo"
igi_test_ca_repo="http://radiohead.cnaf.infn.it:9999/view/REPOS/job/repo_test_ca/lastSuccessfulBuild/artifact/test-ca.repo"

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
    
    if [ -f /root/storm-setup.sh ]; then
    	source /root/storm-setup.sh && echo "Succesfully parsed setup file from /root/storm-setup.sh"
    fi
    	
    additional_repo=$ADDITIONAL_REPO
    emi_release_remote_rpm=$EMI_RELEASE_REMOTE_RPM
    epel_release_remote_rpm=$EPEL_RELEASE_REMOTE_RPM
    java_location=$JAVA_LOCATION
    yaim_configuration_file=$YAIM_CONFIGURATION_FILE
    required_storm_uid=$REQUIRED_STORM_UID
    required_storm_gid=$REQUIRED_STORM_GID
    fs_type=$FS_TYPE
    enable_gridhttps_server=$ENABLE_GRIDHTTPS_SERVER
}

check_environment_variables() {
    # emi-release
    if [ -z "$emi_release_remote_rpm" ]; then
        echo "Please set the EMI_RELEASE_REMOTE_RPM environment variable!"
        exit 1
    fi
    # epel-release
    if [ -z "$epel_release_remote_rpm" ]; then
        echo "Please set the EPEL_RELEASE_REMOTE_RPM environment variable!"
        exit 1
    fi
    # yaim configuration file
    if [ -z "$yaim_configuration_file" ]; then
        yaim_configuration_file=$DEFAULT_YAIM_CONFIGURATION_FILE
    fi
    # fs type
    if [ -z "$fs_type" ]; then
        fs_type=$DEFAULT_FS_TYPE
    fi
    # create gridhttps user
    if [ -z "$enable_gridhttps_server" ]; then
        enable_gridhttps_server=$DEFAULT_ENABLE_GRIDHTTPS_SERVER
    fi
}

print_configuration() {
    echo "ADDITIONAL_REPO = $additional_repo"
    echo "JAVA_LOCATION = $java_location"
    echo "REQUIRED_STORM_UID = $required_storm_uid"
    echo "REQUIRED_STORM_GID = $required_storm_gid"
    echo "EMI_RELEASE_REMOTE_RPM = $emi_release_remote_rpm"
    echo "EPEL_RELEASE_REMOTE_RPM = $epel_release_remote_rpm"
    echo "YAIM_CONFIGURATION_FILE = $yaim_configuration_file"
    echo "FS_TYPE = $fs_type"
    echo "ENABLE_GRIDHTTPS_USER = $enable_gridhttps_server"
    echo "IGI_TEST_CA_REPO = $igi_test_ca_repo"
    echo "EGI_TRUSTANCHORS_REPO = $egi_trustanchors_repo"
    echo "GPFS_REPO = $gpfs_repo"
}

set_users() {
	# create storm user if not exists
    if id -u storm >/dev/null 2>&1
    then
        echo "storm user already exists"
    else
        execute "useradd -M storm"
    fi
    # configure them if necessary
    if [ ! -z $required_storm_uid ] || [ ! -z $required_storm_gid ]; then
        local storm_uid=$(id -u storm)
        if [ ! -z $required_storm_uid ]; then
            if [ $storm_uid -ne $required_storm_uid ]; then
                execute "usermod --uid $required_storm_uid storm"
            fi
        fi
        local storm_gid=$(id -g storm)
        if [ ! -z $required_storm_gid ]; then
            if [ $storm_gid -ne $required_storm_gid ]; then
                execute "groupmod -g $required_storm_gid storm"
                execute "usermod --gid $required_storm_gid storm"
            fi
        fi
    fi
    if [ $enable_gridhttps_server == "true" ]; then
    	if id -u gridhttps >/dev/null 2>&1
    	then
        	echo "gridhttps user already exists"
    	else
        	execute "useradd gridhttps -M -G storm"
    	fi
    else
    	echo "gridhttps user creation disabled"
    fi
}

check_ntpd() {
	if ps ax | grep -v grep | grep ntpd > /dev/null
	then
		echo "ntpd service is running"
	else
		echo "ERROR: install or start ntpd service before"
		exit 1
	fi
}

check_host_credentials() {
    # host's private key and public certificate
    local hostcert_path="/etc/grid-security/hostcert.pem"
    local hostkey_path="/etc/grid-security/hostkey.pem"
    if [ ! -f $hostcert_path ]; then
		echo "$hostcert_path does not exists"
		exit 1
	fi
    echo "$hostcert_path exists"
    if [ ! -f $hostkey_path ]; then
        echo "$hostkey_path does not exists"
        exit 1
    fi
    echo "$hostkey_path exists"
}

check_prerequisites() {
    echo "Checking pre-requisites..."
    # check if ntpd is running
    check_ntpd
    # check if hostkey and hostcert exist
    check_host_credentials
    echo "Checking pre-requisites... OK"
}

add_repo() {
    local remote_url=$1
    local local_repo_dir="/etc/yum.repos.d"
    local remote_repo_filename=$(basename "$remote_url")
    local local_repo_path="$local_repo_dir/$remote_repo_filename"
    execute "wget -q $remote_url -O $local_repo_path"
}

update_repositories() {
    localinstall_rpm $epel_release_remote_rpm
    localinstall_rpm $emi_release_remote_rpm
    add_repo $egi_trustanchors_repo
    add_repo $igi_test_ca_repo
    if [ ! -z "$additional_repo" ]; then
        add_repo $additional_repo
    fi
    if [ ! -z "$fs_type" ]; then
        if [ $fs_type -eq "GPFS" ]; then
        	add_repo $gpfs_repo
    	fi
    fi
    # refresh yum
    execute "yum clean all"
}

init_directories() {
    local storm_conf_dir="/etc/storm"
    # create directories
    execute "mkdir -p $storm_conf_dir"
    execute "mkdir -p $storm_conf_dir/siteinfo"
    execute "mkdir -p $storm_conf_dir/siteinfo/vo.d"
    execute "chown -R storm:storm $storm_conf_dir"
    if [ -d "/var/log/storm" ]; then
        execute "chown -R storm:storm /var/log/storm"
    fi
}

localinstall_rpm() {
    local remote_url=$1
    local local_name=$(basename $remote_url)
    execute "wget $remote_url -O /tmp/$local_name"
    execute "yum localinstall --nogpgcheck -y /tmp/$local_name"
    execute "rm -f /tmp/$local_name"
    echo "$local_name installed!"
}

install_all() {
    # ca-policy-egi-core
    execute "yum install -y ca-policy-egi-core"
    # igi-test-ca
    execute "yum install -y igi-test-ca"
    # gpfs libraries
    if [ ! -z "$fs_type" ]; then
        if [ $fs_type -eq "GPFS" ]; then
        	execute "yum install gpfs.base"
    	fi
    fi
    # StoRM metapackages
    execute "yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp"
    if [ $enable_gridhttps_server == "true" ]; then
    	execute "yum install -y emi-storm-gridhttps-mp"
    fi
}

configure() {
    local siteinfo_dir="/etc/storm/siteinfo"
    local storm_def_file="$siteinfo_dir/storm.def"
    # download main configuration file
    execute "wget $yaim_configuration_file -O $storm_def_file"
    if [ $enable_gridhttps_server == "false" ]; then
    	execute "sed -i '/STORM_GRIDHTTPS_SERVER_USER_UID/ d' $storm_def_file"
    	execute "sed -i '/STORM_GRIDHTTPS_SERVER_GROUP_UID/ d' $storm_def_file"
    	replace_file_key_value  $storm_def_file "STORM_GRIDHTTPS_ENABLED" false
    fi
    # download vo files
    local storm_deployment_repo="https://raw.github.com/italiangrid/storm-deployment-test"
    local branch="master"
    execute "wget $remote_siteinfo_dir/vo.d/testers.eu-emi.eu -O $siteinfo_dir/vo.d/testers.eu-emi.eu"
    # download storm users, groups and wn-list
    execute "wget $remote_siteinfo_dir/storm-users.conf -O $siteinfo_dir/storm-users.conf"
    execute "wget $remote_siteinfo_dir/storm-groups.conf -O $siteinfo_dir/storm-groups.conf"
    execute "wget $remote_siteinfo_dir/storm-wn-list.conf -O $siteinfo_dir/storm-wn-list.conf"    
    if [ ! -z $java_location ]; then
        # delete line
        execute "sed -i '/JAVA_LOCATION/ d' $storm_def_file"
        # add line
        execute "echo JAVA_LOCATION=$java_location >> $storm_def_file"
    fi
}

replace_file_key_value() {
    local CONFIG_FILE=$1
    local TARGET_KEY=$2
    local REPLACEMENT_VALUE=$3
    execute "sed -c -i \"s/\($TARGET_KEY *= *\).*/\1$REPLACEMENT_VALUE/\" $CONFIG_FILE"
}

do_yaim() {
    local siteinfo_dir="/etc/storm/siteinfo"
    if [ $enable_gridhttps_server == "true" ]; then
    	local profiles="-n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_gridhttps"
    else
    	local profiles="-n se_storm_backend -n se_storm_frontend -n se_storm_gridftp"
    fi
    execute "/opt/glite/yaim/bin/yaim -c -s $siteinfo_dir/storm.def $profiles"
}




# hostname
hostname=$(hostname -f)

echo "StoRM Deployment started on $hostname!"

# init from environment variables
get_environment_variables
check_environment_variables
print_configuration

# add storm and gridhttps users
set_users

# check installation pre-requisites
check_prerequisites

# add repositories
update_repositories

# init directories
init_directories

# install StoRM
install_all

# base configuration
configure

# execute yaim
do_yaim

echo "StoRM Deployment finished!"
exit 0
