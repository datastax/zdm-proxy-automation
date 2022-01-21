#!/bin/bash

export PATH="/root/.local/bin/:$PATH"
export DEBIAN_FRONTEND=noninteractive
export TZ=America/New_York

function test_conn() {
	gosu ubuntu ssh -q "ubuntu@$1" exit
	while [ $? -ne 0 ];
		do echo "ssh not ready on $1";
		sleep 5;
		gosu ubuntu ssh -q "ubuntu@$1" exit;
	done
}

function scan_key() {
	ssh-keyscan "$1" >> /home/ubuntu/.ssh/known_hosts
	while [ $? -ne 0 ]; 
		do sleep 5;
		echo "rescanning keys on $1";
		ssh-keyscan "$1" >> /home/ubuntu/.ssh/known_hosts;
	done
}

function get_ip() {
	dig +short "$1"
}

# Skip setup step if ubuntu user already exists
if ! id "ubuntu" &>/dev/null; then
	echo "Updating packages"
	apt update

	echo "Installing network utils"
	apt -y install iproute2 net-tools iputils-ping dnsutils gettext-base

	echo "Installing OpenSSH"
	apt -y install openssh-server

	echo "Installing gosu"
	apt -y install gosu

	echo "Creating ubuntu user"
	useradd -rm -d /home/ubuntu -s /bin/bash -g root -G sudo -u 1001 ubuntu

	echo "Starting SSH server"
	/etc/init.d/ssh start

	echo "Generating SSH key pair"
	gosu ubuntu ssh-keygen -q -t rsa -N '' -f /home/ubuntu/.ssh/id_rsa
	cp -rf /home/ubuntu/.ssh/id_rsa.pub /run/keys/
	cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys

	echo "Adding proxy servers to SSH known_hosts"
	gosu ubuntu touch /home/ubuntu/.ssh/known_hosts

	scan_key cloudgate-automation_jumphost_1
	scan_key cloudgate-automation_proxy_1
	scan_key  cloudgate-automation_proxy_2
	scan_key  cloudgate-automation_proxy_3

	test_conn cloudgate-automation_proxy_1
	test_conn  cloudgate-automation_proxy_2
	test_conn  cloudgate-automation_proxy_3

	# remove shared keys once applied to remote servers
	rm /run/keys/*.pub

	echo "Installing Python 3"
	apt -y install python3 python3-pip

	echo "Installing Ansible"
	python3 -m pip install ansible
fi

echo "Starting SSH server"
/etc/init.d/ssh start

test_conn cloudgate-automation_proxy_1
test_conn cloudgate-automation_proxy_2
test_conn cloudgate-automation_proxy_3

export PROXY_IP_1=`get_ip cloudgate-automation_proxy_1`
export PROXY_IP_2=`get_ip cloudgate-automation_proxy_2`
export PROXY_IP_3=`get_ip cloudgate-automation_proxy_3`
export JUMPHOST_IP=`get_ip cloudgate-automation_jumphost_1`

cd /opt/cloudgate-automation

echo "Setting up Inventory file"
envsubst < compose/cloudgate_inventory > ansible/cloudgate_inventory

echo "Overwriting ansible.cfg"
echo "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ansible/ansible.cfg

cd ansible

gosu ubuntu ansible-playbook cloudgate_proxy_playbook.yml -i cloudgate_inventory \
	-e "origin_cassandra_username=foo" \
	-e "origin_cassandra_password=foo" \
	-e "target_cassandra_username=foo" \
	-e "target_cassandra_password=foo" \
	-e "origin_cassandra_contact_points=cloudgate-automation_origin_1" \
	-e "origin_cassandra_port=9042" \
	-e "target_cassandra_contact_points=cloudgate-automation_target_1" \
	-e "target_cassandra_port=9042" \
	-e "proxy_query_address=0.0.0.0"

echo "Ready"
tail -F /dev/null # keeps container running