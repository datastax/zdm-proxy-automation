# syntax=docker/dockerfile:1
FROM ubuntu:18.04

WORKDIR /home/ubuntu/

RUN apt-get update && apt-get install -y software-properties-common
RUN add-apt-repository ppa:ansible/ansible && apt-get update && apt-get install -y \
    ansible \
    python-jmespath \
    git \
 && rm -rf /var/lib/apt/lists/*

RUN ansible-galaxy collection install community.docker
RUN ansible-galaxy collection install community.general

# install git?
COPY cloudgate-automation-deploy-key .ssh/
RUN chmod 400 .ssh/cloudgate-automation-deploy-key
RUN echo "# deploy key \nHost cloudgate-automation github.com\n  Hostname github.com\n  IdentityFile .ssh/cloudgate-automation-deploy-key\n"  >> .ssh/config

RUN cat .ssh/config

#RUN git clone git@cloudgate-automation:riptano/cloudgate-automation.git

