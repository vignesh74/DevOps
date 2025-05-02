terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "usw1"
  region = "us-west-1"
}

# Lookup the latest Amazon Linux 2 AMI per region
data "aws_ami" "amzn2_use1" {
  provider    = aws.use1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_ami" "amzn2_usw1" {
  provider    = aws.usw1
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPCs
resource "aws_vpc" "vpc_use1" {
  provider             = aws.use1
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_vpc" "vpc_usw1" {
  provider             = aws.usw1
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnets
resource "aws_subnet" "subnet_use1" {
  provider          = aws.use1
  vpc_id            = aws_vpc.vpc_use1.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "subnet_usw1" {
  provider          = aws.usw1
  vpc_id            = aws_vpc.vpc_usw1.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-west-1b"
}

# Internet Gateways
resource "aws_internet_gateway" "igw_use1" {
  provider = aws.use1
  vpc_id   = aws_vpc.vpc_use1.id
}

resource "aws_internet_gateway" "igw_usw1" {
  provider = aws.usw1
  vpc_id   = aws_vpc.vpc_usw1.id
}

# Route Tables
resource "aws_route_table" "rt_use1" {
  provider = aws.use1
  vpc_id   = aws_vpc.vpc_use1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_use1.id
  }
}

resource "aws_route_table" "rt_usw1" {
  provider = aws.usw1
  vpc_id   = aws_vpc.vpc_usw1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_usw1.id
  }
}

# Route table associations
resource "aws_route_table_association" "assoc_use1" {
  provider       = aws.use1
  subnet_id      = aws_subnet.subnet_use1.id
  route_table_id = aws_route_table.rt_use1.id
}

resource "aws_route_table_association" "assoc_usw1" {
  provider       = aws.usw1
  subnet_id      = aws_subnet.subnet_usw1.id
  route_table_id = aws_route_table.rt_usw1.id
}

# Security groups
resource "aws_security_group" "nginx_use1" {
  provider = aws.use1
  name     = "nginx-sg-use1"
  vpc_id   = aws_vpc.vpc_use1.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nginx_usw1" {
  provider = aws.usw1
  name     = "nginx-sg-usw1"
  vpc_id   = aws_vpc.vpc_usw1.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instances with NGINX install
resource "aws_instance" "ec2_use1" {
  provider                  = aws.use1
  ami                       = data.aws_ami.amzn2_use1.id
  instance_type             = "t2.micro"
  subnet_id                 = aws_subnet.subnet_use1.id
  vpc_security_group_ids    = [aws_security_group.nginx_use1.id]
  associate_public_ip_address = true
  key_name                  = "120425" # Replace with your key pair name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install nginx1 -y
              sudo systemctl enable nginx
              sudo systemctl start nginx
              EOF

  tags = {
    Name = "nginx-use1"
  }
}

resource "aws_instance" "ec2_usw1" {
  provider                  = aws.usw1
  ami                       = data.aws_ami.amzn2_usw1.id
  instance_type             = "t2.micro"
  subnet_id                 = aws_subnet.subnet_usw1.id
  vpc_security_group_ids    = [aws_security_group.nginx_usw1.id]
  associate_public_ip_address = true
  key_name                  = "120425" # Replace with your key pair name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install nginx1 -y
              sudo systemctl enable nginx
              sudo systemctl start nginx
              EOF

  tags = {
    Name = "nginx-usw1"
  }
}

# Outputs
output "ec2_use1_public_ip" {
  value = aws_instance.ec2_use1.public_ip
}

output "ec2_usw1_public_ip" {
  value = aws_instance.ec2_usw1.public_ip
}

