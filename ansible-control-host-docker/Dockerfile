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

RUN apt-get update && apt-get upgrade --yes &&  \
    apt-get install --yes python3-pip && \
    apt-get install --yes python3-jmespath && \
    apt-get install --yes python3-cryptography && \
    apt-get install --yes pipx && \
    apt-get autoremove && apt-get autoclean

# Setup PATH for both root and the ubuntu user
# pipx installs binaries to ~/.local/bin by default
ENV PATH="/root/.local/bin:/home/ubuntu/.local/bin:${PATH}"

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

RUN pipx install --include-deps ansible==10.7.0
RUN ansible-galaxy collection install community.docker
RUN ansible-galaxy collection install community.general

RUN cd
RUN mkdir zdm-proxy-ssh-key-dir
RUN mkdir origin_tls_files
RUN mkdir target_tls_files
RUN mkdir zdm_proxy_tls_files

ENTRYPOINT ["/bin/bash"]
