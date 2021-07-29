variable "aws_profile" {}

variable "aws_region" {}

variable "cloudgate_public_key" {}

variable "proxy_instance_count" {
  default = "3"
}

variable "aws_cloudgate_vpc_cidr_prefix" {
  default = "172.18"
}

variable "proxy_instance_type" {
  default = "c5.xlarge"
}

variable "monitoring_instance_type" {
  default = "c5.2xlarge"
}