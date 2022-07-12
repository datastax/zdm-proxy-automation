#!/bin/bash

for f in ~/zdm-proxy-ssh-key-dir/*
do
  echo "Copying key $f to the SSH directory and adding it to the SSH config file"
  chmod 400 "$f"
  cp ~/zdm-proxy-ssh-key-dir/"$f" ~/.ssh/
  printf "# proxy instances \nHost 172.18.*\n  IdentityFile /home/ubuntu/.ssh/%s\n" "$f" >> .ssh/config
done

echo "Changing ownership of all keys to user ubuntu"
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/

echo "Cloning the automation git repo"
git clone git@cloudgate-automation:riptano/cloudgate-automation.git

echo "Making the inventory file available to Ansible"
sudo chown ubuntu:ubuntu cloudgate_inventory
mv /home/ubuntu/cloudgate_inventory /home/ubuntu/cloudgate-automation/ansible

# Overwrite the ansible.cfg file with the appropriate parameters to run playbooks from the jumphost
cd cloudgate-automation/ansible || return

echo "Setting the appropriate options in the global Ansible configuration file"
printf "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ansible.cfg
