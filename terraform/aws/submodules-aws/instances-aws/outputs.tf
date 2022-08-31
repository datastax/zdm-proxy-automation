output "zdm_proxy_instance_ids" {
  description = "IDs of the EC2 ZDM proxy instances"
  value = aws_instance.zdm_proxy.*.id
}

output "zdm_proxy_instance_names" {
  description = "Names of the EC2 ZDM proxy instances"
  value = aws_instance.zdm_proxy.*.tags.Name
}

output "zdm_proxy_instance_private_ips" {
  description = "Private IP of the EC2 ZDM proxy instances"
  value = aws_instance.zdm_proxy.*.private_ip
}

output "zdm_monitoring_instance_public_ip" {
  description = "Public IP of the EC2 ZDM monitoring instance"
  value = aws_eip.zdm_monitoring_eip.public_ip
}

output "zdm_monitoring_instance_private_ip" {
  description = "Private IP of the EC2 ZDM monitoring instance"
  value = aws_instance.zdm_monitoring.private_ip
}

output "public_key" {
  value = aws_key_pair.zdm_key_pair.public_key
}