#!/bin/bash

###
# Convenience script to install the latest Docker engine on Ubuntu. See https://docs.docker.com/engine/install/ubuntu/
###

#Clean up unwanted old versions:
sudo apt-get remove docker docker-engine docker.io containerd runc

#Update apt package index:
sudo apt-get update

#Install packages needed by the installation process:
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

#Add Docker's official GPG key:
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

#To fix the warning:
sudo gpgconf --kill dirmngr
sudo chown -R $USER ~/.gnupg

#Set up the repo:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

#Update apt package index again:
sudo apt-get update

#Install the docker engine:
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

#Enable your current user to run the docker command without sudo
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker