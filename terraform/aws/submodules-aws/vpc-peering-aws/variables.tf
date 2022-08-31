variable "user_vpc_id" {}
variable "user_route_table_ids" {
  type = list(string)
}

variable "zdm_vpc_id" {}
variable "zdm_route_table_ids" {
  type = list(string)
}

variable "zdm_aws_profile" {}
variable "user_aws_profile" {
  // if not specified, this will default to the profile used for the ZDM infrastructure
  default = ""
}

variable "zdm_aws_region" {}

