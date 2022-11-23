#!/bin/bash

# Help function
print_help_message () {
  echo
  echo
  printf "Usage: ./init_container_internal.sh [ARG] [ARG], where ARG has the form: arg_name arg_value \n"
  echo
  printf "Required arguments: \n"
  printf "  -p / --proxy_ip_address_prefix: common prefix of the ip addresses of all proxy instances \n"
  printf "  -i / --ansible_inventory_name: name of the Ansible inventory file, which must be located in the home directory of the container \n"
  echo
  printf "Examples:  \n"
  printf "  ./init_container_internal.sh -p 172.18.* -i my_ansible_inventory \n"
  printf "  ./init_container_internal.sh -proxy_ip_address_prefix 172.18.* -ansible_inventory_name my_ansible_inventory \n"
  printf "  ./init_container_internal.sh --proxy_ip_address_prefix 172.18.* --ansible_inventory_name my_ansible_inventory \n"
  printf "Short and long options can also be combined \n"
  echo
  printf "This script will exit now, please try again. \n"
  echo
  echo
  return
}

#### Main script ####

# Exit if any command fails
set -e
SSH_KEY_DIR="/home/ubuntu/zdm-proxy-ssh-key-dir/"
echo
echo
echo "***** Configuring the newly created container ***** "
echo
echo

# Parse named command-line arguments
SHORT=p:,i:,h
LONG=proxy_ip_address_prefix:,ansible_inventory_name:,help
OPTS=$(getopt -a -n init_container_internal --options $SHORT --longoptions $LONG -- "$@")

VALID_ARGUMENTS=$#

if [ "$VALID_ARGUMENTS" -eq 0 ]; then
  echo "ERROR: Missing mandatory parameters"
  print_help_message
  exit 1
fi

eval set -- "$OPTS"
while :
do
  case "$1" in
    -p | --proxy_ip_address_prefix )
      PROXY_IP_ADDRESS_PREFIX_RAW="$2"
      shift 2
      ;;
    -i | --ansible_inventory_name )
      ANSIBLE_INVENTORY_NAME_RAW="$2"
      shift 2
      ;;
    -h | --help )
      print_help_message
      exit 1
      ;;
    --)
      shift;
      break
      ;;
    * )
      echo "Unknown option: $1"
      print_help_message
      exit 1
      ;;
  esac
done

PROXY_IP_ADDRESS_PREFIX="$(echo -e "$PROXY_IP_ADDRESS_PREFIX_RAW" | tr -d '[:space:]')"
if [ -z "$PROXY_IP_ADDRESS_PREFIX" ]
then
  echo "ERROR: Missing mandatory parameter proxy_ip_address_prefix"
  print_help_message
  exit 1
fi

ANSIBLE_INVENTORY_NAME="$(echo -e "$ANSIBLE_INVENTORY_NAME_RAW" | tr -d '[:space:]')"
if [ -z "$ANSIBLE_INVENTORY_NAME" ]
then
  echo "ERROR: Missing mandatory parameter ansible_inventory_name"
  print_help_message
  exit 1
fi

#Copy all provided keys to the .ssh directory, change permissions and update the ssh config file accordingly
if [ "$(ls -A $SSH_KEY_DIR)" ]; then
   cd $SSH_KEY_DIR || return
   for KEY_FILE in *
   do
     echo "Copying key $KEY_FILE to the SSH directory"
     sudo chmod 400 "$KEY_FILE"
     sudo cp "$KEY_FILE" /home/ubuntu/.ssh/
     if pcregrep -Mq "Host $PROXY_IP_ADDRESS_PREFIX\n  IdentityFile /home/ubuntu/.ssh/$KEY_FILE" /home/ubuntu/.ssh/config
     then
       echo "Entry for key $KEY_FILE and proxy IP prefix $PROXY_IP_ADDRESS_PREFIX already exists in the SSH config file"
     else
       echo "Adding an entry for key $KEY_FILE and proxy IP prefix $PROXY_IP_ADDRESS_PREFIX to the SSH config file"
       printf "# proxy instances \nHost $PROXY_IP_ADDRESS_PREFIX\n  IdentityFile /home/ubuntu/.ssh/%s\n" "$KEY_FILE" >> /home/ubuntu/.ssh/config
     fi
     echo
   done
else
  echo "No SSH key was found in $SSH_KEY_DIR. At least one SSH key able to access the proxy instances must be made available to the container."
  exit 1
fi

echo "Changing ownership of all keys to user ubuntu"
sudo chown -R ubuntu:ubuntu /home/ubuntu/.ssh/
echo

cd || return

# Clone the automation if it is not already present
if [ -d "/home/ubuntu/zdm-proxy-automation" ]
then
  echo "The automation git repo has already been cloned."
else
  echo "Cloning the automation git repo"
  git clone https://github.com/datastax/zdm-proxy-automation.git
fi
echo

cd zdm-proxy-automation/ansible || return

# Overwrite the ansible.cfg file with the appropriate parameters to run playbooks from the jumphost
echo "Setting the appropriate options in the global Ansible configuration file"
printf "[defaults]\ninterpreter_python = auto\n" > ansible.cfg
printf "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" >> ansible.cfg
echo

cd || return

# Copy the Ansible inventory into the Ansible automation directory
echo "Making the inventory file available to Ansible"
sudo chown ubuntu:ubuntu "$ANSIBLE_INVENTORY_NAME"
mv "$ANSIBLE_INVENTORY_NAME" /home/ubuntu/zdm-proxy-automation/ansible
echo

echo "************************************************************************ "
echo "*** The Ansible container is now fully initialized and ready to use. *** "
echo "************************************************************************ "
echo
echo "You can proceed to configure and run the Ansible playbooks to deploy and manage the proxies."
echo "As a reminder, your Ansible inventory file is called $ANSIBLE_INVENTORY_NAME and is now located in zdm-proxy-automation/ansible"

