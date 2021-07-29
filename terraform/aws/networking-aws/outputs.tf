output "cloudgate_vpc_id" {
  description = "IDs of the Cloudgate VPC"
  value = aws_vpc.cloudgate_vpc.id
}

output "default_security_group_id" {
  description = "Default security group of the Cloudgate VPC"
  value = aws_vpc.cloudgate_vpc.default_security_group_id
}

output "cloudgate_private_subnet_ids" {
  description = "IDs of the private subnets in the Cloudgate VPC"
  value = aws_subnet.private_subnets.*.id
}

output "cloudgate_public_subnet_id" {
  description = "ID of the public subnet in the Cloudgate VPC"
  value = aws_subnet.public_subnet.id
}

output "public_instance_sg_id" {
  description = "ID of the security group to be used for public instances"
  value = aws_security_group.public_instance_sg.id
}

output "private_instance_sg_id" {
  description = "ID of the security group to be used for private instances"
  value = aws_security_group.private_instance_sg.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT gateway that allows the proxies to initiate outbound connections"
  value = aws_eip.nat_gateway_eip.public_ip
}


#output "allow_ssh_sg_id" {
#  description = "ID of the security group to allow SSH access"
#  value = aws_security_group.allow_ssh_sg.id
#}