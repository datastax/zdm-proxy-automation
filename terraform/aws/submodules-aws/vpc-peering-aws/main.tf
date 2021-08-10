## Requester = Cloudgate
## Accepter = User

provider "aws" {
  alias = "cloudgate"
  profile = var.cloudgate_aws_profile
  region = var.aws_region
  # Requester's credentials (Cloudgate)
}

provider "aws" {
  alias = "user"
  profile = var.user_aws_profile
  region = var.aws_region
  # Accepter's credentials. (User)
}

data "aws_vpc" "cloudgate_vpc" {
  id = var.cloudgate_vpc_id
}

data "aws_vpc" "user_vpc" {
  id = var.user_vpc_id
}

# User's account details
data "aws_caller_identity" "user_identity" {
  provider = aws.user
}

# Cloudgate requests a peering connection
resource "aws_vpc_peering_connection" "peering_request" {
  provider = aws.cloudgate

  vpc_id        = data.aws_vpc.cloudgate_vpc.id
  peer_vpc_id   = data.aws_vpc.user_vpc.id
  peer_owner_id = data.aws_caller_identity.user_identity.account_id
  auto_accept   = false

  tags = {
    Side = "Cloudgate (Requester)"
  }
}

# User accepts the peering connection request
resource "aws_vpc_peering_connection_accepter" "peering_acceptance" {
  provider = aws.user

  vpc_peering_connection_id = aws_vpc_peering_connection.peering_request.id
  auto_accept               = true

  tags = {
    Side = "User (Accepter)"
  }
}

# On the Cloudgate side, set the peering connection id taken from the acceptance of the request
resource "aws_vpc_peering_connection_options" "requester_options" {
  provider = aws.cloudgate

  # As options can't be set until the connection has been accepted
  # create an explicit dependency on the accepter.
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peering_acceptance.id

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

# On the User side, set the peering connection id taken from the acceptance of the request
resource "aws_vpc_peering_connection_options" "accepter_options" {
  provider = aws.user

  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peering_acceptance.id

  accepter {
    allow_remote_vpc_dns_resolution = true
  }
}

# Add routes to the route table to enable two-way communication over the VPC peering

/**
 * Creates a new route rule on the Cloudgate VPC main route table. All requests
 * to the User VPC's IP range will be directed to the VPC peering
 * connection.
 */
resource "aws_route" "cloudgate_to_user" {
  provider = aws.cloudgate

  //route_table_id            = data.aws_vpc.cloudgate_vpc.main_route_table_id
  route_table_id = var.cloudgate_proxy_route_table_id
  destination_cidr_block    = data.aws_vpc.user_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peering_acceptance.id
}

/*
resource "aws_route_table_association" "private_subnet_rta" {
  count = length(aws_subnet.private_subnets)

  subnet_id = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_subnet_rt.id
}
*/

/**
 * Creates a new route rule on the User VPC main route table. All requests
 * to the Cloudgate VPC's IP range will be directed to the VPC peering
 * connection.
 */
resource "aws_route" "user_to_cloudgate" {
  provider = aws.user

  count = length(var.user_route_table_ids)
  //route_table_id            = data.aws_vpc.user_vpc.main_route_table_id
  //route_table_id = var.user_route_table_id != "" ? var.user_route_table_id : data.aws_vpc.user_vpc.main_route_table_id
  route_table_id = var.user_route_table_ids[count.index]
  destination_cidr_block    = data.aws_vpc.cloudgate_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peering_acceptance.id
}

# Add security group on each side of the peering to allow inbound SSH from the other side of the peering

resource "aws_security_group" "cloudgate_allow_traffic_from_peering_sg" {
  provider = aws.cloudgate

  name = "cloudgate_allow_traffic_from_peering_sg"
  vpc_id = data.aws_vpc.cloudgate_vpc.id
  ingress {
    description      = "Inbound traffic from user VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.user_vpc.cidr_block]
  }

  // Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "user_allow_traffic_from_peering_sg" {
  provider = aws.user

  name = "user_allow_traffic_from_peering_sg"
  vpc_id = data.aws_vpc.user_vpc.id
  ingress {
    description      = "Inbound traffic from Cloudgate VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.cloudgate_vpc.cidr_block]
  }

//  ingress {
//    description      = "Inbound Native Cassandra Protocol from Cloudgate VPC"
//    from_port        = 9042
//    to_port          = 9042
//    protocol         = "tcp"
//    cidr_blocks      = [data.aws_vpc.cloudgate_vpc.cidr_block]
//  }

  // Not adding the default egress rule here to avoid interfering with other restrictive egress rules that the user may have set

}
