# See https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Scenario2.html

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

####################################
## VPC
####################################
resource "aws_vpc" "zdm_vpc" {
  cidr_block = "${var.zdm_vpc_cidr_prefix}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "zdm_vpc${var.custom_name_suffix}"
    Owner = var.owner
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

####################################
## Private subnets
####################################
resource "aws_subnet" "private_subnets" {
  count = length(data.aws_availability_zones.available.names)
  vpc_id = aws_vpc.zdm_vpc.id
  cidr_block = cidrsubnet(aws_vpc.zdm_vpc.cidr_block, 8, 10+count.index )
  availability_zone= data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "private_subnet_${data.aws_availability_zones.available.names[count.index]}${var.custom_name_suffix}"
    Owner = var.owner
  }
}

##################################################
## Route table associated to the private subnets
## Important: routes cannot be defined inline here as it would conflict with adding standalone routes later.
## This is important for the VPC peering later on
##################################################
resource "aws_route_table" "private_subnet_rt" {
  vpc_id = aws_vpc.zdm_vpc.id
  tags = {
    Name = "private_subnet_rt${var.custom_name_suffix}"
    Owner = var.owner
  }
}

resource "aws_route_table_association" "private_subnet_rta" {
  count = length(aws_subnet.private_subnets)

  subnet_id = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_subnet_rt.id
}

resource "aws_route" "proxy_to_nat" {
  route_table_id = aws_route_table.private_subnet_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway.id
}

######################################################################################
## Security Group for instances in private subnets
######################################################################################
resource "aws_security_group" "private_instance_sg" {
  name = "private_instance_sg"
  vpc_id = aws_vpc.zdm_vpc.id

  # Allow ssh connection from the public subnet (i.e. monitoring instance only)
  ingress {
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  # Allow Prometheus to pull proxy metrics
  ingress {
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
    from_port = 14001
    to_port = 14001
    protocol = "tcp"
  }

  # Allow Prometheus to pull OS node metrics
  ingress {
    cidr_blocks = [aws_subnet.public_subnet.cidr_block]
    from_port = 9100
    to_port = 9100
    protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = var.allowed_outbound_ip_ranges
  }

  tags = {
    Name = "private_instance_sg${var.custom_name_suffix}"
    Owner = var.owner
  }
}

########################################################
## Public subnet for the NAT and monitoring instance / jumphost
########################################################
resource "aws_subnet" "public_subnet" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = cidrsubnet(aws_vpc.zdm_vpc.cidr_block, 8, 100 )
  vpc_id = aws_vpc.zdm_vpc.id
  tags = {
    Name = "public_subnet_${data.aws_availability_zones.available.names[0]}${var.custom_name_suffix}"
    Owner = var.owner
  }
}

####################################
## NAT gateway + its elastic IP
####################################
resource "aws_nat_gateway" "nat_gateway" {
  connectivity_type = "public"
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id = aws_subnet.public_subnet.id
  tags = {
    Name = "zdm_nat_gateway${var.custom_name_suffix}"
    Owner = var.owner
  }
}

resource "aws_eip" "nat_gateway_eip" {
  vpc      = true
  tags = {
    Name = "zdm_nat_gateway_eip${var.custom_name_suffix}"
    Owner = var.owner
  }
}

##################################################################################
## Main route table must contain a route to send outbound traffic to NAT gateway
##################################################################################
resource "aws_default_route_table" "default_route_table_for_vpc" {
  default_route_table_id = aws_vpc.zdm_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "default_route_table"
    Owner = var.owner
  }
}

####################################
## Internet gateway
####################################
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.zdm_vpc.id
  tags = {
    Name = "zdm_internet_gateway${var.custom_name_suffix}"
    Owner = var.owner
  }
}

#########################################################
## Route table for internet gateway + association to it
#########################################################
resource "aws_route_table" "internet_gateway_rt" {
  vpc_id = aws_vpc.zdm_vpc.id
  tags = {
    Name = "zdm_internet_gateway_rt${var.custom_name_suffix}"
    Owner = var.owner
  }
}

resource "aws_route" "igw_route" {
  count = length(var.allowed_outbound_ip_ranges)

  route_table_id = aws_route_table.internet_gateway_rt.id
  destination_cidr_block = var.allowed_outbound_ip_ranges[count.index]
  gateway_id = aws_internet_gateway.internet_gateway.id
}

resource "aws_route_table_association" "internet_gateway_rta" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.internet_gateway_rt.id
}

######################################################################################
## Security Group for instances accessible from outside
######################################################################################
resource "aws_security_group" "public_instance_sg" {
  name = "public_instance_sg"
  vpc_id = aws_vpc.zdm_vpc.id

  // Inbound SSH from trusted VPNs
  ingress {
    cidr_blocks = var.allowed_inbound_ip_ranges
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  // Grafana UI
  ingress {
    cidr_blocks = var.allowed_inbound_ip_ranges
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
  }
  // Prometheus UI
  ingress {
    cidr_blocks = var.allowed_inbound_ip_ranges
    from_port = 9090
    to_port = 9090
    protocol = "tcp"
  }

  // Allow any incoming traffic from within the VPC
  ingress {
    cidr_blocks = [aws_vpc.zdm_vpc.cidr_block]
    from_port = 0
    to_port = 0
    protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = var.allowed_outbound_ip_ranges
  }

  tags = {
    Name = "public_instance_sg${var.custom_name_suffix}"
    Owner = var.owner
  }
}