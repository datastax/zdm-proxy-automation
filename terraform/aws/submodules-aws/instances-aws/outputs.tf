output "proxy_instance_ids" {
  description = "IDs of the EC2 proxy instances"
  value = aws_instance.cloudgate_proxy.*.id
}

output "proxy_instance_names" {
  description = "Names of the EC2 proxy instances"
  value = aws_instance.cloudgate_proxy.*.tags.Name
}

output "proxy_instance_private_ips" {
  description = "Private IP of the EC2 proxy instances"
  value = aws_instance.cloudgate_proxy.*.private_ip
}

output "monitoring_instance_public_ip" {
  description = "Public IP of the EC2 monitoring instance"
  value = aws_instance.monitoring.public_ip
}

output "monitoring_instance_private_ip" {
  description = "Private IP of the EC2 monitoring instance"
  value = aws_instance.monitoring.private_ip
}

output "jumphost_public_ip" {
  value = aws_instance.ec2jumphost.public_ip
}


#output "monitoring_eip" {
#  description = "Public IP of the EC2 monitoring instance"
#  value = aws_eip.monitoring_eip.public_ip
#}