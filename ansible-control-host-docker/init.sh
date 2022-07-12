#!/bin/bash

SSH_KEY_DIR="/home/ubuntu/zdm-proxy-ssh-key-dir/"

echo "Please enter the common prefix of the private IP addresses of the proxy instances. Simply press ENTER to use the default of 172.18.* "
read -r PROXY_PRIVATE_IP_PREFIX

if [ -z "$PROXY_PRIVATE_IP_PREFIX" ]
then
  PROXY_PRIVATE_IP_PREFIX="172.18.*"
fi
echo

echo "Please enter the path and name of your Ansible inventory file on the container. Simply press ENTER if your inventory is /home/ubuntu/cloudgate_inventory"
read -r ANSIBLE_INVENTORY

if [ -z "$ANSIBLE_INVENTORY" ]
then
  ANSIBLE_INVENTORY="/home/ubuntu/cloudgate_inventory"
fi

if [ ! -f $ANSIBLE_INVENTORY ]
then
    echo "The Ansible inventory file $ANSIBLE_INVENTORY was not found. Please ensure that the file exists and is located in the specified path on the container."
    echo "To copy your Ansible inventory from the host to the container, open a shell on the host and run the following command, removing the angle brackets and replacing the values appropriately: "
    echo "sudo docker cp <your-ansible-inventory-name> <container-name>:/home/ubuntu/ "
    echo "Then run this script again"
    return
fi

echo

if [ "$(ls -A $SSH_KEY_DIR)" ]; then
   cd $SSH_KEY_DIR || return
   for KEY_FILE in *
   do
     echo "Copying key $KEY_FILE to the SSH directory"
     chmod 400 "$KEY_FILE"
     sudo cp "$KEY_FILE" /home/ubuntu/.ssh/
     if pcregrep -Mq "Host $PROXY_PRIVATE_IP_PREFIX\n  IdentityFile /home/ubuntu/.ssh/$KEY_FILE" /home/ubuntu/.ssh/config
     then
       echo "Entry for key $KEY_FILE and proxy IP prefix $PROXY_PRIVATE_IP_PREFIX already exists in the SSH config file"
     else
       echo "Adding an entry for key $f and proxy IP prefix $PROXY_PRIVATE_IP_PREFIX to the SSH config file"
       printf "# proxy instances \nHost $PROXY_PRIVATE_IP_PREFIX\n  IdentityFile /home/ubuntu/.ssh/%s\n" "$f" >> /home/ubuntu/.ssh/config
     fi
     echo
   done
else
  echo "No SSH key was found in $SSH_KEY_DIR. At least one SSH key able to access the proxy instances must be made available to the container."
  echo "To copy keys from the host into $SSH_KEY_DIR on the container, open a shell on the host and run the following command, removing the angle brackets and replacing the values appropriately: "
  echo "sudo docker cp <your-ssh-key-name> <container-name>:$SSH_KEY_DIR "
  echo "Then run this script again"
  return
fi

echo "Changing ownership of all keys to user ubuntu"
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/
echo

cd

if [ -d "home/ubuntu/cloudgate-automation" ]
then
  echo "The automation git repo has already been cloned."
else
  echo "Cloning the automation git repo"
  git clone git@cloudgate-automation:riptano/cloudgate-automation.git
fi
echo

cd cloudgate-automation/ansible || return

# Overwrite the ansible.cfg file with the appropriate parameters to run playbooks from the jumphost
echo "Setting the appropriate options in the global Ansible configuration file"
printf "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ansible.cfg
echo

echo "Making the inventory file available to Ansible"
sudo chown ubuntu:ubuntu /home/ubuntu/$ANSIBLE_INVENTORY
mv /home/ubuntu/$ANSIBLE_INVENTORY /home/ubuntu/cloudgate-automation/ansible
echo

echo "*** The Ansible container is now fully initialized and ready to use. *** "
echo "You can proceed to configure and run the Ansible playbooks to deploy and manage the proxies."
echo "As a reminder, your Ansible inventory file is called $ANSIBLE_INVENTORY and is now located in cloudgate-automation/ansible"

