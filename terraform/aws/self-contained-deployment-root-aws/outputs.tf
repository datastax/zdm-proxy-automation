output "proxy_instance_private_ips" {
  description = "Private IP of the EC2 proxy instances"
  value = module.instances.proxy_instance_private_ips
}

output "monitoring_private_ip" {
  description = "Private IP of the EC2 monitoring instance"
  value = module.instances.monitoring_instance_private_ip
}

output "monitoring_public_ip" {
  description = "Public IP of the EC2 monitoring instance"
  value = module.instances.monitoring_instance_public_ip
}

output "cloudgate_vpc_id" {
  description = "ID of the VPC provisioned for the Cloudgate deployment"
  value = module.proxy_networking.cloudgate_vpc_id
}