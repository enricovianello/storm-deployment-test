yum erase -y storm-xmlrpc-c storm-xmlrpc-c-client emi-storm-gridhttps-mp storm-dynamic-info-provider storm-globus-gridftp-server yaim-storm storm-gridhttps-server emi-storm-frontend-mp storm-backend-server emi-storm-backend-mp storm-frontend-server emi-storm-globus-gridftp-mp storm-gridhttps-plugin storm-pre-assembled-configuration
userdel gridhttps
groupdel gridhttps
userdel storm
groupdel storm
rm -rf /var/log/storm
rm -rf /etc/storm
yum erase -y emi-release
yum erase -y epel-release
