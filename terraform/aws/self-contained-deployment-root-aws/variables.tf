variable "zdm_aws_region" {}

variable "zdm_proxy_instance_count" {}

variable "zdm_aws_profile" {}

/*
 Specify user_aws_profile only if the AWS profile to be used to access the existing user's VPC is different to the one being used to create the ZDM infrastructure.
 If this variable is not specified on the command line, the profile will default to the one used to create the ZDM infrastructure.
*/
variable "user_aws_profile" {
  // if not specified, this will default to the profile used for the ZDM infrastructure
  default = ""
}

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

variable "user_vpc_id" {
  // TODO make this a list of strings so the user can specify multiple VPCs if necessary
  type = string
}

variable "user_route_table_ids" {
  type = list(string)
}

variable "zdm_vpc_cidr_prefix" {
  default = "172.18"
}

variable "zdm_proxy_instance_type" {
  default = "c5.xlarge"
}

variable "zdm_monitoring_instance_type" {
  default = "c5.2xlarge"
}

variable "zdm_public_key_localpath" {
  # path where the key pair is stored, without trailing slash
  default = "~/.ssh"
}

variable "zdm_keypair_name" {}

