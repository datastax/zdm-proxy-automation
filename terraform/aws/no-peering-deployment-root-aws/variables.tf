variable "aws_region" {}

variable "proxy_instance_count" {}

variable "cloudgate_aws_profile" {}

variable "whitelisted_inbound_ip_ranges" {
  type = list(string)
  # defaults to Santa Clara VPN IP range
  default = ["38.99.104.112/28"]
}

variable "whitelisted_outbound_ip_ranges" {
  type = list(string)
  # defaults to everything (unrestricted)
  default = ["0.0.0.0/0"]
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

variable "cloudgate_public_key_localpath" {
  # path where the key pair is stored, without trailing slash
  default = "~/.ssh"
}

variable "cloudgate_keypair_name" {}

