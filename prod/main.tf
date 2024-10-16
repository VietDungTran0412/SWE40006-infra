variable "aws_region" {
  type = string
}
provider "aws" {
  region = var.aws_region
}
variable "database_engine" {
  type = string
}

variable "key_name" {
  type = string
}

variable "app_vpc_id" {
  type = string
}

locals {
  subnets = {
    private_subnet_1 = {
      cidr_block = "10.0.3.0/24"
      name       = "private_subnet_1"
    }
    private_subnet_2 = {
      cidr_block = "10.0.4.0/24"
      name       = "private_subnet_2"
    }
  }
  rtb_name = "private-rtb"
}

# Public route table
resource "aws_route_table" "private_rtb" {
  vpc_id = data.aws_vpc.app_vpc.id
  #   route {
  #     cidr_block = "0.0.0.0/0"
  #     gateway_id = aws_internet_gateway.app_vpc_igw.id
  #   }
  tags = {
    Name = local.rtb_name
  }
}

resource "aws_route_table_association" "rtb_associations" {
  for_each = {
    public_subnet_1 = aws_subnet.private_subnet_1.id
    public_subnet_2 = aws_subnet.private_subnet_2.id
  }
  route_table_id = aws_route_table.private_rtb.id
  subnet_id      = each.value
}

// Application VPC
data "aws_vpc" "app_vpc" {
  id = var.app_vpc_id
}

# Set up aws_subnet 2
resource "aws_subnet" "private_subnet_1" {
  vpc_id     = data.aws_vpc.app_vpc.id
  cidr_block = local.subnets.private_subnet_1.cidr_block
  tags = {
    "Provisioner" = "Terraform"
    Name          = local.subnets.private_subnet_1.name
  }
}

# Set up aws_subnet 2
resource "aws_subnet" "private_subnet_2" {
  vpc_id     = data.aws_vpc.app_vpc.id
  cidr_block = local.subnets.private_subnet_2.cidr_block
  tags = {
    "Provisioner" = "Terraform"
    Name          = local.subnets.private_subnet_2.name
  }
}



resource "aws_security_group" "db_sg" {
  vpc_id = data.aws_vpc.app_vpc.id # Ensure security group is in the same VPC

  name = "db_sg"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "TCP" # This allows all traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # This allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "db" {
  source     = "terraform-aws-modules/rds/aws"
  identifier = "onboardingdb"

  # Database engine settings
  engine               = "mysql"
  engine_version       = var.database_engine
  major_engine_version = "8.0"
  family               = "mysql8.0"

  # Database parameter group settings
  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  # Database option group settings
  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"
      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        }
      ]
    }
  ]

  create_db_subnet_group = true

  # Database credentials and configuration
  db_name           = "c6g1"
  username          = "dev"
  password          = "devpassword"
  storage_type      = "gp3"
  allocated_storage = 20
  instance_class    = "db.t3.micro"

  # Network settings
  subnet_ids             = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
  vpc_security_group_ids = [aws_security_group.db_sg.id]
}



variable "public_subnet_2" {
    type = string
    default = "subnet-074f6b1af2e64436e"
}

variable "public_subnet_1" {
    type = string
    default = "subnet-0a7a87290e2efb9a0"
}

resource "aws_security_group" "allow_8080" {
  name        = "allow-8080"
  description = "Security group that only allows traffic on port 8080"
  vpc_id      = var.app_vpc_id  # Replace with your actual VPC ID

  ingress {
    description = "Allow traffic on port 8080"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # This allows all incoming traffic; adjust as needed (e.g., for specific IP ranges)
  }
#     # Allow SSH traffic on port 22
#   ingress {
#     description = "Allow SSH traffic on port 22"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from any IP address, restrict this for security
#   }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-8080"
  }
}
data "aws_iam_role" "ec2_role" {
  name = "AllowEC2FullAccessS3"
}

resource "aws_instance" "prod_server_1" {
  ami           = "ami-0f71013b2c8bd2c29"       # The AMI for the CI server instance
  instance_type = "t2.micro"                    # The instance type (e.g., t2.micro, t3.medium)
  subnet_id     = var.public_subnet_1 # The subnet where the instance will launch
  key_name      = var.key_name
  # Corrected security group reference: Use ID instead of name
  vpc_security_group_ids      = [aws_security_group.allow_8080.id]
  associate_public_ip_address = false
  iam_instance_profile = data.aws_iam_role.ec2_role.id

  tags = {
    Name = "Prod Server" # Instance tag for identification
  }
}

resource "aws_instance" "prod_server_2" {
  ami           = "ami-0f71013b2c8bd2c29"       # The AMI for the CI server instance
  instance_type = "t2.micro"                    # The instance type (e.g., t2.micro, t3.medium)
  subnet_id     = var.public_subnet_2 # The subnet where the instance will launch
  key_name      = var.key_name
  # Corrected security group reference: Use ID instead of name
  vpc_security_group_ids      = [aws_security_group.allow_8080.id]
  associate_public_ip_address = false
  iam_instance_profile = data.aws_iam_role.ec2_role.id

  tags = {
    Name = "Prod Server" # Instance tag for identification
  }
}