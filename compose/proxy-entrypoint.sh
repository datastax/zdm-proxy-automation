#!/bin/bash

# Skip setup step if ubuntu user already exists
if ! id "ubuntu" &>/dev/null; then
	echo "Updating packages"
	apt update
	 
	echo "Installing OpenSSH"
	export DEBIAN_FRONTEND=noninteractive
	export TZ=America/New_York
	apt -y install openssh-server

	echo "Installing gosu"
	apt -y install gosu sudo

	echo "Installing iproute2"
	apt -y install iproute2

	echo "Creating ubuntu user"
	useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1001 ubuntu

	echo "Set up passwordless sudo for Ansible"
	echo "ubuntu ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

	echo "Disable password auth"
	sed -i s/^#PasswordAuthentication\ yes/PasswordAuthentication\ no/ /etc/ssh/sshd_config

	echo "Installing SSH public key"
	gosu ubuntu mkdir -p /home/ubuntu/.ssh/
	gosu ubuntu touch /home/ubuntu/.ssh/authorized_keys
	# wait for key pair to be created in the jumphost
	while [ ! -f /run/keys/*.pub ]; do echo "SSH key not ready" && sleep 5; done
	cat /run/keys/*.pub > /home/ubuntu/.ssh/authorized_keys

	echo "Creating shared assets folder"
	mkdir -p /home/ubuntu/shared_assets
fi

echo "Starting SSH server"
/etc/init.d/ssh start

echo "Starting Docker daemon"
dockerd &> /var/log/dockerd &

echo "Ready"
tail -F /dev/null # keeps container running