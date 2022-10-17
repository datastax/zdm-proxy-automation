# syntax=docker/dockerfile:1
FROM ubuntu:18.04

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
    apt-add-repository "deb http://ppa.launchpad.net/ansible/ansible/ubuntu bionic main" && \
    apt-get update && apt-get upgrade --yes &&  \
    apt-get install --yes ansible && \
    apt-get install python-jmespath && \
    apt-get autoremove && apt-get autoclean

RUN ansible-galaxy collection install community.docker:3.0.2
RUN ansible-galaxy collection install community.general:4.8.6

# create ubuntu user
RUN useradd -ms /bin/bash ubuntu
RUN usermod -aG sudo ubuntu
USER ubuntu
WORKDIR /home/ubuntu/

RUN mkdir zdm-proxy-ssh-key-dir/

USER root
RUN echo 'ubuntu ALL=NOPASSWD: ALL' >> /etc/sudoers

#TODO this will not be necessary once the automation repository is public
COPY zdm-proxy-automation-deploy-key .ssh/
RUN ls -l .ssh/
RUN chmod 400 .ssh/zdm-proxy-automation-deploy-key
RUN printf "# deploy key \nHost zdm-proxy-automation github.com\n  Hostname github.com\n  IdentityFile /home/ubuntu/.ssh/zdm-proxy-automation-deploy-key\n"  >> .ssh/config
RUN chmod 664 .ssh/config
RUN chown -R ubuntu:ubuntu .ssh/*

COPY init_container_internal.sh .
RUN chown ubuntu:ubuntu init_container_internal.sh
RUN chmod +x init_container_internal.sh

USER ubuntu

RUN cd
RUN mkdir origin_tls_files
RUN mkdir target_tls_files
RUN mkdir zdm_proxy_tls_files

ENTRYPOINT ["/bin/bash"]

