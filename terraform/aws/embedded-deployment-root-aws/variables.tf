variable "aws_region" {}

variable "proxy_instance_count" {}

variable "user_aws_profile" {}

variable "user_subnet_ids" {
  type = list(string)
}

variable "user_proxy_security_group_ids" {
  type = list(string)
}

variable "user_monitoring_security_group_ids" {
  type = list(string)
}

variable "proxy_instance_type" {
  default = "c5.xlarge"
}

variable "monitoring_instance_type" {
  default = "c5.2xlarge"
}

variable "keypair_localpath" {
  # path where the key pair is stored, without trailing slash
  default = "~/.ssh"
}

variable "keypair_name" {}

