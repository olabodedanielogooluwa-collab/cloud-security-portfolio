# Incident 3: database instance deployed into the wrong (public) subnet
# Standalone demo. Intentionally insecure BEFORE state, lab only.

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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "subnet-demo-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "subnet-demo-public" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "subnet-demo-private" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "subnet-demo-igw" }
}

# Only the public subnet gets a route to the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "subnet-demo-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private route table has no internet route at all
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "subnet-demo-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# Deliberately open MySQL port. Bad practice, kept to show that placement
# alone neutralizes exposure even with a weak security group.
resource "aws_security_group" "db" {
  name   = "subnet-demo-db-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "subnet-demo-db-sg" }
}

data "aws_ami" "al" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# BEFORE (bug): subnet_id = aws_subnet.public.id -> database exposed to the internet
# AFTER (fix):  subnet_id = aws_subnet.private.id -> no route from the IGW
# Changing subnet_id forces destroy and recreate (plan shows -/+), not an in-place edit
resource "aws_instance" "db" {
  ami                    = data.aws_ami.al.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db.id]
  tags = { Name = "subnet-demo-db" }
}
