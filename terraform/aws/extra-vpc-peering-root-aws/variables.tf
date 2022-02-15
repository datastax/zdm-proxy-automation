variable "aws_region" {}

variable "cloudgate_aws_profile" {}

/*
 Specify user_aws_profile only if the AWS profile to be used to access the existing user's VPC is different to the one being used to create the Cloudgate infrastructure.
 If this variable is not specified on the command line, the profile will default to the one used to create the Cloudgate infrastructure.
*/
variable "user_aws_profile" {
  // if not specified, this will default to the profile used for the Cloudgate infrastructure
  default = ""
}

variable "user_vpc_id" {
  type = string
}

variable "user_route_table_ids" {
  type = list(string)
}

