# syntax=docker/dockerfile:1
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND noninteractive

# install all necessary software packages and dependencies
RUN apt-get update && apt-get install -y software-properties-common \
    vim-tiny \
    vim \
    nano \
    git \
    sudo \
    pcregrep \
    gnupg

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 && \
    apt-add-repository "deb http://ppa.launchpad.net/ansible/ansible/ubuntu noble main" && \
    apt-get update && apt-get upgrade --yes &&  \
    apt-get install --yes python3-pip && \
    apt-get install --yes python3-jmespath && \
    apt-get install --yes ansible && \
    apt-get install --yes python3-cryptography && \
    apt-get autoremove && apt-get autoclean

# switch to ubuntu user
USER ubuntu
WORKDIR /home/ubuntu/

USER root
RUN echo 'ubuntu ALL=NOPASSWD: ALL' >> /etc/sudoers

RUN mkdir .ssh
RUN touch .ssh/config
RUN chmod 664 .ssh/config
RUN chown -R ubuntu:ubuntu .ssh/*

COPY init_container_internal.sh .
RUN chown ubuntu:ubuntu init_container_internal.sh
RUN chmod +x init_container_internal.sh

USER ubuntu

RUN ansible-galaxy collection install community.docker
RUN ansible-galaxy collection install community.general

RUN cd
RUN mkdir zdm-proxy-ssh-key-dir
RUN mkdir origin_tls_files
RUN mkdir target_tls_files
RUN mkdir zdm_proxy_tls_files

ENTRYPOINT ["/bin/bash"]
