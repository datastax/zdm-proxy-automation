output "zdm_proxy_instance_private_ips" {
  description = "Private IP of the EC2 ZDM proxy instances"
  value = module.zdm_instances.zdm_proxy_instance_private_ips
}

output "zdm_monitoring_private_ip" {
  description = "Private IP of the EC2 ZDM monitoring instance"
  value = module.zdm_instances.zdm_monitoring_instance_private_ip
}

output "zdm_monitoring_public_ip" {
  description = "Public IP of the EC2 ZDM monitoring instance"
  value = module.zdm_instances.zdm_monitoring_instance_public_ip
}

output "zdm_jumphost_public_ip" {
  description = "Public IP of the EC2 ZDM instance used as jumphost"
  value = module.zdm_instances.zdm_monitoring_instance_public_ip
}

output "zdm_vpc_id" {
  description = "ID of the VPC provisioned for the ZDM deployment"
  value = module.zdm_proxy_networking.zdm_vpc_id
}