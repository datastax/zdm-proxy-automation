#!/bin/bash

#####################################################################################
### Prerequisites ###
### Please make sure that the following files exist and are in the correct location:

###  - ~/.ssh/<zdm_keypair_name>
###  - ~/.ssh/<zdm_keypair_name>.pub
###  - ~/.ssh/zdm-proxy-automation-deploy-key
###  - ~/zdm_ansible_inventory

#####################################################################################

###################################################
### Configuration variables
###################################################

### REQUIRED variables - Please uncomment and specify

# Name of the keypair that enables access to the ZDM infrastructure.
#zdm_keypair_name=

### End of REQUIRED variables

### OPTIONAL variables - Please change defaults as appropriate
# SSH config directory used by the SSH agent. Typically it is .ssh in the home of the OS user (default "ubuntu")
ssh_dir="/home/ubuntu/.ssh"

# Prefix of the private IP addresses of the ZDM proxies.
# This defaults to the first two octets of the ZDM VPC created by Terraform in the standard configuration.
# Please uncomment and change as appropriate, to match the prefix of the private IPs of the proxy machines.
zdm_proxy_private_ip_address_prefix="172.18"

###################################################
### Main script
###################################################

# Change the permissions of the ZDM key pair
chmod 400 "${ssh_dir}"/"${zdm_keypair_name}"*

#Ensure that the ssh agent is running
eval $(ssh-agent -s)

# Add the private ssh key to the ssh agent
ssh-add "${ssh_dir}"/"${zdm_keypair_name}"

# Append the following lines to the ssh config file (creating it if it doesn't exist)
printf "# proxy instances \nHost %s.*\n  IdentityFile %s/%s\n" "${zdm_proxy_private_ip_address_prefix}" "${ssh_dir}" "${zdm_keypair_name}" >> "${ssh_dir}"/config

# Install Ansible if it has not already been installed
if ! command -v ansible &> /dev/null; then
  echo "Installing Ansible"
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
  sudo apt-add-repository "deb http://ppa.launchpad.net/ansible/ansible/ubuntu bionic main"
  sudo apt update
  sudo apt upgrade
  sudo apt install --yes software-properties-common
  sudo apt install --yes ansible
fi

# Install the jmespath dependency
sudo apt-get install --yes python-jmespath

# Install the community.docker dependency
ansible-galaxy collection install community.docker:3.0.2

# Install the community.general dependency
ansible-galaxy collection install community.general:4.8.6

# Set up the ZDM proxy automation repository deploy key
chmod 400 "${ssh_dir}"/zdm-proxy-automation-deploy-key

# Append the following lines to the ssh config file (creating it if it doesn't exist)
printf "# deploy key \nHost zdm-proxy-automation github.com\n  Hostname github.com\n  IdentityFile %s/zdm-proxy-automation-deploy-key\n"  "${ssh_dir}" >> "${ssh_dir}"/config

# Clone the automation repo
git clone git@github.com:datastax/zdm-proxy-automation.git

# Put the inventory file into the Ansible directory of the ZDM proxy automation code
mv /home/ubuntu/zdm_ansible_inventory /home/ubuntu/zdm-proxy-automation/ansible

# Overwrite the ansible.cfg file with the appropriate parameters to run playbooks from the jumphost
cd zdm-proxy-automation/ansible || return
printf "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ansible.cfg




