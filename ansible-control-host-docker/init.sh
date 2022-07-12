#!/bin/bash

echo "This script requires the common prefix of the private IP addresses of the proxy instances."
echo "Please enter its value, or simply press ENTER to use the default of 172.18.* :"
read -r proxy_private_ip_prefix

if [ -z "$proxy_private_ip_prefix" ]
then
  proxy_private_ip_prefix="172.18.*"
fi

cd /home/ubuntu/zdm-proxy-ssh-key-dir/ || return

for f in *
do
  echo "Copying key $f to the SSH directory"
  chmod 400 "$f"
  sudo cp "$f" /home/ubuntu/.ssh/
  if pcregrep -Mq "Host $proxy_private_ip_prefix\n  IdentityFile /home/ubuntu/.ssh/$f" /home/ubuntu/.ssh/config
  then
    echo "Entry for key $f and proxy IP prefix $proxy_private_ip_prefix already exists in the SSH config file"
  else
    echo "Adding an entry for key $f and proxy IP prefix $proxy_private_ip_prefix to the SSH config file"
    printf "# proxy instances \nHost $proxy_private_ip_prefix\n  IdentityFile /home/ubuntu/.ssh/%s\n" "$f" >> /home/ubuntu/.ssh/config
  fi
  echo
done

echo "Changing ownership of all keys to user ubuntu"
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/
echo

cd

echo "Cloning the automation git repo"
git clone git@cloudgate-automation:riptano/cloudgate-automation.git

echo "Making the inventory file available to Ansible"
sudo chown ubuntu:ubuntu cloudgate_inventory
mv /home/ubuntu/cloudgate_inventory /home/ubuntu/cloudgate-automation/ansible

# Overwrite the ansible.cfg file with the appropriate parameters to run playbooks from the jumphost
cd cloudgate-automation/ansible || return

echo "Setting the appropriate options in the global Ansible configuration file"
printf "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ansible.cfg