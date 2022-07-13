#!/bin/bash

# Check that Docker is installed. If not ask user to install Docker and exit

# Prompt user for proxy private IP prefix
# Prompt user for ssh key file
# Prompt user for Ansible inventory file (TODO give the option to just specify private IPs of proxies and monitoring instances)

# Pull image from docker hub (make repo and tag configurable)
# Create container
# Copy files into container (ssh key, inventory)
# Run init_container_internal script

echo "****************************************************************************** "
echo "*** This script creates and initializes the Ansible Control Host container *** "
echo "****************************************************************************** "
echo

if [[ $(which docker) && $(docker --version) ]]; then
    echo "Docker is available - running version " $(docker --version)
else
    echo "Docker is required by this script but was not found. Please install Docker following the official documentation for your OS and run this script again. Exiting now."
    return
fi
echo

echo "Please enter the common prefix of the private IP addresses of the proxy instances. Simply press ENTER to use the default of 172.18.* "
read -r PROXY_PRIVATE_IP_PREFIX

if [ -z "$PROXY_PRIVATE_IP_PREFIX" ]
then
  PROXY_PRIVATE_IP_PREFIX="172.18.*"
fi
echo

echo "Please enter the path and name of the SSH private key to access the proxy instances. This is a required parameter and does not have a default value"
read -r SSH_KEY_PATH_ON_HOST

if [ -z "$SSH_KEY_PATH_ON_HOST" ]
then
  echo "No SSH private key was specified. This is a required parameter. Please rectify and run this script again. Exiting now."
  exit 1
fi
echo

while true
do
  read -pr "Do you have an existing Ansible inventory file? (y/n)" YN_INV
  case $YN_INV in
        [yY][eE][sS]|[yY])
              EXISTING_INVENTORY=true
              ;;
        [nN][oO]|[nN])
              EXISTING_INVENTORY=false
              ;;
        *)
              echo "Invalid input"
              ;;
  esac
done

if [ $EXISTING_INVENTORY == true ]
then
  echo "Please enter the path and name of your Ansible inventory file. Simply press ENTER if your inventory is /home/ubuntu/cloudgate_inventory"
  read -r ANSIBLE_INVENTORY

  if [ -z "$ANSIBLE_INVENTORY" ]
  then
    ANSIBLE_INVENTORY="/home/ubuntu/cloudgate_inventory"
  fi

  if [ ! -f $ANSIBLE_INVENTORY ]
  then
      echo "The Ansible inventory file $ANSIBLE_INVENTORY was not found. Please ensure that the file exists and is located in the specified path."
      echo
      echo "To copy your Ansible inventory from the host to the container, open a shell on the host and run the following command, removing the angle brackets and replacing the values appropriately: "
      echo "sudo docker cp <your-ansible-inventory-name> <container-name>:/home/ubuntu/ "
      echo "Then run this script again"
      exit 1
  fi
else
  echo "Please provide the private IP addresses of all your proxy instances, entering one at a time and pressing ENTER. When you have finished, simply press ENTER. "
  #TODO prompt in a loop to allow people to enter as many variables as they want. empty line means finished
  echo "Please provide the private IP addresses of your monitoring instance"
fi
