#!/bin/bash

# This script execute a clean deployment of the StoRM testsuite environment on a Scientific Linux os.
# It needs the following environment variables:
#   PLATFORM : available values SL5 or SL6
#   ADDITIONAL_REPO : (optional) the URI of the repo to use for StoRM and emi components installation
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

#igi-test-ca remote rpm
remote_igi_test_ca_rpm="http://radiohead.cnaf.infn.it:9999/job/test-ca/os=SL5_x86_64/lastSuccessfulBuild/artifact/igi-test-ca/rpmbuild/RPMS/noarch/igi-test-ca-1.0.2-2.noarch.rpm"

# robot framework remote tar.gz
remote_robot_framework_targz="https://robotframework.googlecode.com/files/robotframework-2.7.7.tar.gz"

# dcache srm client remote rpm
dcahe_srmclient_remote_rpm="http://www.dcache.org/downloads/1.9/srm/dcache-srmclient-1.9.5-23.noarch.rpm"

update_repositories() {
	# update egi repo
	execute "wget $egi_trustanchors_repo -O $egi_trustanchors_file"
	# additional repo
	if [ ! -z "$extra_repo" ]; then
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
		echo "$emi_release installed"
	fi
}

install_igi_test_ca() {
	if rpm -qa | grep "igi-test-ca-1.0.2-2" > /dev/null 2>&1
	then
		echo "igi-test-ca-1.0.2-2 already installed"
	else
		execute "wget $remote_igi_test_ca_rpm -O igi-test-ca.rpm"
		execute "rpm -ivh igi-test-ca.rpm"
	fi
}

install_all() {
	# check if epel-release is installed, in case install
	install_epel
	# check if emi-release is installed, in case install
	install_emi_release
	# check if igi-test-ca is installed, in case install
	install_igi_test_ca
	# git
	execute "yum install -y git"
	# ca-policy-egi-core
	execute "yum install -y ca-policy-egi-core"
	# globus-gass-copy-progs
	execute "yum install -y globus-gass-copy-progs"
	# clientSRM
	execute "yum install -y emi-storm-srm-client-mp"
	# lcg-utils
	execute "yum install -y lcg-util"
	# voms-clients
	execute "yum install -y voms-clients"
	# dcache-srmclient
	execute "wget $dcahe_srmclient_remote_rpm -O $HOME/dcache-srmclient.rpm"
	execute "yum localinstall -y --nogpgcheck $HOME/dcache-srmclient.rpm"
	# robot-framework
	execute "yum install -y python"
	execute "wget $remote_robot_framework_targz -O $HOME/robot-framework.tar.gz"
	execute "tar -xzf $HOME/robot-framework.tar.gz"
	execute "cd $HOME/robot-framework"
	execute "python setup.py install"
}

configure_voms_clients(){

	# Setup certificate for voms-proxy-init test
	if [ ! -d "$HOME/.globus" ]; then
		execute "mkdir -p $HOME/.globus"
	fi
	execute "cp /usr/share/igi-test-ca/test0.cert.pem $HOME/.globus/usercert.pem"
	execute "cp /usr/share/igi-test-ca/test0.key.pem $HOME/.globus/userkey.pem"
	execute "chmod 600 $HOME/.globus/usercert.pem"
	execute "chmod 400 $HOME/.globus/userkey.pem"
	if [ ! -d "/etc/grid-security/vomsdir" ]; then
		execute "mkdir -p /etc/grid-security/vomsdir"
	fi
	execute "cp /etc/grid-security/hostcert.pem /etc/grid-security/vomsdir"

	# Setup vomsdir & vomses
	# Configure lsc and vomses
	if [ ! -d "/etc/vomses" ]; then
		execute "mkdir /etc/vomses"
	fi
	execute "wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/testers.eu-emi.eu-emitestbed01.cnaf.infn.it -O /etc/vomses/testers.eu-emi.eu-emitestbed01.cnaf.infn.it"
	execute "wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/testers.eu-emi.eu-emitestbed07.cnaf.infn.it -O /etc/vomses/testers.eu-emi.eu-emitestbed07.cnaf.infn.it"
	if [ ! -d "/etc/grid-security/vomsdir/testers.eu-emi.eu" ]; then
		execute "mkdir /etc/grid-security/vomsdir/testers.eu-emi.eu"
	fi
	execute "wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/emitestbed01.cnaf.infn.it.lsc -O /etc/grid-security/vomsdir/testers.eu-emi.eu/emitestbed01.cnaf.infn.it.lsc"
	execute "wget https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/emitestbed07.cnaf.infn.it.lsc -O /etc/grid-security/vomsdir/testers.eu-emi.eu/emitestbed07.cnaf.infn.it.lsc"
	# test basic voms-proxy-init command
	execute "echo 'pass' | voms-proxy-init --pwstdin --cert $HOME/.globus/usercert.pem --key $HOME/.globus/userkey.pem"
	echo "VOMS clients succesfully deployed"
}

replace_file_key_value() {
	local CONFIG_FILE=$1
	local TARGET_KEY=$2
	local REPLACEMENT_VALUE=$3
	execute "sed -c -i \"s/\($TARGET_KEY *= *\).*/\1$REPLACEMENT_VALUE/\" $CONFIG_FILE"
}

# hostname
hostname=$(hostname -f)

echo "StoRM-testsuite deployment started on $hostname!"

# add repositories
update_repositories

# install all
install_all

# configure voms clients
configure_voms_clients

echo "StoRM-testsuite deployment finished!"
exit 0
