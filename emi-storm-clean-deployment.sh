#!/bin/bash

# This script execute a clean deployment of the StoRM on a Scientific Linux os.
# It needs the following environment variables:
#   ADDITIONAL_REPO             : the URI of the repo to use for StoRM and emi components installation
#   EMI_RELEASE_REMOTE_RPM      : (MANDATORY) the URI of the EMI release rpm
#   EPEL_RELEASE_REMOTE_RPM     : (MANDATORY) the URI of the EPEL release rpm
#   YAIM_CONFIGURATION_FILE     : the URI of the 'storm.def' file with yaim configuration values
#   REQUIRED_STORM_UID          : the required user-id for storm user
#   REQUIRED_STORM_GID          : the required user-gid for storm user
#   IGI_TEST_CA_REMOTE_RPM      : the URI of the IGI-test-CA rpm
#   EGI_TRUSTANCHORS_REPO       : the URI of the EGI-trustanchors repo
#   JAVA_LOCATION               : specify a different java location
#   FS_TYPE                     : values: DISK or GPFS (default: DISK)
#
trap "exit 1" TERM
export TOP_PID=$$

remote_siteinfo_dir="https://raw.github.com/italiangrid/storm-deployment-test/master/siteinfo"
default_egi_trustanchors_repo="http://repository.egi.eu/sw/production/cas/1/current/repo-files/EGI-trustanchors.repo"
default_gpfs_repo="http://radiohead.cnaf.infn.it:9999/job/repo_gpfs/3/artifact/gpfs.repo"
default_igi_test_ca_remote_rpm="http://radiohead.cnaf.infn.it:9999/job/test-ca/os=SL5_x86_64/lastSuccessfulBuild/artifact/igi-test-ca/rpmbuild/RPMS/noarch/igi-test-ca-1.0.2-2.noarch.rpm"
default_yaim_configuration_file="$remote_siteinfo_dir/storm.def"
default_fs_type="DISK"

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
    epel_release_remote_rpm=$EPEL_RELEASE_REMOTE_RPM
    egi_trustanchors_repo=$EGI_TRUSTANCHORS_REPO
    igi_test_ca_remote_rpm=$IGI_TEST_CA_REMOTE_RPM
    java_location=$JAVA_LOCATION
    yaim_configuration_file=$YAIM_CONFIGURATION_FILE
    required_storm_uid=$REQUIRED_STORM_UID
    required_storm_gid=$REQUIRED_STORM_GID
    fs_type=$FS_TYPE
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
    # epel-release
    if [ -z "$epel_release_remote_rpm" ]; then
        echo "Please set the EPEL_RELEASE_REMOTE_RPM environment variable!"
        exit 1
    fi
    echo "EPEL_RELEASE_REMOTE_RPM = $epel_release_remote_rpm"
    # egi-trustanchors repo
    if [ -z "$egi_trustanchors_repo" ]; then
        egi_trustanchors_repo=$default_egi_trustanchors_repo
    fi
    echo "EGI_TRUSTANCHORS_REPO = $egi_trustanchors_repo"
    # igi-test-ca
    if [ -z "$igi_test_ca_remote_rpm" ]; then
        igi_test_ca_remote_rpm=$default_igi_test_ca_remote_rpm
    fi
    echo "IGI_TEST_CA_REMOTE_RPM = $igi_test_ca_remote_rpm"
    # java location
    echo "JAVA_LOCATION = $java_location"
    # yaim configuration file
    if [ -z "$yaim_configuration_file" ]; then
        yaim_configuration_file=$default_yaim_configuration_file
    fi
    echo "YAIM_CONFIGURATION_FILE = $yaim_configuration_file"
    # storm uid and gid
    echo "REQUIRED_STORM_UID = $required_storm_uid"
    echo "REQUIRED_STORM_GID = $required_storm_gid"
    # fs type
    if [ -z "$fs_type" ]; then
        fs_type=$default_fs_type
    fi
    echo "FS_TYPE = $fs_type"
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
    # create gridhttps user if not exists
    if id -u gridhttps >/dev/null 2>&1
    then
        echo "gridhttps user already exists"
    else
        execute "useradd gridhttps -M -G storm"
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
    if [ ! -z "$additional_repo" ]; then
        add_repo $additional_repo
    fi
    if [ $fs_type -eq "GPFS" ]; then
        add_repo $default_gpfs_repo
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
    # igi-test-ca
    localinstall_rpm $igi_test_ca_remote_rpm
    # ca-policy-egi-core
    execute "yum install -y ca-policy-egi-core"
    # gpfs libraries
    if [ $fs_type -eq "GPFS" ]; then
        execute "yum install gpfs.base"
    fi
    # StoRM metapackages
    execute "yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp emi-storm-gridhttps-mp"
}

configure() {
    local siteinfo_dir="/etc/storm/siteinfo"
    # download main configuration file
    execute "wget $yaim_configuration_file -O $siteinfo_dir/storm.def"
    # download vo files
    local storm_deployment_repo="https://raw.github.com/italiangrid/storm-deployment-test"
    local branch="master"
    execute "wget $remote_siteinfo_dir/vo.d/testers.eu-emi.eu -O $siteinfo_dir/vo.d/testers.eu-emi.eu"
    # download storm users, groups and wn-list
    execute "wget $remote_siteinfo_dir/storm-users.conf -O $siteinfo_dir/storm-users.conf"
    execute "wget $remote_siteinfo_dir/storm-groups.conf -O $siteinfo_dir/storm-groups.conf"
    execute "wget $remote_siteinfo_dir/storm-wn-list.conf -O $siteinfo_dir/storm-wn-list.conf"    
    if [ ! -z $java_location ]; then
        local storm_def_file="$siteinfo_dir/storm.def"
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
    local profiles="-n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_gridhttps"
    execute "/opt/glite/yaim/bin/yaim -c -s $siteinfo_dir/storm.def $profiles"
}

# hostname
hostname=$(hostname -f)

echo "StoRM Deployment started on $hostname!"

# init from environment variables
get_environment_variables
check_environment_variables

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
