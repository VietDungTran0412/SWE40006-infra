variable "aws_region" {
  type        = string
  description = "aws-regions"
}
variable "app_vpc_id" {
  type        = string
  description = "vpc-id"
}

variable "ci_instance_ami" {
  type = string
}

variable "ci_instance_type" {
  type = string
}

provider "aws" {
  region = "ap-southeast-2"
}

// Application VPC
data "aws_vpc" "app_vpc" {
  id = var.app_vpc_id
}

# Local variables
locals {
  subnets = {
    public_subnet_1 = {
      cidr_block = "10.0.1.0/24"
      name       = "public_subnet_1"
    }
    public_subnet_2 = {
      cidr_block = "10.0.2.0/24"
      name       = "public_subnet_2"
    }
  }
  rtb_name           = "public_rtb"
  ci_server_instance = "CI Server"
}

# Set up internet gateway
resource "aws_internet_gateway" "app_vpc_igw" {
  vpc_id = data.aws_vpc.app_vpc.id
}

# Set up aws_subnet
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = data.aws_vpc.app_vpc.id
  cidr_block = local.subnets.public_subnet_1.cidr_block
  tags = {
    "Provisioner" = "Terraform"
    Name          = local.subnets.public_subnet_1.name
  }
}

# Set up aws_subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = data.aws_vpc.app_vpc.id
  cidr_block = local.subnets.public_subnet_2.cidr_block
  tags = {
    "Provisioner" = "Terraform"
    Name          = local.subnets.public_subnet_2.name
  }
}

# Public route table
resource "aws_route_table" "public_rtb" {
  vpc_id = data.aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_vpc_igw.id
  }
  tags = {
    Name = local.rtb_name
  }
}

resource "aws_route_table_association" "rtb_associations" {
  for_each = {
    public_subnet_1 = aws_subnet.public_subnet_1.id
    public_subnet_2 = aws_subnet.public_subnet_2.id
  }
  route_table_id = aws_route_table.public_rtb.id
  subnet_id      = each.value
}


resource "aws_security_group" "ci_server_sg" {
  name = "ci_server_sg"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # This allows all traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # This allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "ci_server" {
  ami             = var.ci_instance_ami
  instance_type   = var.ci_instance_type
  subnet_id       = aws_subnet.public_subnet_1.id
  security_groups = [aws_security_group.ci_server_sg.name]
  tags = {
    Name = local.ci_server_instance
  }
}