variable "user_vpc_id" {}
variable "user_route_table_ids" {
  type = list(string)
}

variable "cloudgate_vpc_id" {}
variable "cloudgate_public_subnet_id" {}
variable "cloudgate_route_table_ids" {
  type = list(string)
}

variable "cloudgate_aws_profile" {}
variable "user_aws_profile" {
  // if not specified, this will default to the profile used for the Cloudgate infrastructure
  default = ""
}

variable "aws_region" {}

