[proxies]
%{ for ip in cloudgate_proxy_private_ips ~}
${ip} ansible_connection=ssh ansible_user=ubuntu
%{ endfor ~}


[monitoring]
${monitoring_private_ip} ansible_connection=ssh ansible_user=ubuntu
