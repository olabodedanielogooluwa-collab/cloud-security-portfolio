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


---

## Step 2: Network ACLs + Incident 2 (NACL blocks legit traffic)

**Goal:** Understand the stateless NACL by building one, breaking its return path, tracing the failure and fixing it.

**Concept:**
- A NACL is a stateless firewall on the subnet boundary, evaluated before any Security Group.
- Stateless: the request and the reply are judged separately, so each needs its own rule.
- Rules run lowest number first, and the first match wins. The final `*` rule denies everything.
- Direction is measured from the subnet: inbound crosses into it, outbound crosses out.
- A visitor's request uses a fixed port (443). The reply goes back to the visitor's random high port (1024-65535).

**What I built:**
- Test subnet `172.31.96.0/24` in the default VPC (checked for overlap with the existing /20 subnets first)
- Custom NACL `wk10-nacl` attached to it
  - Inbound: 100 allow 443, 110 allow 22 from my /32, 120 allow 1024-65535
  - Outbound: 100 allow 443, 110 allow 80, 120 allow 1024-65535 (the reply rule)
- A `break_reply` variable that removes outbound rule 120, so the failure can be switched on and off
- A temporary t3.micro in the subnet as the test target (destroyed after each test to avoid cost)

**Incident 2 drill:**
1. **Baseline:** Reachability Analyzer, internet gateway to instance on TCP 443. Result: reachable.
2. **Break:** applied with `break_reply=true`, which removed outbound rule 120. Confirmed with the CLI that rule 120 was gone.
3. **First re-test (wrong):** the same forward path still said reachable.
4. **Trace:** the analyzer output flagged `UNIDIRECTIONAL_PATH_ANALYSIS_ONLY`. It checks one direction per analysis, and the forward path only touches inbound rules. The removed rule was outbound.
5. **Correct test:** a reverse path, instance to internet gateway on port 51234, which stands in for the visitor's random high port. Result: not reachable, with the explanation `SUBNET_ACL_RESTRICTION` (the NACL does not allow outbound traffic from the subnet).
6. **Fix:** re-applied without `break_reply`, restoring rule 120. Re-ran the same reverse path. Result: reachable, with the path details naming outbound rule 120 as the allow.

**SG vs NACL (what this proved):**
- A Security Group would have allowed the reply automatically because it tracks connections.
- The NACL has no memory, so the missing outbound rule silently dropped the replies. The client would see a hang, not an error.

**What went wrong:**
- My first re-test used only the forward path, so it passed while the subnet was actually broken. A "reachable" result on one direction says nothing about the other.
- I destroyed the test instance before running the break test, so I had to recreate it and build new paths, because the old ones pointed at a deleted instance.
- Lesson: test both directions for any stateless control, and keep the target alive until the whole drill is finished.

**Not tested:** rule-order conflicts (for example a deny placed after a broader allow). To be covered in the attack simulation.

**Findings (carried into the threat model):**
- Inbound 1024-65535 from anywhere is wide. It is the price of statelessness, and the Security Group is what stops those ports from reaching the instance.
- The NACL only protects the test subnet. The default VPC's other subnets still use the default NACL, which allows everything.
- Outbound is still wide open at the Security Group layer.

**Code:** [`nacl/`](nacl/)


---

## Step 3: boto3 Security Group audit + Incident 1 (SSH exposed to the internet)

**Goal:** Automate detection of Security Group rules open to the internet, then use it to catch and fix a deliberate exposure.

**Concept:**
- boto3 is the AWS SDK for Python. It calls the same API as the CLI but returns structured data that can be looped over and tested.
- The audit asks one question of every Security Group: does any inbound rule allow `0.0.0.0/0` or `::/0`?

**What I built (`sg_audit.py`):**
- Pages through every Security Group in the region
- Flags inbound rules open to the internet and grades them
  - CRITICAL: all traffic
  - HIGH: a sensitive port in range (SSH, RDP, MySQL, PostgreSQL, MSSQL, Redis, MongoDB)
  - MEDIUM: any other open port range
- Treats 80 and 443 as expected public ports
- Exits non-zero on CRITICAL or HIGH findings, so it can later run in a pipeline

**Incident 1 drill:**
1. **Baseline:** audit on the account returned 0 findings.
2. **Break:** created a throwaway SG and opened port 22 to `0.0.0.0/0`.
3. **Detect:** the audit reported `[HIGH] ... SSH (ports 22-22) open to 0.0.0.0/0`.
4. **Fix:** revoked the open rule first, then added port 22 from a single `/32`. Removing before adding keeps the exposure window short.
5. **Verify:** re-ran the audit and got 0 findings.
6. **Clean up:** deleted the throwaway SG.

**Risk documented:**
- SSH open to the internet is scanned and brute-forced constantly by automated tools.
- One weak credential or unpatched SSH flaw becomes full control of the instance.
- The fix is a single-IP source, or better, no public SSH at all.

**What went wrong:**
- A pasted heredoc came out garbled in the terminal. I verified the file with `py_compile`, a line count and `tail` before trusting it, and it was intact.
- The `$SG` shell variable was empty in a new session, so I reset it before running the revoke command. Variables do not survive between sessions.

**Limits of the script (carried into the threat model):**
- Checks inbound rules only, so wide-open egress is not flagged
- Does not follow Security Group references, so a chain of SG-to-SG trust is invisible to it
- Scans one region per run
- Matches a fixed list of sensitive ports; an unusual port is graded MEDIUM

**Code:** [`boto3/`](boto3/)
