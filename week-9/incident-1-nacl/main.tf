# Incident 1: stateless NACL blocking return traffic
# Append this block to core-vpc/main.tf (it attaches to the public subnet)

# BEFORE (broken): outbound HTTPS allowed, no inbound rule, so replies are dropped
# AFTER (fixed): uncomment the ingress block below, then terraform apply
resource "aws_network_acl" "demo" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public.id]

  # Outbound: HTTPS requests may leave
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Inbound: ephemeral port range for replies. NACLs are stateless, so this
  # must be written explicitly. This is the fix.
  # ingress {
  #   rule_no    = 100
  #   protocol   = "tcp"
  #   action     = "allow"
  #   cidr_block = "0.0.0.0/0"
  #   from_port  = 1024
  #   to_port    = 65535
  # }

  tags = { Name = "week9-nacl-demo" }
}
