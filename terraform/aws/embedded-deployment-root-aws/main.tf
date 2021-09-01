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
  profile = var.user_aws_profile
  region  = var.aws_region
}

module "instances" {
  source = "../submodules-aws/instances-aws"

  // top level variables
  aws_profile = var.user_aws_profile
  aws_region = var.aws_region
  cloudgate_public_key_localpath = var.keypair_localpath
  cloudgate_keypair_name = var.keypair_name

  // variable wirings for the instance module
  proxy_instance_count = var.proxy_instance_count
  proxy_instance_type = var.proxy_instance_type
  monitoring_instance_type = var.monitoring_instance_type

  // variables from modules
  private_subnet_ids = var.user_subnet_ids
  public_subnet_id = var.user_subnet_ids[0]

  //proxy_security_group_ids = [module.proxy_networking.private_instance_sg_id]
  proxy_security_group_ids = var.user_proxy_security_group_ids

  monitoring_security_group_ids = var.user_monitoring_security_group_ids
}