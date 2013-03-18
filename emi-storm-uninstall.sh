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

echo "StoRM 1.11 uninstall.."

execute "yum erase -y storm-xmlrpc-c storm-xmlrpc-c-client emi-storm-gridhttps-mp storm-dynamic-info-provider storm-globus-gridftp-server yaim-storm storm-gridhttps-server emi-storm-frontend-mp storm-backend-server emi-storm-backend-mp storm-frontend-server emi-storm-globus-gridftp-mp storm-gridhttps-plugin storm-pre-assembled-configuration"
execute "userdel gridhttps"
execute "groupdel gridhttps"
execute "userdel storm"
execute "groupdel storm"
execute "rm -rf /var/log/storm"
execute "rm -rf /etc/storm"
execute "yum erase -y emi-release"
execute "yum erase -y epel-release"
execute "rm $egi_trustanchors_file"
execute "yum clean all"

echo "StoRM 1.11 uninstall - terminated"
