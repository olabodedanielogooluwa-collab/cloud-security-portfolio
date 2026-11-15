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


---

## Step 4: Attack simulation (testing my own firewall rules)

**Goal:** Probe my own infrastructure from outside, compare real results to predictions, and test whether NACL rule order behaves as expected.

**Scope and constraints:**
- Target: only my own temporary test instance
- Ports: 22, 80, 443, 8080, 3306; one connection attempt each, 3-second timeout, no flooding
- Source: Cloud Shell, whose IP is not the one allowed by my SSH rules
- Instance destroyed after the test

**What I built (`port_probe.py`):** a small TCP probe that classifies each port.
- Open: connected, so a service is listening
- Refused: the packet passed every firewall, but nothing is listening
- Filtered: the connection timed out, so a firewall dropped it silently
- Ports can be passed on the command line, otherwise it uses the five defaults

**Test 1: baseline (predicted before running)**

| Port | Result | Reason |
|---|---|---|
| 22 | filtered | NACL and SG allow SSH only from one /32, and Cloud Shell is a different IP |
| 80 | filtered | no rule in either layer |
| 443 | refused | both layers allow it, but nothing listens |
| 8080 | filtered | NACL allows 1024-65535, but the SG has no rule, so the SG drops it |
| 3306 | filtered | same as 8080 |

All five predictions matched.

**Key lesson:** an answer, even a refusal, means the firewalls let the packet through. Silence means a firewall dropped it. This also showed the NACL's wide ephemeral range is not what protects 8080 and 3306; the Security Group is.

**Test 2: NACL rule order**
- Added inbound rule 90 (deny TCP 443) ahead of rule 100 (allow TCP 443).
- Re-ran the probe: 443 changed from refused to filtered.
- Why: a NACL evaluates from the lowest rule number upward and stops at the first match. The deny at 90 fires before the allow at 100 is ever reached, so the packet is dropped before it reaches the instance.
- The allow rule still exists but is irrelevant. Rule order, not rule presence, decides the outcome.
- Removed rule 90 afterwards and confirmed rules 100, 110, 120 remained.

**What went wrong:**
- My first explanation of the 443 change was wrong. I reasoned from "allowed and listening" instead of rule order, and I described the evaluation direction incorrectly. Corrected: lowest number first, first match wins.
- My first attempt at making ports a command-line argument did not save. The test run showed all five default ports instead of two, which exposed it. I fixed it and re-verified.

**Findings (carried into the threat model):**
- Amazon Linux runs an SSH server by default, so the Security Group is the only thing keeping port 22 closed to the internet.
- The NACL is permissive on high ports, so a mistake in the Security Group has no second layer behind it.
- Rule order in a NACL is a change-control risk: one misplaced deny or allow silently changes behaviour.
- Port probing shows what is reachable, not what is vulnerable.

**Code:** [`attack-sim/`](attack-sim/)



---


## Step 5: CloudTrail investigation (Incident 3: unknown IP in the logs)

**Goal:** Build a repeatable method to find every source IP in the account's activity, classify each one, and decide whether anything is a threat.

**Triage framework (three questions per source):**
1. Do I recognise the source?
2. Is the action one I did or expected?
3. Is anything failing, or touching identity (failed logins, root use, IAM or key changes)?

An unknown source is only urgent when it combines with the third question.

**What I built:**
- `cloudtrail_ips.py`: groups 24 hours of CloudTrail events by source IP, with event count, error count, users and sample event names
- `cloudtrail_errors.py`: lists failed events (source, event name, error code) for one region

**Investigation:**
- Three sources appeared:
  - `cloudtrail.amazonaws.com` (about 400 events, 0 errors): CloudTrail checking the ACL on its own log bucket. AWS service, normal.
  - A Google-range address (Cloud Shell) acting as my `terraform-cli` user, running a trail status check. Mine.
  - `resource-explorer-2.amazonaws.com` (75 events, 11 errors): AWS Resource Explorer scanning the account. AWS service.
- AWS services show up as service names, not IPs, and cannot be spoofed. A stolen key would show the attacker's real IP.
- All 11 errors were `SubscriptionRequiredException` on read-only `List*` calls, meaning the account is not subscribed to those services (for example GuardDuty). No access-denied, identity, key or login activity.

**Open item: Resource Explorer index in an unused region:**
- Indexes existed in `us-east-1` and `eu-north-1`. I do not use `eu-north-1`.
- CloudTrail's event history returned nothing for who created it. The index's creation date was about 99 days ago, past the 90-day lookup window, so the creator cannot be verified.
- Likely benign: my console sometimes opens in `eu-north-1` before I switch regions, which fits a one-click setup. This is a hypothesis, not proof.
- Action: deleted the `eu-north-1` index (confirmed `DELETED`) and set my console default region to `us-east-1`.

**Verdict:** no unknown IP and no threat. Baseline established.

**What went wrong:**
- I first said an AWS source would be suspicious. Corrected: AWS service principals are normal background activity, and the real signal is an unfamiliar IP combined with failures or identity activity.
- I pasted a placeholder (`<paste-ARN-here>`) into a command instead of the real value, which shell rejected with a syntax error. Fixed by capturing the ARN in a variable. Same class of mistake as the Step 1 VPC ID.
- A script file was never created because its creation command was not run, so the run failed with "No such file". Fixed by creating the file and confirming it with `ls` before running.

**Findings (carried into the threat model):**
- No managed threat detection (GuardDuty) is enabled, so detection depends on manually reading logs.
- CloudTrail event history only covers 90 days, so older activity cannot be investigated without a trail and log bucket.
- A resource in an unused region could not be attributed. Region guardrails are a gap.

**Code:** [`cloudtrail/`](cloudtrail/)
