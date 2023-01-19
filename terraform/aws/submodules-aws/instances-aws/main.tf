terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

#############################
## AWS Key Pair
#############################
resource "aws_key_pair" "zdm_key_pair" {
  key_name = var.zdm_keypair_name
  public_key = file(format("%s/%s.pub", var.zdm_public_key_local_path, var.zdm_keypair_name))

  tags = {
    Name = var.zdm_keypair_name
  }
}

############################
## AMI ID from Linux distro
############################
locals {
    allowed_linux_distros = {
    bionic = { owner = "amazon", name_pattern = "ubuntu/images/*/ubuntu-*-18.04-*", linux_user = "ubuntu" }
    focal = { owner = "amazon", name_pattern = "ubuntu/images/*/ubuntu-*-20.04-*", linux_user = "ubuntu" }
    jammy = { owner = "amazon", name_pattern = "ubuntu/images/*/ubuntu-*-22.04-*", linux_user = "ubuntu" }
    centos7 = { owner = "125523088429", name_pattern = "CentOS Linux 7*", linux_user = "centos" }
    centos8 = { owner = "125523088429", name_pattern = "CentOS Stream 8*", linux_user = "centos" }
    centos9 = { owner = "125523088429", name_pattern = "CentOS Stream 9*", linux_user = "ec2-user" }
    rocky8 = { owner = "679593333241", name_pattern = "Rocky-8*", linux_user = "rocky" }
    rocky9 = { owner = "679593333241", name_pattern = "Rocky-9*", linux_user = "rocky" }
  }
}

data "aws_ami" "linux_distro" {
  for_each = local.allowed_linux_distros

  most_recent = true
  owners = [each.value.owner]

  filter {
    name = "name"
    values = [each.value.name_pattern]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

#############################
## ZDM proxy instances
#############################
resource "aws_instance" "zdm_proxy" {
  count = var.zdm_proxy_instance_count
  
  ami = data.aws_ami.linux_distro[var.zdm_linux_distro].id
  instance_type = var.zdm_proxy_instance_type
  key_name = aws_key_pair.zdm_key_pair.key_name
  associate_public_ip_address = false

  subnet_id = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = var.zdm_proxy_security_group_ids
  
  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "ZDM_Proxy_${count.index}${var.custom_name_suffix}"
  }

}

#############################
## ZDM Jumphost / Monitoring instance
#############################
resource "aws_instance" "zdm_monitoring" {
  ami = data.aws_ami.linux_distro[var.zdm_linux_distro].id
  instance_type = var.zdm_monitoring_instance_type
  key_name      = aws_key_pair.zdm_key_pair.key_name
  
  subnet_id = var.public_subnet_id

  vpc_security_group_ids = var.zdm_monitoring_security_group_ids

  root_block_device {
    volume_size = 200
    volume_type = "gp3"
  }

  tags = {
    Name = "ZDM_Monitoring${var.custom_name_suffix}"
  }
}

resource "aws_eip" "zdm_monitoring_eip" {
  vpc      = true
}

resource "aws_eip_association" "zdm_monitoring_eip_assoc" {
  instance_id   = aws_instance.zdm_monitoring.id
  allocation_id = aws_eip.zdm_monitoring_eip.id
}

###################################
## Generation of Ansible inventory
###################################
resource "local_file" "zdm_ansible_inventory" {
  content = templatefile("${path.module}/templates/zdm_ansible_inventory.tpl",
    {
      zdm_proxy_private_ips = aws_instance.zdm_proxy.*.private_ip
      zdm_monitoring_private_ip = aws_instance.zdm_monitoring.private_ip
      zdm_linux_user = local.allowed_linux_distros[var.zdm_linux_distro].linux_user
    }
  )
  filename = "zdm_ansible_inventory"
}

######################################################
## Generation of ZDM SSH config file for ProxyJump
######################################################
resource "local_file" "zdm_ssh_config" {
  content = templatefile("${path.module}/templates/zdm_ssh_config.tpl",
  {
    zdm_proxy_private_ips = aws_instance.zdm_proxy.*.private_ip
    jumphost_private_ip = aws_instance.zdm_monitoring.private_ip
    jumphost_public_ip = aws_eip.zdm_monitoring_eip.public_ip
    keypath = var.zdm_public_key_local_path
    keyname = var.zdm_keypair_name
    zdm_linux_user = local.allowed_linux_distros[var.zdm_linux_distro].linux_user
  }
  )
  filename = "zdm_ssh_config"
}
