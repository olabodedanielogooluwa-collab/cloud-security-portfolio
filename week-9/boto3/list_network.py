# Week 9: boto3 network audit
# Read-only: lists VPCs, subnets and NAT Gateways. Changes nothing.
import boto3

# Client: one connection to the EC2 service in one region
ec2 = boto3.client("ec2", region_name="us-east-1")

# List every VPC and its CIDR range (default=True is AWS's own VPC)
print("VPCs")
for vpc in ec2.describe_vpcs()["Vpcs"]:
    print(f"  {vpc['VpcId']}  {vpc['CidrBlock']}  default={vpc['IsDefault']}")

# List every subnet and which VPC it belongs to
print("Subnets")
for s in ec2.describe_subnets()["Subnets"]:
    print(f"  {s['SubnetId']}  {s['CidrBlock']}  {s['AvailabilityZone']}  vpc={s['VpcId']}")

# Cost check: NAT Gateways bill hourly while in the "available" state
print("NAT Gateways")
for n in ec2.describe_nat_gateways()["NatGateways"]:
    print(f"  {n['NatGatewayId']}  state={n['State']}")
