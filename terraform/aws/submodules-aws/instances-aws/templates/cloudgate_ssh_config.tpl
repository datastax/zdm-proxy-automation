Host ${jumphost_private_ip} jumphost
  Hostname ${jumphost_public_ip}
  Port 22

%{ for index, ip in cloudgate_proxy_private_ips ~}
Host ${ip} cloudgate-proxy-${index}
  Hostname ${ip}
  ProxyJump jumphost

%{ endfor ~}

Host *
    User ubuntu
    IdentityFile ${keypath}/${keyname}
    IdentitiesOnly yes
    StrictHostKeyChecking no
    GlobalKnownHostsFile /dev/null
    UserKnownHostsFile /dev/null
