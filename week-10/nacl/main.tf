terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" { default = "us-east-1" }
variable "vpc_id" {}
variable "my_ip"  {}

# Dedicated test subnet inside the default VPC
resource "aws_subnet" "test" {
  vpc_id            = var.vpc_id
  cidr_block        = "172.31.96.0/24"
  availability_zone = "${var.region}a"
  tags              = { Name = "wk10-test-subnet" }
}

resource "aws_network_acl" "wk10" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.test.id]
  tags       = { Name = "wk10-nacl" }

  # Inbound
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "${var.my_ip}/32"
    from_port  = 22
    to_port    = 22
  }
  ingress {
    rule_no    = 120   # replies to connections this subnet starts
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  egress {
    rule_no    = 120   # replies to inbound 443 and 22 go to the client's high port
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
}
