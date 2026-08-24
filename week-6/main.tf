terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # update to your preferred region
}

resource "aws_instance" "week6_ec2" {
  ami           = "ami-*****************" # example Amazon Linux 2 AMI — verify current AMI ID for your region
  instance_type = "t3.micro"              # t2.micro is NOT Free Tier eligible for accounts created after July 15, 2025

  tags = {
    Name = "week6-terraform-instance"
  }
}
