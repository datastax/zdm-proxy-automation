#!/bin/bash

export PATH="/root/.local/bin/:$PATH"

function get_host_info() {
    host_search_name=$1

    echo "Searching for '$host_search_name' hosts"
    cidr_ip_subnet=${CIDR_IP_SUBNET}
    if [ -z "$cidr_ip_subnet" ]
    then
        echo "getting subnet from eth0"
        cidr_ip_subnet=$(ip addr show | grep "inet" | grep "eth0" | tr -s ' ' | cut -d' ' -f3)
    fi
    # formats each entry in the array as: <host_name>:<host_ip>
    get_host_info_results=( \
        $(nmap -sn $cidr_ip_subnet | \
            grep "proxy" | \
            cut -d' ' -f5,6 | \
            sed 's,\.proxy\ (\([0-9\.]*\)),:\1,' | \
            grep -e "${host_search_name}_[0-9]"))

    while [ ${#get_host_info_results[*]} -eq 0 ]
    do
        echo "no '$host_search_name' hosts found, trying again in 20s"
        sleep 20
        get_host_info_results=( \
            $(nmap -sn $cidr_ip_subnet | \
                grep "proxy" | \
                cut -d' ' -f5,6 | \
                sed 's,\.proxy\ (\([0-9\.]*\)),:\1,' | \
                grep -e "${host_search_name}_[0-9]"))
    done
    echo "Found '$host_search_name' hosts:"
    for host_info in ${get_host_info_results[*]}
    do
        echo " - ${host_info//:*/}: ${host_info//*:/}"
    done
}

function test_conn() {
    echo "testing SSH connection on $1"
    gosu ${USER_NAME} ssh -q "${USER_NAME}@$1" exit
    while [ $? -ne 0 ]
    do
		echo "SSH not ready on $1, trying again in 20s"
        sleep 20
        gosu ${USER_NAME} ssh -q "${USER_NAME}@$1" exit
    done
}

function scan_key() {
    echo "scanning keys on $1"
    ssh-keyscan "$1" >> ${USER_HOME}/.ssh/known_hosts
    while [ $? -ne 0 ]; 
    do
		echo "unable to find keys on $1, trying again in 20s"
        sleep 20
		echo "rescanning keys on $1";
        ssh-keyscan "$1" >> ${USER_HOME}/.ssh/known_hosts
    done
}

function get_ip() {
    dig +short "$1"
}

echo "Creating hosts file"
echo -n > ${HOSTS_FILE}

get_host_info_results=()
get_host_info "proxy"
proxy_host_info=(${get_host_info_results[*]})

get_host_info_results=()
get_host_info "origin"
origin_host_info=${get_host_info_results[0]}

get_host_info_results=()
get_host_info "target"
target_host_info=${get_host_info_results[0]}

for host_info in ${proxy_host_info[*]}
do
    host_name=${host_info//:*/}
    host_number=$(rev <<<${host_name} | cut -d'_' -f1)
    echo "PROXY_${host_number}:${host_info}" >> ${HOSTS_FILE}
done
echo "CASSANDRA_ORIGIN:${origin_host_info}" >> ${HOSTS_FILE}
echo "CASSANDRA_TARGET:${target_host_info}" >> ${HOSTS_FILE}

echo "Starting SSH server"
/etc/init.d/ssh start

echo "Generating SSH key pair"
gosu ${USER_NAME} ssh-keygen -q -t rsa -N '' -f ${USER_HOME}/.ssh/id_rsa
mkdir -p ${KEY_DROP_DIR} && \
  cp -f ${USER_HOME}/.ssh/id_rsa.pub ${KEY_DROP_DIR}/
cat ${USER_HOME}/.ssh/id_rsa.pub >> ${USER_HOME}/.ssh/authorized_keys

scan_key jumphost
for host_info in ${proxy_host_info[*]}
do
    scan_key ${host_info//:*/}
done

for host_info in ${proxy_host_info[*]}
do
    test_conn ${host_info//:*/}
done

echo "Creating Inventory file"
echo -n > ${ZDM_ANSIBLE_INVENTORY_FILE}
{
  echo "[proxies]"
  for host_info in ${proxy_host_info[*]}
  do
      echo "${host_info//*:/}   ansible_connection=ssh     ansible_user=${USER_NAME}"
  done
  echo
  echo "[monitoring]"
  echo "$(hostname -i)	ansible_connection=ssh     ansible_user=${USER_NAME}"
} >> ${ZDM_ANSIBLE_INVENTORY_FILE}

# remove shared keys once applied to remote servers
rm -fr ${KEY_DROP_DIR}/

echo "Overwriting ansible.cfg"
gosu ${USER_NAME} cp ${ZDM_PROXY_OPT}/ansible/ansible.cfg ${ZDM_PROXY_OPT}/ansible/ansible.cfg.bak
echo "[ssh_connection]\nssh_args = -o StrictHostKeyChecking=no\n" > ${ZDM_PROXY_OPT}/ansible/ansible.cfg

cd ${ZDM_PROXY_OPT}/ansible || exit 1

gosu ${USER_NAME} ansible-playbook deploy_zdm_proxy.yml -i zdm_ansible_inventory \
    -e "origin_cassandra_username=foo" \
    -e "origin_cassandra_password=foo" \
    -e "target_cassandra_username=foo" \
    -e "target_cassandra_password=foo" \
    -e "origin_cassandra_contact_points=${origin_host_info//:*/}" \
    -e "origin_cassandra_port=9042" \
    -e "target_cassandra_contact_points=${target_host_info//:*/}" \
    -e "target_cassandra_port=9042" \
    -e "forward_reads_to_target=false"

echo "Ready"
tail -F /dev/null # keeps container running