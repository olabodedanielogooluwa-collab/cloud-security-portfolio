# Week 9 core build: VPC with public and private subnets, IGW, NAT Gateway
# Lab use only. NAT Gateway bills hourly, so destroy after testing.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# VPC: the isolated address space (65,536 IPs)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "week9-vpc" }
}

# Public subnet: instances here get a public IP automatically
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "week9-public-subnet" }
}

# Private subnet: no public IPs, no direct internet route
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "week9-private-subnet" }
}

# Internet Gateway: the VPC's door to the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "week9-igw" }
}

# Public route table: this one 0.0.0.0/0 -> IGW route is what makes a subnet "public"
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "week9-public-rt" }
}

# Association: a route table does nothing until it is attached to a subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Elastic IP: fixed public address required by the NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = { Name = "week9-nat-eip" }
}

# NAT Gateway: lives in the PUBLIC subnet, gives private instances outbound-only internet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags = { Name = "week9-nat-gw" }
  depends_on = [aws_internet_gateway.main]  # IGW must exist first
}

# Private route table: outbound traffic goes to the NAT Gateway, not the IGW
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "week9-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Test security group: SSH in, everything out (lab only, tighten in real use)
resource "aws_security_group" "test" {
  name   = "week9-test-sg"
  vpc_id = aws_vpc.main.id

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
  tags = { Name = "week9-test-sg" }
}

# Latest Amazon Linux 2023 AMI, looked up dynamically (no hardcoded AMI ID)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Test instance in the public subnet: should receive a public IP
resource "aws_instance" "public_test" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.test.id]
  tags = { Name = "week9-public-test" }
}

# Test instance in the private subnet: should have NO public IP
resource "aws_instance" "private_test" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.test.id]
  tags = { Name = "week9-private-test" }
}
