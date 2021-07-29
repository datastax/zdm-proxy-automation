output "proxy_instance_private_ips" {
  description = "Private IP of the EC2 proxy instances"
  value = module.instances.proxy_instance_private_ips
}

output "jumphost_public_ip" {
  description = "Public IP of the EC2 jump host instance"
  value = module.instances.jumphost_public_ip
}

output "monitoring_private_ip" {
  description = "Private IP of the EC2 monitoring instance"
  value = module.instances.monitoring_instance_private_ip
}

output "monitoring_public_ip" {
  description = "Public IP of the EC2 monitoring instance"
  value = module.instances.monitoring_instance_public_ip
}