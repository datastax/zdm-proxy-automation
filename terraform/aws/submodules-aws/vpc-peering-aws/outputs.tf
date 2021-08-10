output "vpc_peering_connection_id" {
  description = "ID of the newly established VPC peering connection"
  value = aws_vpc_peering_connection.peering_request.id
}

output "cloudgate_to_user_security_group_ids" {
  description = "IDs of the security groups to be added to all the user's instances to which the Cloudgate proxies must be able to connect. Typically these are the Origin cluster nodes. These IDs indicate which VPC the security groups belong to."
  value = aws_security_group.user_allow_traffic_from_peering_sg.*.id
}

output "user_to_cloudgate_security_group_ids" {
  description = "IDs of the security groups to be added to all Cloudgate proxy instances to enable them to receive connections from the user's instances. These IDs indicate which VPC the security groups belong to."
  value = aws_security_group.cloudgate_allow_traffic_from_peering_sg.*.id
}