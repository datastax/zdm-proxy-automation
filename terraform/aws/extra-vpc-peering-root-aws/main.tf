terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = var.cloudgate_aws_profile
  region  = var.aws_region
}

data "aws_vpc" "cloudgate_vpc" {
  tags = {
    Name = "cloudgate_vpc"
  }
}

data "aws_route_table" "cloudgate_private_subnet_route_table" {
  vpc_id = data.aws_vpc.cloudgate_vpc.id

  # Within the VPC's route tables, this is necessary to identify only the route table used by the private subnets
  tags = {
    Name = "private_subnet_rt"
  }

}

// peers the Cloudgate VPC with all the existing VPCs specified by the user
module "vpc_peering" {
  source = "../submodules-aws/vpc-peering-aws"

  aws_region = var.aws_region
  cloudgate_aws_profile = var.cloudgate_aws_profile
  // if no user AWS profile was specified, default the user AWS profile to the Cloudgate AWS profile
  user_aws_profile = (var.user_aws_profile != "" ? var.user_aws_profile : var.cloudgate_aws_profile)

  cloudgate_vpc_id = data.aws_vpc.cloudgate_vpc.id
  #cloudgate_route_table_ids = tolist([module.proxy_networking.private_subnet_route_table_id])
  cloudgate_route_table_ids = [data.aws_route_table.cloudgate_private_subnet_route_table.id]
  user_vpc_id = var.user_vpc_id
  user_route_table_ids = var.user_route_table_ids
}
