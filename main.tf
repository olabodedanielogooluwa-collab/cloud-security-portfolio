provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "week6_ec2" {
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t2.micro"

  tags = {
    Name = "week6-portfolio-instance"
  }
}
