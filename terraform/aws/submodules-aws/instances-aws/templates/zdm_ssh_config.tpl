Host ${jumphost_private_ip} jumphost
  Hostname ${jumphost_public_ip}
  Port 22

%{ for index, ip in zdm_proxy_private_ips ~}
Host ${ip} zdm-proxy-${index}
  Hostname ${ip}
  ProxyJump jumphost

%{ endfor ~}

Host *
    User ${zdm_linux_user}
    IdentityFile ${keypath}/${keyname}
    IdentitiesOnly yes
    StrictHostKeyChecking no
    GlobalKnownHostsFile /dev/null
    UserKnownHostsFile /dev/null
