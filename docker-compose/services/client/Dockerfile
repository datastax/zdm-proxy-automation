FROM ubuntu:20.04

ENV ZDM_PROXY_RUN /run/zdm-proxy-automation
ENV HOSTS_FILE ${ZDM_PROXY_RUN}/hostsfile

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt-get -y install \
        iproute2 \
        net-tools \
        iputils-ping \
        python3 \
        python3-pip \
        tzdata

RUN python3 -m pip install -U cqlsh

# Fix timezone in client 
RUN ln -fs /usr/share/zoneinfo/Australia/Sydney /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata

ENTRYPOINT ["client-entrypoint.sh"]
CMD [""]