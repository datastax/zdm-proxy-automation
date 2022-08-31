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

#############################
## ZDM proxy instances
#############################
resource "aws_instance" "zdm_proxy" {
  count = var.zdm_proxy_instance_count
  
  ami = lookup(var.ami, var.zdm_aws_region)
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
    Name = "ZdmProxy-${count.index}"
  }

}

#############################
## ZDM Jumphost / Monitoring instance
#############################
resource "aws_instance" "zdm_monitoring" {
  ami = lookup(var.ami, var.zdm_aws_region)
  instance_type = var.zdm_monitoring_instance_type
  key_name      = aws_key_pair.zdm_key_pair.key_name
  
  subnet_id = var.public_subnet_id

  vpc_security_group_ids = var.zdm_monitoring_security_group_ids

  root_block_device {
    volume_size = 200
    volume_type = "gp3"
  }

  tags = {
    Name = "ZdmMonitoringInstance"
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
  }
  )
  filename = "zdm_ssh_config"
}
