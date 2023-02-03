#!/bin/bash

###
# Convenience script to install the latest Docker engine on CentOS. See https://docs.docker.com/engine/install/centos
###

#Clean up unwanted old versions:
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

sudo yum install -y yum-utils

sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

echo "About to install Docker. If prompted to accept the GPG key, verify that the fingerprint matches 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35, and if so, accept it."
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl start docker

sudo usermod -aG docker $USER

newgrp docker

echo "Docker installed. To test, run: docker run hello-world"