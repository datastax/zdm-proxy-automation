#!/bin/bash

echo "Changing ownership of all keys to user ubuntu"
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/

eval $(ssh-agent -s)
for f in ~/.ssh/*
do
  echo "Adding key " $f " to SSH agent"
  ssh-add "$f"
done

echo "Cloning the automation git repo"
git clone git@cloudgate-automation:riptano/cloudgate-automation.git

echo "Making the inventory file available to Ansible"
sudo chown ubuntu:ubuntu cloudgate_inventory
mv /home/ubuntu/cloudgate_inventory /home/ubuntu/cloudgate-automation/ansible

# Overwrite the ansible.cfg file with the appropriate parameters to run playbooks from the jumphost
cd cloudgate-automation/ansible

echo "Setting the appropriate options in the global Ansible configuration file"
printf "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ansible.cfg