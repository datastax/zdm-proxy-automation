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
## Cloudgate proxy instances
#############################
resource "aws_instance" "cloudgate_proxy" {
  count         = var.proxy_instance_count
  
  ami           = lookup(var.ami, var.aws_region)
  instance_type = var.proxy_instance_type
  key_name      = var.cloudgate_public_key
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
  key_name      = var.cloudgate_public_key
  
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


######################################################################################
## Test jumphost
## (Replace this with the enterprise's infra simulation)
## TODO REMOVE THIS COMPLETELY when deploying for customers:
## The only way into the proxy (including ssh) must be from the enterprise's own VPC
######################################################################################
resource "aws_instance" "ec2jumphost" {
  instance_type = "t2.micro"
  ami = lookup(var.ami, var.aws_region)
  subnet_id = var.public_subnet_id
  vpc_security_group_ids = var.jumphost_security_group_ids
  key_name = var.cloudgate_public_key
  associate_public_ip_address = true

  disable_api_termination = false
  ebs_optimized = false
  
  root_block_device {
    volume_size = "10"
  }

    tags = {
    Name = "JumpHost"
  }
}
