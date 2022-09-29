FROM thesoul/ubuntu-dind:docker-20.10.12

ENV USER_NAME ubuntu
ENV USER_HOME /home/${USER_NAME}
ENV ZDM_PROXY_RUN /run/zdm-proxy-automation
ENV KEY_DROP_DIR ${ZDM_PROXY_RUN}/key_drop

RUN apt-get update && \
    apt-get -y install \
        openssh-server \
        gosu \
        sudo \
        iproute2

RUN useradd \
        -rm \
        -d ${USER_HOME} \
        -s /bin/bash \
        -g root \
        -G sudo \
        -u 1001 \
        ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    sed -i 's,^#\(PasswordAuthentication\)\ yes,\1\ no,' /etc/ssh/sshd_config && \
    gosu ${USER_NAME} mkdir -p ${USER_HOME}/.ssh/ && \
    chown ${USER_NAME}:root ${USER_HOME}/.ssh/ && \
    chmod 700 ${USER_HOME}/.ssh/ && \
    gosu ${USER_NAME} touch ${USER_HOME}/.ssh/authorized_keys && \
    gosu ${USER_NAME} mkdir -p ${USER_HOME}/shared_assets

EXPOSE 9042

ENTRYPOINT ["proxy-entrypoint.sh"]
CMD [""]