# syntax=docker/dockerfile:1
FROM ubuntu:18.04

# install all necessary software packages and dependencies
RUN apt-get update && apt-get install -y software-properties-common \
    vim-tiny \
    vim \
    nano \
    git \
    sudo \
    pcregrep

RUN add-apt-repository ppa:ansible/ansible && apt-get update && apt-get install -y \
    ansible \
    python-jmespath \
 && rm -rf /var/lib/apt/lists/*

RUN ansible-galaxy collection install community.docker
RUN ansible-galaxy collection install community.general

# create ubuntu user
RUN useradd -ms /bin/bash ubuntu
RUN usermod -aG sudo ubuntu
USER ubuntu
WORKDIR /home/ubuntu/

RUN mkdir zdm-proxy-ssh-key-dir/

USER root
RUN echo 'ubuntu ALL=NOPASSWD: ALL' >> /etc/sudoers

COPY cloudgate-automation-deploy-key .ssh/
RUN ls -l .ssh/
RUN chmod 400 .ssh/cloudgate-automation-deploy-key
RUN printf "# deploy key \nHost cloudgate-automation github.com\n  Hostname github.com\n  IdentityFile /home/ubuntu/.ssh/cloudgate-automation-deploy-key\n"  >> .ssh/config
RUN chmod 664 .ssh/config
RUN chown -R ubuntu:ubuntu .ssh/*

COPY init_container_internal.sh .
RUN chown ubuntu:ubuntu init_container_internal.sh
RUN chmod +x init_container_internal.sh

USER ubuntu

ENTRYPOINT ["/bin/bash"]

