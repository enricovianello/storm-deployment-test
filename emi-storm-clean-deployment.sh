#!/bin/bash
 
# This script execute a clean deployment of the StoRM on a Scientific Linux os. 
# It needs the following environment variables:
#   PLATFORM : available values SL5 or SL6
#   DEFAULT_EMI_REPO : the URI of the repo to use for StoRM and emi components installation
#
trap "exit 1" TERM
export TOP_PID=$$

# check env variables
platform=$PLATFORM
if [ -z "$platform" ]; then 
  echo "Please set the PLATFORM env variable! Available values: SL5 or SL6"
	exit 1
fi
if [ ! \( $platform = "SL5" -o $platform = "SL6" \) ]; then
	echo "PLATFORM value '$platform' not valid"
	exit 1
fi
echo "PLATFORM=$platform"

emi_repo=$DEFAULT_EMI_REPO
emi_repo_filename="/etc/yum.repos.d/test_emi.repo"
if [ -z "$emi_repo" ]; then 
	echo "Please set the DEFAULT_EMI_REPO env variable!"
	exit 1
fi
echo "DEFAULT_EMI_REPO=$emi_repo"

# init

# host's private key and public certificate
hostcert_path="/etc/grid-security/hostcert.pem"
hostkey_path="/etc/grid-security/hostkey.pem"

# egi-trustenchors repo link and destination file path
egi_trustanchors_repo="http://repository.egi.eu/sw/production/cas/1/current/repo-files/EGI-trustanchors.repo"
egi_trustanchors_file="/etc/yum.repos.d/EGI-trustanchors.repo"

# epel-release paths
if [ $platform = "SL5" ]; then
	epel_release="epel-release-5-4"
	epel_release_rpm="http://archives.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm"
else 
	epel_release="epel-release-6-8"
	epel_release_rpm="http://www.nic.funet.fi/pub/mirrors/fedora.redhat.com/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm"	
fi

# emi-release paths
#emi_release="emi-release-3.0.0-2"
#if [ $platform = "SL5" ]; then
#	emi_release_rpm="$emi_release.el5.noarch.rpm"
#	emi_release_remote_rpm="http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl5/x86_64/base/$emi_release.el5.noarch.rpm"
#else 
#	emi_release_rpm="$emi_release.el6.noarch.rpm"
#	emi_release_remote_rpm="http://emisoft.web.cern.ch/emisoft/dist/EMI/3/sl6/x86_64/base/$emi_release.el6.noarch.rpm"	
#fi

# storm.def location
storm_def_file="/etc/storm/siteinfo/storm.def"

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

set_users() {
	# storm user
	if id -u storm >/dev/null 2>&1
	then
		#exists:
		local storm_uid=$(id -u storm);
		echo "user storm exists with uid = $storm_uid"
	else
		#not exists: create
		execute "useradd -M storm"
	fi
	execute "chown -R storm:storm /var/log/storm /etc/storm"
	# gridhttps user
	if id -u gridhttps >/dev/null 2>&1
	then
		echo "user gridhttps exists"
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

check_acl() {
	if ! type "getfacl" > /dev/null 2>&1
	then
  		echo "acl not installed"
  		# install acl
  		execute "yum install -y acl"
  	else
  		echo "acl installed"
	fi
}

check_attr() {
	if ! type "getfattr" > /dev/null 2>&1
	then
  		echo "attr not installed"
  		# install attr
  		execute "yum install -y attr"
  	else
  		echo "attr installed"
	fi
}

check_epel() {
	# check if installed
	if rpm -qa | grep $epel_release > /dev/null 2>&1
	then 
		# nothing to do
		echo "$epel_release already installed"
	else 
		# download & install
		execute "wget $epel_release_rpm"
		execute "yum localinstall --nogpgcheck $epel_release.noarch.rpm -y"
		echo "$epel_release installed"
	fi
}

check_emi_release() {
	# check if installed

	# install emi-release package
	execute 'yum -y install emi-release'
	
	#if rpm -qa | grep $emi_release > /dev/null 2>&1
	#then 
	#	# nothing to do
	#	echo "$emi_release already installed"
	#else 
	#	# download & install
	#	execute "wget $emi_release_remote_rpm"
	#	execute "yum localinstall --nogpgcheck $emi_release_rpm -y"
	#	echo "$emi_release installed"
	#fi
}

update_egi_repo() {
	execute "wget $egi_trustanchors_repo -O $egi_trustanchors_file"
}

check_prerequisites() {
	echo "Checking pre-requisites..."
	# check if ntpd is running
	check_ntpd
	# check if hostkey and hostcert exist
	check_keys $hostkey_path $hostcert_path
	# check if acl is installed
	check_acl
	# check if attr is installed
	check_attr
	# check if epel-release is installed, in case install
	check_epel
	# check if emi-release is installed, in case install
	check_emi_release
	# update egi repo
	update_egi_repo
	# refresh yum
	execute "yum clean all"
	echo "Checking pre-requisites... OK"
}

install_all() {
	# ca-policy-egi-core
	execute "yum install -y ca-policy-egi-core"
	# StoRM metapackages
	execute "yum install -y emi-storm-backend-mp emi-storm-frontend-mp emi-storm-globus-gridftp-mp emi-storm-gridhttps-mp"
	# StoRM pre-assembled configuration
	execute "yum install -y storm-pre-assembled-configuration"
}

base_configuration() {
	local output_file=$1
	# set backend hostname
	replace_file_key_value $storm_def_file "STORM_BACKEND_HOST" $hostname
	echo "set STORM_BACKEND_HOST as $hostname"
	# set java location on SL6
	if [ $platform = "SL6" ]; then
		local java_location="\/usr\/lib\/jvm\/java"
		replace_file_key_value $output_file "JAVA_LOCATION" $java_location
		echo "set JAVA_LOCATION as $java_location"
	fi
	# set gridhttps uid and gid
	gridhttps_uid=$(id -u gridhttps)
	replace_file_key_value $output_file "STORM_GRIDHTTPS_SERVER_USER_UID" $gridhttps_uid
	echo "set STORM_GRIDHTTPS_SERVER_USER_UID as $gridhttps_uid"
	gridhttps_gid=$(id -g gridhttps)
	replace_file_key_value $output_file "STORM_GRIDHTTPS_SERVER_GROUP_UID" $gridhttps_gid
	echo "set STORM_GRIDHTTPS_SERVER_GROUP_UID as $gridhttps_gid"
}

replace_file_key_value() {
	local CONFIG_FILE=$1
	local TARGET_KEY=$2
	local REPLACEMENT_VALUE=$3
	execute "sed -c -i \"s/\($TARGET_KEY *= *\).*/\1$REPLACEMENT_VALUE/\" $CONFIG_FILE"	
}

do_yaim() {
	local config_file=$1
	profiles="-n se_storm_backend -n se_storm_frontend -n se_storm_gridftp -n se_storm_gridhttps"
	execute "/opt/glite/yaim/bin/yaim -c -d 6 -s $config_file $profiles"
}


# hostname
hostname=$(hostname -f)

echo "StoRM 1.11 Deployment started on $hostname!"

# add storm and gridhttps users
set_users

# check installation pre-requisites
check_prerequisites

# install StoRM
install_all

# base configuration
base_configuration $storm_def_file

# configuration for vm-storage-02
add_tape_storage_area $storm_def_file

# execute yaim
do_yaim $storm_def_file

echo "StoRM 1.11 Deployment finished!"
