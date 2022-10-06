#!/bin/bash

echo "checking if SSH key is ready"
while [ $(find ${KEY_DROP_DIR} -mindepth 1 -maxdepth 1 -type f -iname "*.pub" | wc -l) -eq 0 ]
do
    echo "SSH key not ready on $1, trying again in 20s"
    sleep 20
done

cat ${KEY_DROP_DIR}/*.pub > ${USER_HOME}/.ssh/authorized_keys

echo "Starting SSH server"
/etc/init.d/ssh start

echo "Starting Docker daemon"
dockerd &> /var/log/dockerd &

echo "Ready"
tail -F /dev/null # keeps container running