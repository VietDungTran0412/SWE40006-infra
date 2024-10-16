variable "aws_region" {
  type        = string
  description = "aws-regions"
}

variable "database_engine" {
  type = string
}

variable "app_vpc_id" {
  type        = string
  description = "vpc-id"
}

variable "key_name" {
  type = string
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
  sonar_instance     = "Sonar Server"
  bucket_name        = ""
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
  vpc_id = data.aws_vpc.app_vpc.id # Ensure security group is in the same VPC

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

resource "aws_security_group" "sonar_server_sg" {
  vpc_id = data.aws_vpc.app_vpc.id # Ensure security group is in the same VPC

  name = "sonar_server_sg"

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

resource "aws_security_group" "test_server_sg" {
  vpc_id = data.aws_vpc.app_vpc.id # Ensure security group is in the same VPC

  name = "test_server_sg"

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
  ami           = var.ci_instance_ami           # The AMI for the CI server instance
  instance_type = var.ci_instance_type          # The instance type (e.g., t2.micro, t3.medium)
  subnet_id     = aws_subnet.public_subnet_1.id # The subnet where the instance will launch

  # Corrected security group reference: Use ID instead of name
  vpc_security_group_ids      = [aws_security_group.ci_server_sg.id]
  associate_public_ip_address = true

  # Corrected user_data to read from a file
  user_data = file("${path.module}/install_jenkins.sh")

  tags = {
    Name = local.ci_server_instance # Instance tag for identification
  }
}

resource "aws_instance" "sonar_server" {
  ami           = var.ci_instance_ami           # The AMI for the CI server instance
  instance_type = "t2.small"                    # The instance type (e.g., t2.micro, t3.medium)
  subnet_id     = aws_subnet.public_subnet_1.id # The subnet where the instance will launch

  # Corrected security group reference: Use ID instead of name
  vpc_security_group_ids      = [aws_security_group.sonar_server_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = local.sonar_instance # Instance tag for identification
  }
}

resource "aws_instance" "test_server" {
  ami           = "ami-0f71013b2c8bd2c29"       # The AMI for the CI server instance
  instance_type = "t2.micro"                    # The instance type (e.g., t2.micro, t3.medium)
  subnet_id     = aws_subnet.public_subnet_2.id # The subnet where the instance will launch
  key_name      = var.key_name
  # Corrected security group reference: Use ID instead of name
  vpc_security_group_ids      = [aws_security_group.test_server_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "Test Server" # Instance tag for identification
  }
}

module "report_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  bucket = "swin-c6g1-report-bucket"
  # Block public access (must disable these settings for public access)
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  # Public access bucket policy
  policy = file("${path.module}/s3_bucket_policy.json")
}


