FROM ubuntu:20.04

ENV USER_NAME ubuntu
ENV USER_HOME /home/${USER_NAME}
ENV ZDM_PROXY_RUN /run/zdm-proxy-automation
ENV ZDM_PROXY_OPT /opt/zdm-proxy-automation
ENV KEY_DROP_DIR ${ZDM_PROXY_RUN}/key_drop
ENV HOSTS_FILE ${ZDM_PROXY_RUN}/hostsfile
ENV ZDM_ANSIBLE_INVENTORY_FILE ${ZDM_PROXY_OPT}/ansible/zdm_ansible_inventory

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install \
        iproute2 \
        net-tools \
        iputils-ping \
        nmap \
        dnsutils \
        gettext-base \
        openssh-server \
        gosu \
        python3 \
        python3-pip

RUN python3 -m pip install ansible

RUN useradd \
        -rm \
        -d ${USER_HOME} \
        -s /bin/bash \
        -g root \
        -G sudo \
        -u 1001 \
        ${USER_NAME} && \
    gosu ${USER_NAME} mkdir -p ${USER_HOME}/.ssh/ && \
    chown ${USER_NAME}:root ${USER_HOME}/.ssh/ && \
    chmod 700 ${USER_HOME}/.ssh/ && \
    gosu ${USER_NAME} touch ${USER_HOME}/.ssh/known_hosts

RUN mkdir -p ${ZDM_PROXY_OPT}

ENV CIDR_IP_SUBNET ""
ENV PROXY_IP_1 ""
ENV PROXY_IP_2 ""
ENV PROXY_IP_3 ""
ENV JUMPHOST_IP ""

ENTRYPOINT ["jumphost-entrypoint.sh"]
CMD [""]