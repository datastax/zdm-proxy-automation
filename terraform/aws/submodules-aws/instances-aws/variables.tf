variable "zdm_aws_profile" {}
variable "zdm_aws_region" {}

variable "zdm_public_key_local_path" {}
variable "zdm_keypair_name" {}


variable "ami" {
  description = "AMI to be used for this EC2 instance"
  type = map(string)
  default = {
    "us-east-1" = "ami-0bb5a904861ec247f"
    "us-east-2" = "ami-025227bc8f4c2cbdd"
    "us-west-1" = "ami-0558dde970ca91ee5"
    "us-west-2" = "ami-0bdef2eb518663879"

    "eu-west-1" = "ami-0c259a97cbf621daf"
    "eu-west-2" = "ami-013fadefd0ab548ef"
    "eu-west-3" = "ami-0e34a9addd905132f"
    "eu-central-1" = "ami-073375fc9e17516d6"
    "eu-north-1" = "ami-09f07498568488979"
    "eu-south-1" = "ami-016e7e862dbd5eb59"

    "ap-south-1" = "ami-07a4716f9f312e466"
  }
}

variable "zdm_proxy_instance_count" {}

variable "zdm_proxy_instance_type" {}

variable "zdm_monitoring_instance_type" {}

variable "private_subnet_ids" {
  description = "Private subnets IDs in the ZDM VPC"
}

variable "zdm_proxy_security_group_ids" {
  description = "Security group IDs to add to the proxy instances"
  type = list(string)
}

variable "zdm_monitoring_security_group_ids" {
  description = "Security group IDs to add to the monitoring instance"
  type = list(string)
}

variable "public_subnet_id" {
  description = "Public subnet ID in the ZDM VPC"
}

variable "custom_name_suffix" {}