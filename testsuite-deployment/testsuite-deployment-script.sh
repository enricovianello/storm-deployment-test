#!/bin/bash

# This script execute a clean deployment of the StoRM testsuite environment on a Scientific Linux os.
# It needs the following environment variables:
#   PLATFORM : available values SL5 or SL6
#   ADDITIONAL_REPO : (optional) the URI of the repo to use for StoRM and emi components installation
#

trap "exit 1" TERM
export TOP_PID=$$

dcache_srmclient_remote_rpm="http://www.dcache.org/downloads/1.9/srm/dcache-srmclient-1.9.5-23.noarch.rpm"

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

get_environment_variables() {
    emi_release_remote_rpm=$EMI_RELEASE_RPM
    epel_release_remote_rpm=$EPEL_RELEASE_RPM
    additional_repo=$ADDITIONAL_REPO
    egi_trustanchors_repo=$EGI_TRUSTANCHORS_REPO
    igi_test_ca_repo=$IGI_TEST_CA_REPO
    robot_framework_version=$ROBOT_FRAMEWORK_VERSION
}

print_configuration() {
    echo "ADDITIONAL_REPO = $additional_repo"
    echo "EMI_RELEASE_RPM = $emi_release_remote_rpm"
    echo "EPEL_RELEASE_RPM = $epel_release_remote_rpm"
    echo "IGI_TEST_CA_REPO = $igi_test_ca_repo"
    echo "EGI_TRUSTANCHORS_REPO = $egi_trustanchors_repo"
    echo "ROBOT_FRAMEWORK_VERSION = $robot_framework_version"
}

# host's private key and public certificate
hostcert_path="/etc/grid-security/hostcert.pem"
hostkey_path="/etc/grid-security/hostkey.pem"

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
	# update egi repo
    add_repo $egi_trustanchors_repo
    # igi-test-ca repo
    add_repo $igi_test_ca_repo
	# additional repo
	if [ ! -z "$additional_repo" ]; then
		echo "ADDITIONAL_REPO=$additional_repo"
        add_repo $additional_repo
	fi
	# refresh yum
	execute "yum clean all"
}

install_robot_framework() {

    local remote_url="https://robotframework.googlecode.com/files/robotframework-$1.tar.gz"
    execute "wget $remote_url -O $HOME/robotframework-$1.tar.gz"
    execute "tar -xzf $HOME/robotframework-$1.tar.gz"
    execute "cd $HOME/robotframework-$1"
    execute "python setup.py install"

}

install_prerequisites() {
    # wget
    execute "yum install -y wget"
}

remove_dcache_srmclient_if_necessary() {
    local current=$(rpm -qa | grep dcache-srmclient)
    if [ $current == "dcache-srmclient-1.9.5-23" ]
        then
            echo "Your dcache-srmclient version is supported! Nothing to do."
        else
            echo "Your dcache-srmclient version is NOT supported! I'm removing it..."
            execute "yum remove -y dcache-srmclient"
    fi
}

install_all() {

	# epel-release
	localinstall_rpm $epel_release_remote_rpm
	# emi-release
	localinstall_rpm $emi_release_remote_rpm
	# igi-test-ca
    execute "yum install -y igi-test-ca"
	# java
	execute "yum install -y java-1.6.0-openjdk"
	# git
	execute "yum install -y git"
	# openldap-clients
	execute "yum install -y openldap-clients"
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
    remove_dcache_srmclient_if_necessary
    localinstall_rpm $dcache_srmclient_remote_rpm
    # python
    execute "yum install -y python"
	# robot-framework
    install_robot_framework $robot_framework_version
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

add_profile_script() {
    local remoteurl="https://raw.github.com/italiangrid/storm-deployment-test/master/testsuite-deployment/grid.sh"
    execute "wget $remoteurl -O /etc/profile.d/grid.sh"
    execute "source /etc/profile.d/grid.sh"
}

# hostname
hostname=$(hostname -f)

echo "StoRM-testsuite deployment started on $hostname!"

# init
get_environment_variables
print_configuration

# prerequisites
install_prerequisites

# configure repositories
update_repositories

# install
install_all

# configure voms clients
configure_voms_clients

# configure environment
add_profile_script

echo "StoRM-testsuite deployment finished!"
exit 0
