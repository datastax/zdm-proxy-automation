variable "zdm_aws_profile" {}
variable "zdm_aws_region" {}

variable "zdm_public_key_local_path" {}
variable "zdm_keypair_name" {}

variable "zdm_proxy_instance_count" {}

variable "zdm_proxy_instance_type" {}

variable "zdm_monitoring_instance_type" {}

variable "private_subnet_ids" {
  description = "Private subnets IDs in the ZDM VPC"
}

variable "zdm_proxy_security_group_ids" {
  description = "Security group IDs to add to the proxy instances"
  type = list(string)
}

variable "zdm_monitoring_security_group_ids" {
  description = "Security group IDs to add to the monitoring instance"
  type = list(string)
}

variable "public_subnet_id" {
  description = "Public subnet ID in the ZDM VPC"
}

variable "custom_name_suffix" {}

variable "owner" {}

variable "zdm_linux_distro" {
  default = "noble"

  validation {
    condition     = can(regex("focal|jammy|noble|centos7|centos8|centos9|rocky8|rocky9|rhel7|rhel8", var.zdm_linux_distro))
    error_message = "Invalid Linux distro, allowed_values = [focal jammy noble centos7 centos8 centos9 rocky8 rocky9 rhel7 rhel8]."
  }
}
