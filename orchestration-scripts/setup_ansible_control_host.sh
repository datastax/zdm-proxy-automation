#!/bin/bash

#####################################################################################
### Prerequisites ###
### Please make sure that the following files exist and are in the correct location:

###  - ~/.ssh/<cloudgate_keypair_name>
###  - ~/.ssh/<cloudgate_keypair_name>.pub
###  - ~/.ssh/cloudgate-automation-deploy-key
###  - ~/cloudgate-inventory

#####################################################################################

###################################################
### Configuration variables
###################################################

### REQUIRED variables - Please uncomment and specify

# Name of the keypair that enables access to the Cloudgate infrastructure.
#cloudgate_keypair_name=

### End of REQUIRED variables

### OPTIONAL variables - Please change defaults as appropriate
# SSH config directory used by the SSH agent. Typically it is .ssh in the home of the OS user (default "ubuntu")
ssh_dir="/home/ubuntu/.ssh"

# Prefix of the private IP addresses of the Cloudgate proxies.
# This defaults to the first two octets of the Cloudgate VPC created by Terraform in the standard configuration.
# Please uncomment and change as appropriate, to match the prefix of the private IPs of the proxy machines.
proxy_private_ip_address_prefix="172.18"

###################################################
### Main script
###################################################

# Change the permissions of the Cloudgate key pair
chmod 400 "${ssh_dir}"/"${cloudgate_keypair_name}"*

#Ensure that the ssh agent is running
eval $(ssh-agent -s)

# Add the private ssh key to the ssh agent
ssh-add "${ssh_dir}"/"${cloudgate_keypair_name}"

# Append the following lines to the ssh config file (creating it if it doesn't exist)
printf "# proxy instances \nHost %s.*\n  IdentityFile %s/%s\n" "${proxy_private_ip_address_prefix}" "${ssh_dir}" "${cloudgate_keypair_name}" >> "${ssh_dir}"/config

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

# Install the community.general dependency
ansible-galaxy collection install community.general

# Set up the Cloudgate repository deploy key
chmod 400 "${ssh_dir}"/cloudgate-automation-deploy-key

# Append the following lines to the ssh config file (creating it if it doesn't exist)
printf "# deploy key \nHost cloudgate-automation github.com\n  Hostname github.com\n  IdentityFile %s/cloudgate-automation-deploy-key\n"  "${ssh_dir}" >> "${ssh_dir}"/config

# Clone the automation repo
git clone git@cloudgate-automation:riptano/cloudgate-automation.git

# Put the inventory file into the ansible directory of the cloudgate automation code
mv /home/ubuntu/cloudgate_inventory /home/ubuntu/cloudgate-automation/ansible

# Overwrite the ansible.cfg file with the appropriate parameters to run playbooks from the jumphost
cd cloudgate-automation/ansible
printf "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ansible.cfg




