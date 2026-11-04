"""Audit Security Groups for inbound rules open to the internet."""
import sys
import boto3

SENSITIVE = {22: "SSH", 3389: "RDP", 3306: "MySQL", 5432: "PostgreSQL",
             1433: "MSSQL", 6379: "Redis", 27017: "MongoDB"}
EXPECTED_PUBLIC = {80, 443}
OPEN = {"0.0.0.0/0", "::/0"}


def open_sources(rule):
    cidrs = [r["CidrIp"] for r in rule.get("IpRanges", [])]
    cidrs += [r["CidrIpv6"] for r in rule.get("Ipv6Ranges", [])]
    return [c for c in cidrs if c in OPEN]


def classify(rule):
    """Return (severity, description), or None if the rule is acceptable."""
    if rule["IpProtocol"] == "-1":
        return "CRITICAL", "all traffic"
    low, high = rule.get("FromPort", -1), rule.get("ToPort", -1)
    if low == high and low in EXPECTED_PUBLIC:
        return None
    hits = [name for port, name in SENSITIVE.items() if low <= port <= high]
    if hits:
        return "HIGH", f"{', '.join(hits)} (ports {low}-{high})"
    return "MEDIUM", f"ports {low}-{high}"


def audit(region):
    ec2 = boto3.client("ec2", region_name=region)
    findings = []
    for page in ec2.get_paginator("describe_security_groups").paginate():
        for sg in page["SecurityGroups"]:
            for rule in sg["IpPermissions"]:
                sources = open_sources(rule)
                result = classify(rule) if sources else None
                if result:
                    findings.append((result[0], sg["GroupName"], sg["GroupId"],
                                     result[1], ", ".join(sources)))
    return findings


if __name__ == "__main__":
    region = sys.argv[1] if len(sys.argv) > 1 else "us-east-1"
    findings = audit(region)
    order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2}
    for sev, name, gid, desc, src in sorted(findings, key=lambda f: order[f[0]]):
        print(f"[{sev}] {name} ({gid}): {desc} open to {src}")
    print(f"\n{len(findings)} finding(s) in {region}")
    sys.exit(1 if any(f[0] in ("CRITICAL", "HIGH") for f in findings) else 0)
