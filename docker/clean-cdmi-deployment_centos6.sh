#!/bin/bash
set -ex
trap "exit 1" TERM

source ./../properties

COMMON_PATH="../common"
APPLICATION_CONFIG_PATH="/var/lib/cdmi-server/config"
PLUGINS_CONFIG_PATH="/etc/cdmi-server/plugins"

if [ -z ${STORM_REPO_EL7+x} ]; then echo "STORM_REPO_EL7 is unset"; exit 1; fi
if [ -z ${CDMI_CLIENT_ID+x} ]; then echo "CDMI_CLIENT_ID is unset"; exit 1; fi
if [ -z ${CDMI_CLIENT_SECRET+x} ]; then echo "CDMI_CLIENT_SECRET is unset"; exit 1; fi
REDIS_HOSTNAME="${REDIS_HOSTNAME:-redis.cnaf.infn.it}"

# install StoRM repository
sh ${COMMON_PATH}/install-storm-repo.sh ${STORM_REPO_EL7}

# install cdmi_storm
yum clean all
yum install -y cdmi-storm

# Configure
rm -rf ${APPLICATION_CONFIG_PATH}/application.yml
cp -rf ../cdmi/application.yml ${APPLICATION_CONFIG_PATH}/application.yml
sed -i "s/REDIS_HOSTNAME/${REDIS_HOSTNAME}/g" ${APPLICATION_CONFIG_PATH}/application.yml
sed -i "s/CLIENT_ID/${CDMI_CLIENT_ID}/g" ${APPLICATION_CONFIG_PATH}/application.yml
sed -i "s/CLIENT_SECRET/${CDMI_CLIENT_SECRET}/g" ${APPLICATION_CONFIG_PATH}/application.yml

mkdir -p ${PLUGINS_CONFIG_PATH}
cp -rf ../cdmi/capabilities ${PLUGINS_CONFIG_PATH}
cp -rf ../cdmi/storm-properties.json ${PLUGINS_CONFIG_PATH}/storm-properties.json

# Wait for redis server
MAX_RETRIES=600
attempts=1
CMD="nc -w1 ${REDIS_HOSTNAME} 6379"

echo "Waiting for Redis server ... "
$CMD

while [ $? -eq 1 ] && [ $attempts -le  $MAX_RETRIES ];
do
  sleep 5
  let attempts=attempts+1
  $CMD
done

if [ $attempts -gt $MAX_RETRIES ]; then
  echo "Timeout!"
  exit 1
fi

echo "export JAVA_OPTS=\"-Dloader.path=/usr/lib/cdmi-server/plugins/\"" >> /etc/profile.d/cdmi.sh
chmod +x /etc/profile.d/cdmi.sh

su - cdmi -c "cd /var/lib/cdmi-server; ./cdmi-server-1.2.jar"
