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
resource "aws_vpc" "cloudgate_vpc" {
  cidr_block = "${var.aws_cloudgate_vpc_cidr_prefix}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "cloudgate_vpc"
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
  vpc_id = aws_vpc.cloudgate_vpc.id
  cidr_block = "${var.aws_cloudgate_vpc_cidr_prefix}.${10+count.index}.0/24"
  availability_zone= data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "private_subnet_${data.aws_availability_zones.available.names[count.index]}"
  }
}

##################################################
## Route table associated to the private subnets
## Important: routes cannot be defined inline here as it would conflict with adding standalone routes later.
## This is important for the VPC peering later on
##################################################
resource "aws_route_table" "private_subnet_rt" {
  vpc_id = aws_vpc.cloudgate_vpc.id
  route = []
}

resource "aws_route_table_association" "private_subnet_rta" {
  count = length(aws_subnet.private_subnets)

  subnet_id = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_subnet_rt.id
}

resource aws_route "proxy_to_nat" {
  route_table_id = aws_route_table.private_subnet_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gateway.id
}

####################################
## Public subnet for the NAT gateway 
####################################
resource "aws_subnet" "public_subnet" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "${var.aws_cloudgate_vpc_cidr_prefix}.100.0/24"
  vpc_id = aws_vpc.cloudgate_vpc.id
  tags = {
    Name = "public_subnet_${data.aws_availability_zones.available.names[0]}"
  }
}

####################################
## Elastic IP for the NAT gateway 
####################################
resource "aws_eip" "nat_gateway_eip" {
  vpc      = true
}

####################################
## NAT gateway
####################################
resource "aws_nat_gateway" "nat_gateway" {
  connectivity_type = "public"
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id = aws_subnet.public_subnet.id
}

####################################
## Internet gateway
####################################
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.cloudgate_vpc.id

}

#########################################################
## Route table for internet gateway + association to it
#########################################################
resource "aws_route_table" "internet_gateway_rt" {
  vpc_id = aws_vpc.cloudgate_vpc.id
    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
}

resource "aws_route_table_association" "internet_gateway_rta" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.internet_gateway_rt.id
}

##################################################################################
## Main route table must contain a route to send outbound traffic to NAT gateway
##################################################################################
resource "aws_default_route_table" "default_route_table_for_vpc" {
  default_route_table_id = aws_vpc.cloudgate_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

######################################################################################
## Security Groups
## TODO finalise
######################################################################################
resource "aws_security_group" "public_instance_sg" {
  name = "public_instance_sg"
  vpc_id = aws_vpc.cloudgate_vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"] #TODO this could be restricted to an IP range
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  // Grafana UI
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
  }
  // Prometheus UI
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 9090
    to_port = 9090
    protocol = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
      Name = "public_instance_sg"
  }
}