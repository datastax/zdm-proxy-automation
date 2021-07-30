variable "aws_profile" {}

variable "aws_region" {}

variable "proxy_instance_count" {}

variable "aws_cloudgate_vpc_cidr_prefix" {
  default = "172.18"
}

variable "proxy_instance_type" {
  default = "c5.xlarge"
}

variable "monitoring_instance_type" {
  default = "c5.2xlarge"
}

variable "cloudgate_public_key_localpath" {
  # path where the key pair is stored, without trailing slash
  default = "~/.ssh"
}

variable "cloudgate_public_key_filename" {
  default = "cloudgate-key.pub"
}