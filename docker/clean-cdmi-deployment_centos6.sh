#!/bin/bash
set -ex
trap "exit 1" TERM

CLIENT_ID=$1
CLIENT_SECRET=$2

COMMON_PATH="../common"
APPLICATION_CONFIG_PATH="/var/lib/cdmi-server/config"
PLUGINS_CONFIG_PATH="/etc/cdmi-server/plugins"
REDIS_HOSTNAME=${REDIS_HOSTNAME:-redis.cnaf.infn.it}

source ${COMMON_PATH}/input.env

# install cdmi_storm
wget $STORM_REPO -O /etc/yum.repos.d/cdmi-storm.repo
yum clean all
yum install -y cdmi-storm

# Configure
rm -rf ${APPLICATION_CONFIG_PATH}/application.yml
cp -rf ../cdmi/application.yml ${APPLICATION_CONFIG_PATH}/application.yml
sed -i "s/CLIENT_ID/${CLIENT_ID}/g" ${APPLICATION_CONFIG_PATH}/application.yml
sed -i "s/CLIENT_SECRET/${CLIENT_SECRET}/g" ${APPLICATION_CONFIG_PATH}/application.yml

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

export JAVA_OPTS="-Dloader.path=/usr/lib/cdmi-server/plugins/"

cd /var/lib/cdmi-server
su - cdmi -c "./cdmi-server-1.2.jar"
