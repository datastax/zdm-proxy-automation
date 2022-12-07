variable "zdm_aws_profile" {}
variable "zdm_aws_region" {}

variable "zdm_public_key_local_path" {}
variable "zdm_keypair_name" {}


variable "ami" {
  description = "AMI to be used for this EC2 instance"
  type = map(string)
  default = {
    "ap-south-1" = "ami-07ffb2f4d65357b42"
    "ap-south-2" = "ami-0d8d9a2de1bcdb066"
    "ap-southeast-1" = "ami-02045ebddb047018b"
    "ap-southeast-2" = "ami-0df609f69029c9bdb"
    "ap-southeast-3" = "ami-030e837d78f47cbb1"
    "eu-central-1" = "ami-06ce824c157700cd2"
    "eu-central-2" = "ami-0876b3d2f699dd5f3"
    "eu-north-1" = "ami-0fd303abd14827300"
    "eu-south-1" = "ami-03533c29d03faff35"
    "eu-south-2" = "ami-06a35994aaed77af8"
    "eu-west-1" = "ami-05e786af422f8082a"
    "eu-west-2" = "ami-07c2ae35d31367b3e"
    "eu-west-3" = "ami-03b755af568109dc3"
    "us-east-1" = "ami-0574da719dca65348"
    "us-east-2" = "ami-0283a57753b18025b"
    "us-west-1" = "ami-0a1a70369f0fce06a"
    "us-west-2" = "ami-0ecc74eca1d66d8a6"
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
