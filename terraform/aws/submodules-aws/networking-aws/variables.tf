variable "zdm_aws_profile" {}

variable "zdm_aws_region" {}

variable "zdm_vpc_cidr_prefix" {}

variable "whitelisted_inbound_ip_ranges" {
  type = list
}

variable "whitelisted_outbound_ip_ranges" {
  type = list
  # defaults to everything (unrestricted)
  default = ["0.0.0.0/0"]
}

variable "custom_name_suffix" {}