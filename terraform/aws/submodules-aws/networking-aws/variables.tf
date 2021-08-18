variable "aws_profile" {}

variable "aws_region" {}

variable "aws_cloudgate_vpc_cidr_prefix" {}

variable "whitelisted_inbound_ip_ranges" {
  type = list
  # defaults to Santa Clara VPN IP range
  default = ["38.99.104.112/28"]
}

variable "whitelisted_outbound_ip_ranges" {
  type = list
  # defaults to everything (unrestricted)
  default = ["0.0.0.0/0"]
}
