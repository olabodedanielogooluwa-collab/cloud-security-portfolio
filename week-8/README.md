# Week 8 — IAM + Access Control + First Outreach

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
| MFA on root and all users | ⏳ In progress |
| CloudTrail enabled, logs reviewed | ⏳ Not started |
| Over-permissioned user drill | ⏳ Not started |
| 10 outreach messages | ⏳ Not started |
| Incident queue (3) | ⏳ Not started |

---

*Week 08 of 12 — Cloud Security Self-Study Program*
*Repository: cloud-security-portfolio*
