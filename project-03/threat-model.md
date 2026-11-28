# Threat Model v1: Secure VPC Lab (Week 10)

**Status:** First version from Week 10. To be extended in Week 12 with the full VPC (public and private subnets, NAT, SGs, NACLs).
**Format:** problem → constraint → decision → outcome.

## Scope

- **In scope:** the Week 10 lab: Security Groups (`wk10-web-sg`, `wk10-app-sg`), a test subnet with a custom NACL, a temporary test instance, and account-level CloudTrail.
- **Not in scope:** production data, which does not exist in this environment.
- **Threats considered:** internet scanning, a compromised instance, and my own configuration mistakes.
- **Operating constraints:** solo operator, zero-spend account, learning lab.

## Ranking method

Threats are ranked by **residual risk after the controls I actually tested**. T2 ranks first because no control exists against it, while T1's controls held under probing. Ranked by likelihood × impact instead, T1 would come first.

| Rank | Threat | Findings |
|---|---|---|
| 1 | T2: Uncontrolled outbound traffic | 1 |
| 2 | T1: Exposure through thin layering | 2, 3, 4, 5, 7 |
| 3 | T3: Misconfiguration and drift | 6, 8 |
| 4 | T4: Detection and visibility gaps | 9, 10, 11 |

## Findings and evidence

| # | Finding | Evidence | Status |
|---|---|---|---|
| 1 | Egress allow-all on both SGs | Step 1 code; Reachability Analyzer showed outbound "ALL" | Observed |
| 2 | Default VPC, public-by-default subnets | Step 1; CLI check on the VPC | Observed |
| 3 | NACL inbound 1024-65535 open to all | Step 2 rule listing | Observed |
| 4 | Other subnets use the allow-all default NACL | Step 2; CLI check on NACL associations | Observed |
| 5 | SSH server runs by default; SG is the only SSH control | Step 4; port 22 filtered from an outside IP | Expected, not observed on the instance |
| 6 | NACL rule order can silently change behaviour | Step 4; rule 90 flipped 443 from refused to filtered | Observed |
| 7 | No second layer behind the SG on high ports | Step 4; 8080 and 3306 filtered by the SG alone | Observed |
| 8 | Audit script: inbound only, no SG references, one region | Step 3; read from the code | By design, not tested |
| 9 | No managed threat detection | Step 5; `SubscriptionRequiredException` on a GuardDuty-style API | Consistent with, not confirmed |
| 10 | Event-history lookups cover 90 days | Step 5; index creation date was outside the window | Observed |
| 11 | Unattributable resource in an unused region | Step 5; index in a region I do not use | Observed |
| 12 | Long-running public instance unnoticed for months | Step 7; Week 7 instance found by an inventory check | Observed |

## T2: Uncontrolled outbound traffic

**Findings:** 1

**Problem:** Both Security Groups allow all outbound traffic. On the test subnet the NACL also allows outbound 80, 443 and 1024-65535, so a compromised instance could download tools, call back to a command server or send data out over HTTPS or any high port, and nothing would stop it.

**Constraint:** Tight egress rules need a known list of destinations (updates, package repositories, AWS APIs). The lab has no fixed workload, so a strict rule risks breaking things I cannot predict.

**Decision:** Accept the risk in the lab because it holds no production data. Revisit when a real workload exists, starting with a default-deny egress and explicit allows.

**Outcome:** No egress control exists. Egress only matters after a compromise, so the impact is low today, but it would be high in a real workload. Accepted for the lab, not acceptable for production.

## T1: Exposure through thin layering

**Findings:** 2, 3, 4, 5, 7

**Problem:** The VPC is the default one, with public-by-default subnets, and most subnets use the default NACL, which allows everything. On the test subnet the NACL allows wide high-port ranges, so the Security Group is the only real barrier. Amazon Linux runs an SSH server by default (expected, not observed on this instance). One SG mistake, such as port 22 open to the world in Incident 1, exposes the instance with no second layer behind it.

**Constraint:** Week 10 is a lab on the account's existing VPC. The wide high-port NACL range is needed because a NACL is stateless and replies need a path back.

**Decision:** Keep the default VPC for the lab. Hold exposure down with tight SGs (443 public, SSH from a single /32, app tier reachable only through the web SG) and catch mistakes with the audit script. The Project 03 VPC (public and private subnets, NAT in Week 11, SGs and NACLs with deny-by-default in Week 12) is the structural fix.

**Outcome:** Probes from one outside source found every non-intended port filtered or refused, as predicted. Residual risk is moderate: the audit script detects a bad rule after it is made but does not prevent it.

## T3: Misconfiguration and drift

**Findings:** 6, 8

**Problem:** A single misplaced rule silently changes behaviour. Rule 90 (deny 443) placed ahead of rule 100 (allow 443) turned 443 from refused to filtered with no error. Changes made by hand in the console or CLI can also drift from the Terraform code. The audit script would miss some of this: it checks inbound rules only, cannot follow SG-to-SG references and scans one region per run.

**Constraint:** Continuous configuration monitoring (AWS Config) bills per recorded item, which conflicts with a zero-spend lab. The script is a first version scoped to one task.

**Decision:** Use Terraform as the intended source of truth and re-run the audit after every change. Extend the script (egress, SG references, all regions) in the Week 12 audit toolkit. Not yet tested: whether `terraform plan` flags a rule added by hand.

**Outcome:** Residual risk is moderate. Detection is manual and after the fact, so a bad rule can exist until the next audit.

## T4: Detection and visibility gaps

**Findings:** 9, 10, 11, 12

**Problem:** Detection depends on me looking. No managed threat detection appears to be enabled, event-history lookups only reach back 90 days, and an index in a region I do not use could not be attributed to anyone because its creation was outside that window. A public instance from Week 7 also ran for about 110 days before a manual inventory check found it. Free-tier credits absorbed the charges, so no billing alert fired either.

**Constraint:** Managed detection and configuration recording bill by usage, which conflicts with a zero-spend account. A trail's S3 logs only exist from the day the trail was created. I had no automated asset inventory and no habit of checking for leftovers.

**Decision:** Investigate manually with the CloudTrail scripts, and run a running-resources check (instances, NAT Gateways, Elastic IPs, volumes) at the end of every week. Deleted the unattributed index and set the console default region to us-east-1. Week 12 adds the automated CloudTrail and billing alarm. Enable managed detection only if the budget allows.

**Outcome:** Residual risk is moderate in a lab and high in a real environment. The weekly check limits how long a forgotten resource can sit unnoticed to about a week, but only if I run it. A compromise could still go unnoticed, and an old change could not be traced.


## Open items for Week 12

- Re-model with the full VPC (private subnets, NAT, deny-by-default NACLs) and re-rank the threats.
- Test whether `terraform plan` detects a manual NACL change.
- Extend the audit script and consolidate it into the audit toolkit.
- Decide on managed threat detection against the cost.
- Check whether my zero-spend budget alert should have surfaced the long-running instance, and tune it.
