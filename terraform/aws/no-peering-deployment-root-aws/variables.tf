variable "zdm_aws_profile" {}

variable "zdm_aws_region" {}

variable "zdm_proxy_instance_count" {}

variable "allowed_inbound_ip_ranges" {
  type = list(string)
  # defaults to everything (unrestricted)
  default = ["0.0.0.0/0"]
}

variable "allowed_outbound_ip_ranges" {
  type = list(string)
  # defaults to everything (unrestricted)
  default = ["0.0.0.0/0"]
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

variable "zdm_public_key_local_path" {
  description = "Path where the key pair is stored, without trailing slash"
  default = "~/.ssh"
}

variable "zdm_keypair_name" {}

variable "custom_name_suffix" {
  description = "Suffix to append to the name of all the resources that are being provisioned"
  default = ""
}

variable "owner" {
  description = "Owner of this set of infrastructure resources"
  default = ""
}

variable "zdm_linux_distro" {
  default = "noble"

  validation {
    condition     = can(regex("focal|jammy|noble|centos7|centos8|centos9|rocky8|rocky9|rhel7|rhel8", var.zdm_linux_distro))
    error_message = "Invalid Linux distro, allowed_values = [focal jammy noble centos7 centos8 centos9 rocky8 rocky9 rhel7 rhel8]."
  }
}
