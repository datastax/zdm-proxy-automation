#!/bin/bash

function test_conn() {
	cqlsh $1 -e 'quit';
	while [ $? -ne 0 ];
		do echo "cqlsh not ready on $1";
		sleep 30;
		cqlsh $1 -e 'quit';
	done
}

function select_all() {
	echo `cqlsh $1 -e 'SELECT * FROM system.local;'`
}

echo "Updating packages"
apt update

echo "Installing network utils"
apt -y install iproute2 net-tools iputils-ping

echo "Installing Python 3"
apt -y install python3 python3-pip

echo "Installing cqlsh"
pip install -U cqlsh

echo "Testing cqlsh"
test_conn zdm-automation_proxy_1

echo "Running SELECT statement"
select_all zdm-automation_proxy_1

echo "Ready"
tail -F /dev/null # keeps container running