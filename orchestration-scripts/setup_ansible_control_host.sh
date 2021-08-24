#!/bin/bash

#####################################################################################
### Prerequisites ###
### Please make sure that the following files exist and are in the correct location:

###  - ~/.ssh/cloudgate-key
###  - ~/.ssh/cloudgate-key.pub
###  - ~/.ssh/cloudgate-automation-deploy-key
###  - ~/cloudgate-inventory

#####################################################################################

###################################################
### Configuration variables
### Please change defaults as appropriate
###################################################

ssh_dir="/home/ubuntu/.ssh"
cloudgate_vpc_cidr_first_two_octets="172.18"

###################################################
### Main script
###################################################

# Change the permissions of the Cloudgate key pair
chmod 400 "${ssh_dir}"/cloudgate-key*

#Ensure that the ssh agent is running
eval $(ssh-agent -s)

# Add the private ssh key to the ssh agent
ssh-add "${ssh_dir}"/cloudgate-key

# Append the following lines to the ssh config file (creating it if it doesn't exist)
printf "# proxy instances \nHost %s.*\n  IdentityFile %s/cloudgate-key\n" "${cloudgate_vpc_cidr_first_two_octets}" "${ssh_dir}" >> "${ssh_dir}"/config

# Install Ansible if it has not already been installed
if ! command -v ansible &> /dev/null; then
  echo "Installing Ansible"
  sudo apt update
  sudo apt install --yes software-properties-common
  sudo add-apt-repository --yes --update ppa:ansible/ansible
  sudo apt install --yes ansible
fi

# Install the jmespath dependency
sudo apt-get install --yes python-jmespath

# Install the community.docker dependency
ansible-galaxy collection install community.docker

# Set up the Cloudgate repository deploy key
chmod 400 "${ssh_dir}"/cloudgate-automation-deploy-key

# Append the following lines to the ssh config file (creating it if it doesn't exist)
printf "# deploy key \nHost cloudgate-automation github.com\n  Hostname github.com\n  IdentityFile %s/cloudgate-automation-deploy-key\n"  "${ssh_dir}" >> "${ssh_dir}"/config

# Clone the automation repo
git clone git@cloudgate-automation:riptano/cloudgate-automation.git

# Put the inventory file into the ansible directory of the cloudgate automation code
mv /home/ubuntu/cloudgate_inventory /home/ubuntu/cloudgate-automation/ansible


