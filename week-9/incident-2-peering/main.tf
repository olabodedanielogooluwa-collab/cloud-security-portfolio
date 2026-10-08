# Incident 2: VPC peering with a one-sided route
# Standalone demo (separate from core-vpc). No NAT Gateway, so it is cheap.

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

# VPC A and VPC B: CIDRs must NOT overlap or peering is impossible
resource "aws_vpc" "a" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "peering-vpc-a" }
}

resource "aws_vpc" "b" {
  cidr_block = "10.1.0.0/16"
  tags = { Name = "peering-vpc-b" }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.a.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "peering-subnet-a" }
}

resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.b.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "peering-subnet-b" }
}

resource "aws_route_table" "a" {
  vpc_id = aws_vpc.a.id
  tags = { Name = "peering-rt-a" }
}

resource "aws_route_table" "b" {
  vpc_id = aws_vpc.b.id
  tags = { Name = "peering-rt-b" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.a.id
  route_table_id = aws_route_table.a.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.b.id
  route_table_id = aws_route_table.b.id
}

# Peering connection: auto_accept works because both VPCs are in the same account
resource "aws_vpc_peering_connection" "ab" {
  vpc_id      = aws_vpc.a.id
  peer_vpc_id = aws_vpc.b.id
  auto_accept = true
  tags = { Name = "peering-a-b" }
}

# Route A -> B
resource "aws_route" "a_to_b" {
  route_table_id            = aws_route_table.a.id
  destination_cidr_block    = aws_vpc.b.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.ab.id
}

# Route B -> A: this is the FIX. BEFORE state = this block missing,
# so replies have no way back and the whole TCP connection fails.
resource "aws_route" "b_to_a" {
  route_table_id            = aws_route_table.b.id
  destination_cidr_block    = aws_vpc.a.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.ab.id
}

# Security groups: allow SSH between both VPC CIDRs
resource "aws_security_group" "a" {
  name   = "peering-sg-a"
  vpc_id = aws_vpc.a.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "peering-sg-a" }
}

resource "aws_security_group" "b" {
  name   = "peering-sg-b"
  vpc_id = aws_vpc.b.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16", "10.1.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "peering-sg-b" }
}

data "aws_ami" "al" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# One test instance per VPC
resource "aws_instance" "a" {
  ami                    = data.aws_ami.al.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.a.id
  vpc_security_group_ids = [aws_security_group.a.id]
  tags = { Name = "peering-instance-a" }
}

resource "aws_instance" "b" {
  ami                    = data.aws_ami.al.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.b.id
  vpc_security_group_ids = [aws_security_group.b.id]
  tags = { Name = "peering-instance-b" }
}
