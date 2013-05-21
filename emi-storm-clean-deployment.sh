#!/bin/bash

# This script execute a clean deployment of the StoRM on a Scientific Linux os.
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

# init

# host's private key and public certificate
hostcert_path="/etc/grid-security/hostcert.pem"
hostkey_path="/etc/grid-security/hostkey.pem"

# egi-trustenchors repo link and destination file path
egi_trustanchors_repo="http://repository.egi.eu/sw/production/cas/1/current/repo-files/EGI-trustanchors.repo"
egi_trustanchors_file="/etc/yum.repos.d/EGI-trustanchors.repo"

# epel-release paths
if [ $platform == "SL5" ]; then
	epel_release="epel-release-5-4"
	epel_release_rpm="http://archives.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm"
else
	epel_release="epel-release-6-8"
	epel_release_rpm="http://www.nic.funet.fi/pub/mirrors/fedora.redhat.com/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm"
fi

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

#igi-test-ca rpm
remote_igi_test_ca_rpm="http://radiohead.cnaf.infn.it:9999/job/test-ca/os=SL5_x86_64/lastSuccessfulBuild/artifact/igi-test-ca/rpmbuild/RPMS/noarch/igi-test-ca-1.0.2-2.noarch.rpm"
local_igi_test_ca_rpm="igi-test-ca-1.0.2-2.noarch.rpm";

set_users() {
	# storm user
	if id -u storm >/dev/null 2>&1
	then
		#exists:
		local storm_uid=$(id -u storm);
		echo "user storm exists with uid = $storm_uid"
	else
		#not exists: create
		echo "user storm does not exist"
		execute "useradd -M storm"
		echo "user storm created"
	fi
	if [ -d "/var/log/storm" ]; then
		execute "chown -R storm:storm /var/log/storm"
	fi
	if [ -d "/etc/storm" ]; then
		execute "chown -R storm:storm /etc/storm"
	fi
	# gridhttps user
	if id -u gridhttps >/dev/null 2>&1
	then
		local gridhttps_uid=$(id -u gridhttps);
		echo "user gridhttps exists with uid = $gridhttps_uid"
	else
		echo "user gridhttps does not exist"
		execute "useradd gridhttps -M -G storm"
		echo "user gridhttps created"
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

check_keys() {
	local key=$1
	local cert=$2
	if [ ! -f $cert ]; then
		echo "$cert does not exists"
		exit 1
	fi
    echo "$cert exists"
    if [ ! -f $key ]; then
        echo "$key does not exists"
        exit 1
    fi
    echo "$key exists"
}

install_epel() {
    # check if installed
    if rpm -qa | grep $epel_release > /dev/null 2>&1
    then
        # nothing to do
        echo "$epel_release already installed"
    else
        # download & install
        execute "wget $epel_release_rpm"
        execute "yum localinstall --nogpgcheck $epel_release.noarch.rpm -y"
        execute "rm $epel_release.noarch.rpm"
        echo "$epel_release installed"
    fi
}

install_emi_release() {
    # check if installed
    if rpm -qa | grep $emi_release > /dev/null 2>&1
    then
        # nothing to do
        echo "$emi_release already installed"
    else
        # download & install
        execute "wget $emi_release_remote_rpm"
        execute "yum localinstall --nogpgcheck $emi_release_rpm -y"
        execute "rm $emi_release_rpm"
        echo "$emi_release installed"
    fi
}

check_prerequisites() {
    echo "Checking pre-requisites..."
    # check if ntpd is running
    check_ntpd
    # check if hostkey and hostcert exist
    check_keys $hostkey_path $hostcert_path
    echo "Checking pre-requisites... OK"
}

update_repositories() {
    # update egi repo
    execute "wget $egi_trustanchors_repo -O $egi_trustanchors_file"
    # additional repo
    if [ -z "$extra_repo" ]; then
        echo "ADDITIONAL_REPO not found!\n** To install last developed StoRM components' versions do:"
        echo "On SL5:\texport ADDITIONAL_REPO=\"http://radiohead.cnaf.infn.it:9999/view/STORM/job/storm-repo_SL5/lastSuccessfulBuild/artifact/storm.repo\""
        echo "On SL6:\texport ADDITIONAL_REPO=\"http://radiohead.cnaf.infn.it:9999/view/STORM/job/storm-repo_SL6/lastSuccessfulBuild/artifact/storm.repo\""
    else
        echo "ADDITIONAL_REPO=$extra_repo"
        local extra_repo_filename=$(basename "$extra_repo")
        local extra_repo_extension="${extra_repo_filename##*.}"
        extra_repo_filename="${extra_repo_filename%.*}"
        # Install additional test repo
        execute "wget -q $extra_repo -O /etc/yum.repos.d/$extra_repo_filename.$extra_repo_extension"
    fi
    # refresh yum
    execute "yum clean all"
}

install_igi_test_ca() {
	# check if installed
    	if rpm -qa | grep "igi-test-ca-1.0.2-2.noarch" > /dev/null 2>&1
    	then
        	# nothing to do
        	echo "$local_igi_test_ca_rpm already installed"
    	else
		echo "$local_igi_test_ca_rpm not installed"
		execute "wget $remote_igi_test_ca_rpm" 
		execute "rpm -ivh $local_igi_test_ca_rpm"
	fi
}

install_storm() {
    # ca-policy-egi-core
    execute "yum install -y ca-policy-egi-core"
    # StoRM metapackages
    execute "yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp emi-storm-gridhttps-mp"
}

configure_storm() {
    # download configuration files
    local storm_deployment_repo="https://raw.github.com/enricovianello/storm-deployment-test"
    local branch="master"
    local siteinfo_dir="/etc/storm/siteinfo"
    execute "mkdir -p $siteinfo_dir/vo.d"
    execute "wget $storm_deployment_repo/$branch/siteinfo/vo.d/testers.eu-emi.eu -O $siteinfo_dir/vo.d/testers.eu-emi.eu"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm.def -O $siteinfo_dir/storm.def"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm-users.conf -O $siteinfo_dir/storm-users.conf"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm-groups.conf -O $siteinfo_dir/storm-groups.conf"
    execute "wget $storm_deployment_repo/$branch/siteinfo/storm-wn-list.conf -O $siteinfo_dir/storm-wn-list.conf"
    # set backend hostname
    replace_file_key_value $local_storm_def "STORM_BACKEND_HOST" $hostname
    echo "set STORM_BACKEND_HOST as $hostname"
    # set java location on SL6
    if [ $platform == "SL6" ]; then
        local java_location="\/usr\/lib\/jvm\/java"
        replace_file_key_value $local_storm_def "JAVA_LOCATION" $java_location
        echo "set JAVA_LOCATION as $java_location"
    fi
    # set gridhttps uid and gid
    local gridhttps_uid=$(id -u gridhttps)
    replace_file_key_value $local_storm_def "STORM_GRIDHTTPS_SERVER_USER_UID" $gridhttps_uid
    echo "set STORM_GRIDHTTPS_SERVER_USER_UID as $gridhttps_uid"
    local gridhttps_gid=$(id -g gridhttps)
    replace_file_key_value $local_storm_def "STORM_GRIDHTTPS_SERVER_GROUP_UID" $gridhttps_gid
    echo "set STORM_GRIDHTTPS_SERVER_GROUP_UID as $gridhttps_gid"
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

echo "StoRM 1.11 Deployment started on $hostname!"

# add storm and gridhttps users
set_users

# check installation pre-requisites
check_prerequisites

# check if epel-release is installed, in case install
install_epel

# check if emi-release is installed, in case install
install_emi_release

# add repositories
update_repositories

# install igi-test-ca
install_igi_test_ca

# install StoRM
install_storm

# base configuration
configure_storm

# execute yaim
do_yaim

echo "StoRM 1.12 Deployment finished!"

