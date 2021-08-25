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

// creates the Cloudgate VPC and all the networking infrastructure
module "proxy_networking" {
  source = "../submodules-aws/networking-aws"

  aws_profile = var.cloudgate_aws_profile
  aws_region = var.aws_region

  // variable wirings for the networking module
  aws_cloudgate_vpc_cidr_prefix = var.aws_cloudgate_vpc_cidr_prefix

  whitelisted_inbound_ip_ranges = var.whitelisted_inbound_ip_ranges
  whitelisted_outbound_ip_ranges = var.whitelisted_outbound_ip_ranges
}

// peers the Cloudgate VPC with all the existing VPCs specified by the user
module "vpc_peering" {
  source = "../submodules-aws/vpc-peering-aws"

  aws_region = var.aws_region

  cloudgate_aws_profile = var.cloudgate_aws_profile
  // if no user AWS profile was specified, default the user AWS profile to the Cloudgate AWS profile
  user_aws_profile = (var.user_aws_profile != "" ? var.user_aws_profile : var.cloudgate_aws_profile)

  cloudgate_vpc_id = module.proxy_networking.cloudgate_vpc_id
  cloudgate_route_table_ids = tolist([module.proxy_networking.private_subnet_route_table_id, module.proxy_networking.public_subnet_route_table_id])
  user_vpc_id = var.user_vpc_id
  user_route_table_ids = var.user_route_table_ids
}

module "instances" {
  source = "../submodules-aws/instances-aws"

  // top level variables
  aws_profile = var.cloudgate_aws_profile
  aws_region = var.aws_region
  cloudgate_public_key_localpath = var.cloudgate_public_key_localpath
  cloudgate_keypair_name = var.cloudgate_keypair_name

  // variable wirings for the instance module
  proxy_instance_count = var.proxy_instance_count
  proxy_instance_type = var.proxy_instance_type
  monitoring_instance_type = var.monitoring_instance_type

  // variables from modules
  private_subnet_ids = module.proxy_networking.cloudgate_private_subnet_ids
  public_subnet_id = module.proxy_networking.cloudgate_public_subnet_id

  //proxy_security_group_ids = [module.proxy_networking.private_instance_sg_id]
  proxy_security_group_ids = concat(module.vpc_peering.user_to_cloudgate_security_group_ids,[module.proxy_networking.private_instance_sg_id])

  monitoring_security_group_ids = [module.proxy_networking.public_instance_sg_id]
}