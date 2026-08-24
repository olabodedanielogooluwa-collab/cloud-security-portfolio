provider "aws" {
  region = "us-east-1"
}

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 203.0.113.4/32. Get it with: curl ifconfig.me"
  type        = string
}

resource "aws_security_group" "web_sg" {
  name        = "week7-web-sg"
  description = "Allow SSH from my IP and HTTP from anywhere"

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "week7-web-sg"
  }
}

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "week7_key" {
  key_name   = "week7-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.ec2_key.private_key_pem
  filename        = "${path.module}/week7-key.pem"
  file_permission = "0400"
}

resource "aws_instance" "week7_ec2" {
  ami                    = "ami-0c101f26f147fa7fd"
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.week7_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = {
    Name = "week7-portfolio-instance"
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "aws_s3_bucket" "week7_bucket" {
  bucket = "week7-portfolio-olabodedaniel"

  tags = {
    Name = "week7-portfolio-bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "week7_bucket_ownership" {
  bucket = aws_s3_bucket.week7_bucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_object" "test_file" {
  bucket       = aws_s3_bucket.week7_bucket.id
  key          = "test-file.txt"
  content      = "Week 7 S3 test upload - deployed via Terraform"
  content_type = "text/plain"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_policy" "week7_bucket_policy" {
  bucket = aws_s3_bucket.week7_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowOwnerAccountOnly"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.week7_bucket.arn,
          "${aws_s3_bucket.week7_bucket.arn}/*"
        ]
      }
    ]
  })
}
