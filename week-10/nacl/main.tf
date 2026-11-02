# Week 10 Step 2: NACL with a break/fix switch for the return-path drill

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region   # region comes from the variable below
}

variable "region" { default = "us-east-1" }

variable "vpc_id" {}    # set in terraform.tfvars
variable "my_ip" {}     # passed at plan time, no default on purpose

# The drill switch: true removes the outbound reply rule (the "break")
variable "break_reply" { default = false }

# Test subnet: a small /24 inside the default VPC
resource "aws_subnet" "test" {
  vpc_id            = var.vpc_id
  cidr_block        = "172.31.96.0/24"    # free range, no overlap with existing /20s
  availability_zone = "${var.region}a"
  tags              = { Name = "wk10-test-subnet" }
}

# Custom NACL attached to the test subnet. Stateless: replies need their own rules.
resource "aws_network_acl" "wk10" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.test.id]
  tags       = { Name = "wk10-nacl" }

  # INBOUND: web traffic from anywhere
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # INBOUND: SSH from my IP only
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "${var.my_ip}/32"
    from_port  = 22
    to_port    = 22
  }

  # INBOUND: replies to connections the subnet starts (ephemeral ports)
  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # OUTBOUND: HTTPS out
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # OUTBOUND: HTTP out
  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # OUTBOUND: replies to inbound requests go to the client's high port.
  # Removed when break_reply = true. This is the rule the drill breaks.
  dynamic "egress" {
    for_each = var.break_reply ? [] : [1]
    content {
      rule_no    = 120
      action     = "allow"
      protocol   = "tcp"
      cidr_block = "0.0.0.0/0"
      from_port  = 1024
      to_port    = 65535
    }
  }
}

# Existing web SG from Step 1 (allows 443 in), so only the NACL can block traffic
data "aws_security_group" "web" {
  name   = "wk10-web-sg"
  vpc_id = var.vpc_id
}

# Latest Amazon Linux 2023 image
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Test target for Reachability Analyzer. No key pair: we only test the path.
resource "aws_instance" "test" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.test.id
  vpc_security_group_ids      = [data.aws_security_group.web.id]
  associate_public_ip_address = true   # needed so the internet gateway can reach it
  tags                        = { Name = "wk10-test-instance" }
}
