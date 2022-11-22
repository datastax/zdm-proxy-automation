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
  profile = var.zdm_aws_profile
  region  = var.zdm_aws_region
}

// creates the ZDM VPC and all the networking infrastructure
module "zdm_proxy_networking" {
  source = "../submodules-aws/networking-aws"

  custom_name_suffix = var.custom_name_suffix
  zdm_aws_profile = var.zdm_aws_profile
  zdm_aws_region = var.zdm_aws_region

  // variable wirings for the networking module
  zdm_vpc_cidr_prefix = var.zdm_vpc_cidr_prefix

  allowed_inbound_ip_ranges = var.allowed_inbound_ip_ranges
  allowed_outbound_ip_ranges = var.allowed_outbound_ip_ranges
}

module "zdm_instances" {
  source = "../submodules-aws/instances-aws"

  custom_name_suffix = var.custom_name_suffix
  zdm_aws_profile = var.zdm_aws_profile
  zdm_aws_region = var.zdm_aws_region
  zdm_public_key_local_path = var.zdm_public_key_local_path
  zdm_keypair_name = var.zdm_keypair_name

  zdm_proxy_instance_count = var.zdm_proxy_instance_count
  zdm_proxy_instance_type = var.zdm_proxy_instance_type
  zdm_monitoring_instance_type = var.zdm_monitoring_instance_type

  private_subnet_ids = module.zdm_proxy_networking.zdm_private_subnet_ids
  public_subnet_id = module.zdm_proxy_networking.zdm_public_subnet_id

  zdm_proxy_security_group_ids = [module.zdm_proxy_networking.private_instance_sg_id]

  zdm_monitoring_security_group_ids = [module.zdm_proxy_networking.public_instance_sg_id]
}