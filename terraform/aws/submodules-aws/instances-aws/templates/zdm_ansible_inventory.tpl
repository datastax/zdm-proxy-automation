[proxies]
%{ for ip in zdm_proxy_private_ips ~}
${ip} ansible_connection=ssh ansible_user=${zdm_linux_user}
%{ endfor ~}


[monitoring]
${zdm_monitoring_private_ip} ansible_connection=ssh ansible_user=${zdm_linux_user}
