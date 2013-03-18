# StoRM uninstall script

execute() {
  echo "[root@`hostname` ~]# $1"
  eval "$1"
  exit_status=$?
  if [ $exit_status -ne 0 ]; then
  echo "Deployment failed"; 
	kill -s TERM $TOP_PID
  fi
}

egi_trustanchors_file="/etc/yum.repos.d/EGI-trustanchors.repo"
emi_repo_filename="/etc/yum.repos.d/test_emi.repo"

log_directory="/var/log/storm"
conf_directory="/etc/storm"
lib_directory="/var/lib/storm"

echo "StoRM 1.11 uninstall.."

execute "yum erase -y storm-xmlrpc-c storm-xmlrpc-c-client emi-storm-gridhttps-mp storm-dynamic-info-provider storm-globus-gridftp-server yaim-storm storm-gridhttps-server emi-storm-frontend-mp storm-backend-server emi-storm-backend-mp storm-frontend-server emi-storm-globus-gridftp-mp storm-gridhttps-plugin storm-pre-assembled-configuration"

if id -u gridhttps >/dev/null 2>&1
then
	#exists:
	execute "userdel gridhttps"
	execute "groupdel gridhttps"
fi
if id -u storm >/dev/null 2>&1
then
	#exists:
	execute "userdel storm"
	execute "groupdel storm"
fi

if [ -d $log_directory ]; then
	execute "rm -rf $log_directory"
fi
if [ -d $conf_directory ]; then
	execute "rm -rf $conf_directory"
fi
if [ -d $lib_directory ]; then
	execute "rm -rf $lib_directory"
fi

execute "yum erase -y emi-release"
execute "yum erase -y epel-release"

if [ -e $egi_trustanchors_file ]; then
	execute "rm $egi_trustanchors_file"
fi
if [ -e $emi_repo_filename ]; then
	execute "rm $emi_repo_filename"
fi
execute "yum clean all"

echo "StoRM 1.11 uninstall - terminated"
