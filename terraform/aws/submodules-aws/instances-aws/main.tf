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
resource "aws_key_pair" "cloudgate_key_pair" {
  key_name = var.cloudgate_key_name
  public_key = file("${var.cloudgate_public_key_localpath}/${var.cloudgate_public_key_filename}")

  tags = {
    Name = var.cloudgate_key_name
  }
}

#############################
## Cloudgate proxy instances
#############################
resource "aws_instance" "cloudgate_proxy" {
  count = var.proxy_instance_count
  
  ami = lookup(var.ami, var.aws_region)
  instance_type = var.proxy_instance_type
  key_name = var.cloudgate_key_name
  associate_public_ip_address = false

  subnet_id = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = var.proxy_security_group_ids
  
  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = {
    Name = "CloudgateProxy-${count.index}"
  }

}

#############################
## Monitoring instance
#############################
resource "aws_instance" "monitoring" {
  ami = lookup(var.ami, var.aws_region)
  instance_type = var.monitoring_instance_type
  key_name      = var.cloudgate_key_name
  
  subnet_id = var.public_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids = var.monitoring_security_group_ids

  root_block_device {
    volume_size = 200
    volume_type = "gp3"
  }

  tags = {
    Name = "MonitoringInstance"
  }
}
