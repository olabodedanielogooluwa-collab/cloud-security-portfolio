# Week 10: Security Groups, NACLs + Threat Modelling

**Status:** In progress. Entries are added as each step is completed.
**Project link:** Foundation for Project 03 (Secure VPC + Threat Model).
**Tools:** Terraform v1.9.8, AWS provider v5.100.0, AWS CLI, Google Cloud Shell

---

## Step 1: Security Groups via Terraform

**Goal:** Build a two-tier Security Group design where only the intended ports are reachable.

**Concept:**
- A Security Group is a stateful, allow-only firewall attached to an instance's network interface.
- Stateful: replies to allowed traffic leave automatically, so no return-path rule is needed.
- No deny rules: anything not explicitly allowed is dropped.
- A rule's source can be an IP range (CIDR) or another Security Group.

**What I built (7 resources):**
- `wk10-web-sg`
  - Inbound 443 from `0.0.0.0/0` (the only public port)
  - Inbound 22 from a single `/32` (my IP only)
  - Outbound: all traffic
- `wk10-app-sg`
  - Inbound 8080 from `wk10-web-sg` only (Security Group reference, no CIDR)
  - Outbound: all traffic

**Design decisions:**
- SSH is restricted to a single IP because it is the highest-risk port: anyone who reaches it can attempt to take control of the server.
- The app tier trusts the web tier's Security Group instead of an IP range, so the rule survives IP changes and exposes nothing to the internet.
- The IP value is passed in as a variable with no default, which forces me to supply it on every run.
- Outbound rules are declared explicitly because Terraform removes the default allow-all egress rule.
- Every rule had to pass three questions: who needs access, on which port only, and is it needed now.

**Commands:**
```
terraform init
terraform plan -var="my_ip=$(curl -s ifconfig.me)" -out=wk10.plan
terraform apply wk10.plan
```

**Verification:**
```
aws ec2 describe-security-groups --filters Name=group-name,Values=wk10-*-sg \
  --query "SecurityGroups[].IpPermissions[].[FromPort,IpRanges[].CidrIp]" --output text
```
- Port 22: `x.x.x.x/32` (my IP, masked)
- Port 443: `0.0.0.0/0`
- Port 8080: no CIDR listed, because access comes from the web Security Group reference
- No other ports open

**What went wrong:**
- **Issue:** `terraform apply` failed with `InvalidVpcId.Malformed`.
- **Cause:** I ran the placeholder `vpc_id=vpc-XXXX` from the example instead of my real VPC ID. AWS rejected it before creating anything, so there was nothing to clean up.
- **Fix:** Looked up the real ID with `aws ec2 describe-vpcs` and moved it into `terraform.tfvars`.
- **Second issue:** I pasted `init`, `plan` and `apply` as one block, so apply ran with no review step.
- **Habit adopted:** `plan -out=wk10.plan`, read the plan, then `apply wk10.plan`, so apply runs exactly what I reviewed.
- **Dealt with before pushing:** `terraform.tfvars`, plan files and state are excluded via `.gitignore`.

**Findings (carried into the threat model):**
- Outbound is allow-all on both tiers. A compromised instance could call out to anywhere.
- The VPC is the account's default VPC, whose subnets are public by default. This widens the attack surface and will be addressed in the threat model.
- The SSH `/32` breaks whenever my Cloud Shell IP rotates and must be refreshed before each use.

**Code:** [`sg/`](sg/)
