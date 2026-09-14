resource "aws_iam_group" "developers" {
  name = "developers"
}

resource "aws_iam_group" "readonly" {
  name = "readonly"
}

resource "aws_iam_group_policy_attachment" "readonly_attach" {
  group      = aws_iam_group.readonly.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_policy" "developer_policy" {
  name        = "developer-limited-policy"
  description = "Least-privilege policy for developer group: EC2 + S3 limited access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.week8_test_bucket.arn,
          "${aws_s3_bucket.week8_test_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "developers_attach" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_policy.arn
}

resource "aws_iam_user" "dev_user" {
  name = "dev-test-user"
}

resource "aws_iam_user" "readonly_user" {
  name = "readonly-test-user"
}

resource "aws_iam_user_group_membership" "dev_membership" {
  user   = aws_iam_user.dev_user.name
  groups = [aws_iam_group.developers.name]
}

resource "aws_iam_user_group_membership" "readonly_membership" {
  user   = aws_iam_user.readonly_user.name
  groups = [aws_iam_group.readonly.name]
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "week8_test_bucket" {
  bucket = "week8-iam-drill-${data.aws_caller_identity.current.account_id}"
}

resource "aws_iam_policy" "enforce_mfa" {
  name        = "enforce-mfa-policy"
  description = "Denies all actions except a small allow-list unless the request is MFA-authenticated"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowViewAccountInfo"
        Effect = "Allow"
        Action = [
          "iam:GetAccountPasswordPolicy",
          "iam:ListVirtualMFADevices"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowManageOwnMFA"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:DeleteVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:ListMFADevices"
        ]
        Resource = "arn:aws:iam::*:mfa/&{aws:username}"
      },
      {
        Sid    = "AllowManageOwnUser"
        Effect = "Allow"
        Action = [
          "iam:GetUser",
          "iam:ChangePassword"
        ]
        Resource = "arn:aws:iam::*:user/&{aws:username}"
      },
      {
        Sid       = "DenyAllExceptListedUnlessMFAed"
        Effect    = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "developers_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

resource "aws_iam_group_policy_attachment" "readonly_mfa" {
  group      = aws_iam_group.readonly.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "week8-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  # Lab-only setting: allows Terraform to destroy this bucket even if it
  # contains log objects. In production, log buckets should be protected
  # from deletion, not force-destroyable.
  force_destroy = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "week8_trail" {
  name                          = "week8-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs_policy]
}


