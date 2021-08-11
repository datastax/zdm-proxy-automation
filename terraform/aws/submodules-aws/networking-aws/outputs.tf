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

output "private_subnet_route_table_id" {
  description = "ID of the route table associated with the private subnets where the proxy instances will live"
  value = aws_route_table.private_subnet_rt.id
}

output "public_subnet_route_table_id" {
  description = "ID of the route table associated with the public subnet where the monitoring instance will live"
  value = aws_route_table.internet_gateway_rt.id
}

output "public_instance_sg_id" {
  description = "ID of the security group to be used for public instances"
  value = aws_security_group.public_instance_sg.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT gateway that allows the proxies to initiate outbound connections"
  value = aws_eip.nat_gateway_eip.public_ip
}
