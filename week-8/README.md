# Week 8 — IAM + Access Control 

**Status:** In progress
**Environment:** AWS (Google Cloud Shell), Terraform
**Focus:** Identity and Access Management — least privilege by design, not by afterthought

---

## Threat Context

IAM misconfiguration is one of the most common root causes of cloud breaches —
not exploited software, but overly broad permissions granted by default and
never revisited. Every task this week is built around one question:
**does this identity have exactly what it needs, and nothing more?**

---

## 1. IAM Users, Groups, Roles (Terraform)

**Objective:** Establish a group-based access model instead of attaching
permissions directly to individual users — a standard control for
auditability and scalable least privilege.

**What I Did:**

1. Created two IAM groups representing distinct access tiers:
   - `developers` — operational access, scoped to specific services
   - `readonly` — view-only access, no write/modify capability
2. Created two test IAM users, each mapped to exactly one group:
   - `dev-test-user` → `developers`
   - `readonly-test-user` → `readonly`
3. Attached AWS-managed `ReadOnlyAccess` to the `readonly` group
4. Authored a custom policy, `developer-limited-policy`, scoping the
   `developers` group to only the actions required for this drill:
   - `ec2:Describe*`, `ec2:StartInstances`, `ec2:StopInstances`
   - `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`
5. Applied via Terraform — 9 resources created, 0 errors

**Security Rationale:**

- Group-based assignment means permission changes happen in one place
  (the group policy), not per-user — reducing configuration drift
- No user was granted `AdministratorAccess` or any AWS-managed broad policy
  outside of the intentionally read-only group
- Every permission granted to `developers` maps to a specific task in this
  week's plan — nothing was added "just in case"

---

## 2. Least Privilege: Scoping the Developer Policy

**Scenario:** The developer policy's initial S3 permissions used
`Resource = "*"` — access to every bucket in the AWS account, including
buckets unrelated to this project and any created in the future. This was
identified and corrected as part of the least-privilege drill.

**What I Did:**

1. Created a single-purpose test bucket for this exercise
2. Rewrote the policy's S3 `Resource` field from a wildcard to two explicit
   ARNs — the bucket itself and its contained objects
3. Ran `terraform plan` and confirmed the change was an **in-place update**
   (`0 to add, 1 to change, 0 to destroy`) — verifying the fix did not
   disrupt existing group or user attachments
4. Ran `terraform apply` — change applied successfully

**Before → After:**

```hcl
# Before — grants access to every bucket in the account
Resource = "*"
```

```hcl
# After — scoped to one bucket and its objects only
Resource = [
  aws_s3_bucket.week8_test_bucket.arn,
  "${aws_s3_bucket.week8_test_bucket.arn}/*"
]
```

*(Actual bucket name and AWS account ID redacted from this writeup —
account identifiers are treated as sensitive and are not published
publicly, even in a lab/training context.)*

**Security Observations:**

- A wildcard `Resource = "*"` on an S3 statement grants access to every
  **current and future** bucket in the account — a violation of least
  privilege regardless of whether it has been exploited
- `s3:ListBucket` operates on the bucket itself and requires the bucket
  ARN with no suffix; `s3:GetObject`/`s3:PutObject` operate on objects
  *inside* the bucket and require the `/*` suffix. Confusing these two is
  a frequent, easily-overlooked cause of `AccessDenied` errors and, in the
  opposite direction, of accidental over-permissioning
- Reading the Terraform plan diff type (`~` in-place update vs. a
  destroy/recreate) is itself a security check during a permissions
  review — it confirms a policy tightening doesn't silently break or
  detach unrelated resources

---

## 3. MFA: Root Status + Enforcement Policy for IAM Users
 
**Root Account:** MFA was already configured on the root account via
authenticator app during initial account setup (prior week). Confirmed
active — no further action needed here.
 
**IAM Users — Enforcement, Not Just Recommendation:**
 
Rather than relying on users to voluntarily enable MFA, I wrote a policy
that structurally denies access without it.
 
**What I Did:**
 
1. Authored `enforce-mfa-policy` — a policy using a `Deny` statement with
   `NotAction` and a `BoolIfExists` condition on `aws:MultiFactorAuthPresent`
2. The policy denies all actions **except** a small allow-list needed for a
   user to self-service set up their own MFA device (otherwise a user
   without MFA would be locked out entirely, with no path to fix it)
3. Attached the policy to both the `developers` and `readonly` groups
4. Ran `terraform plan` — confirmed `3 to add, 0 to change, 0 to destroy`
   (new policy + two group attachments; no disruption to existing resources)
5. Applied — 3 resources created successfully
**Security Rationale:**
 
- A policy is a stronger control than a written procedure or reminder —
  it removes the option to skip MFA rather than just discouraging it
- The `NotAction` allow-list is deliberately narrow: only what's needed to
  view account info and enroll an MFA device — nothing else is exempted
- `BoolIfExists` matters here: without it, the condition would fail (and
  therefore not deny) for any session where the MFA key is entirely absent
  from the request context, which would defeat the policy's purpose
- **Known effect:** `dev-test-user` and `readonly-test-user` are now denied
  nearly all actions until MFA is enrolled on their credentials. This is
  intentional — it demonstrates the policy is actually enforcing, not just
  present in the account
---

 ## 4. CloudTrail: Visibility Into Every API Call
 
**Why this matters (security first):** IAM policies define what *should*
be possible. CloudTrail is what tells you what *actually happened* —
every API call in the account, successful or denied, is recorded with who
made it, from where, and when. Without it, a compromised credential or a
misused root account leaves no trail to investigate. This is the control
that turns "we think nothing happened" into "we can prove what happened."
 
**What I Did:**
 
1. Created a dedicated S3 bucket to hold CloudTrail logs, separate from
   any test/working buckets — log data is treated as sensitive and is not
   mixed with lab material
2. Attached a bucket policy granting only the CloudTrail service
   principal (`cloudtrail.amazonaws.com`) permission to check the bucket
   ACL and write log objects — no IAM user or role has direct write access
3. Created a trail (`week8-trail`) with:
   - `is_multi_region_trail = true` — captures activity across every AWS
     region, not just the one I'm working in
   - `enable_log_file_validation = true` — enables cryptographic hash
     validation, so log files can be verified as untampered if they're
     ever needed as evidence
4. Applied via Terraform — 3 resources created (bucket, bucket policy, trail)
5. Generated a test event (`aws iam list-users`), waited for delivery,
   then pulled and read a log file directly from S3 to confirm the trail
   was actually capturing activity — not just reporting healthy in the console
   
**Reading a Real Log Entry:**
 
Every CloudTrail event follows the same shape, answering five questions:
 
| Question | Field | Example from this trail |
|---|---|---|
| Who | `userIdentity.userName` / `.type` | `terraform-cli` (IAMUser) |
| What | `eventName` | `ListUsers` |
| When | `eventTime` | `2026-09-06T15:44:24Z` (UTC) |
| Where from | `sourceIPAddress` | Cloud Shell's egress IP |
| Was it a change | `readOnly` | `true` — a read, not a modification |
 
The same log file also contained two `GetBucketAcl` events where
`userIdentity.type` was `AWSService` and `invokedBy` was
`cloudtrail.amazonaws.com` — CloudTrail checking its own bucket
permissions, not human activity. Distinguishing AWS-internal service
events from user-driven events is a necessary first filter before
investigating any real incident; otherwise background service noise gets
mistaken for suspicious activity.
 
**Security Observations:**
 
- Only the CloudTrail service principal can write to the log bucket — no
  IAM user, including root, has a policy granting direct write access to
  it, which reduces the risk of logs being altered or deleted post-compromise
- Multi-region logging closes a common blind spot: activity in an
  unmonitored region is invisible without it, and that's exactly where an
  attacker (or an accidental action) would be least likely to be noticed
- Terraform authenticates through a dedicated IAM user (`terraform-cli`),
  not a personal identity — separating "infrastructure automation"
  from "human user" is good practice, and CloudTrail confirms that
  separation is actually happening in practice, not just on paper
- `force_destroy = true` on the log bucket is a **lab-only setting** to
  allow teardown during this exercise. In a production environment, a
  CloudTrail log bucket would be protected from deletion (e.g. via a
  bucket policy deny statement or Object Lock) — flagged here so this
  isn't mistaken for a production-ready default
---
 
## 5. Drill: Over-Permissioned User → Audit → Reduce → Verify
 
**Why this matters (security first):** Over-permissioning is rarely
intentional — it accumulates from copy-pasted policies, "just to test
something" grants that never get revoked, or broad defaults nobody
revisited. This drill simulates finding that kind of excess and fixing it
the way a real audit would: confirm what exists, remove exactly the
excess, then verify.
 
**What I Did:**
 
1. Deliberately attached an inline policy (`temp-overpermissioned-policy`)
   granting `Action = "*", Resource = "*"` — full administrative access —
   directly to `readonly-test-user`, a user meant to be view-only
   
2. **Audited before touching anything:**
```
   aws iam list-user-policies --user-name readonly-test-user
   aws iam get-user-policy --user-name readonly-test-user \
     --policy-name temp-overpermissioned-policy
```
   Confirmed the exact excess grant rather than assuming what was there
   
3. **Reduced to minimum:** removed the inline policy resource from
   Terraform entirely — `readonly-test-user` did not need a replacement
   policy, since its group membership (`ReadOnlyAccess` via the `readonly`
   group) already provides everything the role requires
   
4. Ran `terraform plan` / `apply` — confirmed exactly
   <img width="1080" height="138" alt="Annotation 2026-09-10 005334" src="https://github.com/user-attachments/assets/4dae54f3-9bfc-4158-90ee-f06900edb822" />
 
 
**Security Observations:**
 
- Inline user policies (attached directly to one user) are a common way
  over-permissioning slips in unnoticed — they don't show up when
  reviewing group policies, so an audit that only checks groups would
  have missed this entirely
- The fix required *removing* a policy, not writing a smaller one —
  the correct level of access already existed at the group level. This
  is a useful pattern to recognize: excess access is sometimes solved by
  deletion, not rewriting
- Verifying the Terraform plan showed only `1 to destroy` (not a
  destroy/recreate of unrelated resources) confirmed the fix was surgical
  — it didn't disturb the user's legitimate group-based access
---
 
## Incident Response Log
 
Simulated incidents, investigated the way a real ticket would be worked —
trace first, fix second, document the reasoning either way.
 
### Incident 1 — IAM User AccessDenied on S3
 
**Reported symptom:** `dev-test-user` receives `AccessDenied` attempting
`s3:GetObject`.
 
**Investigation:**
 
Rather than guessing, I used the IAM Policy Simulator to test the actual
permission evaluation for this user, against two targets — a bucket
outside the user's intended scope, and the bucket the user's policy
*should* allow:
 
```
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account-id>:user/dev-test-user \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::<cloudtrail-log-bucket>/somefile.json
 
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::<account-id>:user/dev-test-user \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::<iam-drill-bucket>/somefile.json
```
 
**Finding:** Both simulations returned `explicitDeny` — but not from the
S3 policy. Both were blocked by `enforce-mfa-policy` (the MFA-enforcement
policy from Section 3). The simulator has no way to represent an
MFA-authenticated session in a hypothetical request, so
`aws:MultiFactorAuthPresent` is absent from the evaluation context.
Because the policy uses `BoolIfExists`, an absent value is treated as
`false`, and the deny-unless-MFA statement fires before the S3-specific
allow/deny logic is ever reached.
 
**Root cause:** Not a gap in the S3 policy at all — the denial originates
entirely from the MFA enforcement layer. A user without an
MFA-authenticated session is denied nearly every action, including ones
their underlying S3 policy would otherwise permit.
 
**Resolution:** No policy change required. The MFA enforcement policy is
working as designed — the correct fix is for `dev-test-user` to
authenticate with MFA, not to loosen any policy. Confirmed no unintended
S3 permission gap exists once MFA is factored in.
 
**Security Observation:**
 
- This is a real troubleshooting trap worth documenting on its own: an
  `AccessDenied` error can originate from a completely different policy
  than the one that looks most relevant to the failing action. Tracing
  the actual `MatchedStatements` in the simulator output — rather than
  assuming the S3 policy was at fault — was the only way to find the true
  cause
- This also validates the MFA policy is actually restrictive in practice,
  not just present on paper — it's intercepting requests exactly as
  designed, even ones that would otherwise be legitimate
---
 
### Incident 2 — Root Account Used for an Action
 
**Reported symptom:** Root account activity needs to be identified and
evaluated — root should be reserved for a small set of tasks that
cannot be performed by any other identity, and any root usage outside
that list is worth investigating.
 
**Investigation:**
 
```
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=root \
  --max-results 10
```
 
**Finding:** CloudTrail's Event history returned a real root-account
event: `DescribeEventAggregates` against `health.amazonaws.com` (a
read-only call to AWS's own service-health dashboard).
 
Two details in the event's `userIdentity` block were essential to
evaluating this correctly rather than treating it as a raw alarm:
 
- `mfaAuthenticated: true` — the root session was MFA-protected
- `sessionCredentialFromConsole: true` — this came from an interactive
  browser login, not a raw access key
  
**Root cause:** Root was used to check the AWS Health Dashboard —
almost certainly a manual console check, not automation and not a
misconfigured script defaulting to root.

 
**Resolution:** No remediation needed for this specific event — it was
MFA-protected and read-only. However, this is documented as a finding
rather than dismissed, because of the underlying principle it tests:
 
**Security Observation:**
 
- Root should be used only for the small set of actions that genuinely
  require it (e.g. closing the account, certain billing/support-plan
  changes) — routine checks like a health dashboard should be done from
  an IAM user or role instead, even when read-only and MFA-protected
- The reason this matters even for a *safe* root action: root cannot be
  restricted by IAM policy. Every guardrail built in this project this
  week — least privilege, MFA enforcement — applies to IAM users and
  roles, not to root. A habit of using root for convenience, even for
  harmless actions, is what leaves an account exposed the one time it
  matters
- This is why CloudTrail's ability to answer "was root used, and under
  what conditions" is a control in its own right, separate from whether
  a specific root action turns out to be benign — the MFA and
  console-login context in this event is what allowed a fast, confident
  "not a compromise" conclusion instead of an open question
---
 
### Incident 3 — Over-Permissioned Role Deployed
 
**Reported symptom:** A policy grant is discovered that exceeds what the
attached identity should have — the kind of finding that surfaces during
a routine access review, not from a specific failure.
 
**Investigation:**
 
This incident reuses the audit performed in Section 5, framed here as an
incident response rather than a planned drill. The deployed grant was
an inline policy (`temp-overpermissioned-policy`) attached directly to
`readonly-test-user`, granting `Action = "*", Resource = "*"` —
unrestricted access, on an identity intended to be view-only.
 
Before making any change, the existing grant was confirmed directly
rather than assumed:
 
```
aws iam list-user-policies --user-name readonly-test-user
aws iam get-user-policy --user-name readonly-test-user \
  --policy-name temp-overpermissioned-policy
```
 
**Root cause:** An inline policy attached at the individual-user level,
bypassing the group-based access model entirely. Because inline policies
don't appear when reviewing group policies, this kind of grant is easy
to miss unless users are audited individually, not just by group
membership.
 
**Resolution — audit, reduce, verify:**
 
1. **Audit:** confirmed via the commands above that the grant was
   exactly `Action = "*", Resource = "*"` — full administrative access
2. **Reduce:** removed the inline policy resource from Terraform
   entirely. No replacement policy was needed — `readonly-test-user`'s
   group membership (`ReadOnlyAccess` via the `readonly` group) already
   provides everything the role legitimately requires
3. **Verify nothing breaks:** ran `terraform plan`, confirming exactly
   `1 to destroy, 0 added, 0 changed` — proof the fix removed only the
   excess grant and didn't disturb the user's legitimate group-based
   permissions
4. Applied the fix — destruction confirmed
**Security Observation:**
 
- The fix here was deletion, not rewriting a smaller policy — the
  correct access level already existed at the group level, and the
  inline policy was pure excess rather than a partially-correct grant
  that needed narrowing
- This incident is a reminder that access reviews need to check
  individual users directly, not only the groups they belong to —
  group-based access models reduce risk but don't eliminate the
  possibility of an out-of-band grant slipping in underneath them
- Confirming the Terraform plan's diff type before applying (`1 to
  destroy` vs. a broader change) is what turns "I removed the bad
  policy" into "I removed *only* the bad policy" — a distinction that
  matters when documenting incident resolution
---
 
## Credential & Identifier Handling
 
In line with cloud security best practice, the following are intentionally
excluded from this writeup and from version control:
 
- AWS Account ID
- S3 bucket names containing the account ID
- Any access keys, secret keys, or session tokens
- IAM ARNs in full (only the resource *type* and *policy logic* are shown)
Terraform state and `.tfvars` files (if used) are excluded via `.gitignore`
and are never committed to this repository.
 
---
 
## Status Against Week 8 Goals
 
| Task | Status |
|---|---|
| IAM users, groups, roles via Terraform | ✅ Complete |
| Least privilege applied + documented | ✅ Complete (S3 scoping) |
| MFA on root and all users | ✅ Complete |
| CloudTrail enabled, logs reviewed | ✅ Complete |
| Over-permissioned user drill | ✅ Complete |
| Incident queue (3 of 3) | ✅ Complete |
 
---
 
*Week 08 of 12 — Cloud Security Self-Study Program*
*Repository: cloud-security-portfolio*
 

