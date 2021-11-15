
########################
# Spinnaker IAM
########################

# Allows to allow them to assume the roles provisioned for specific Spinnaker pods/services.
# Req: The IAM Role ARN of the EKS workers that Spinnaker runs in
data "aws_iam_policy_document" "worker_iam_role_assume_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "AWS"

      identifiers = [var.eks_worker_role_arn]
    }
  }
}

# Create IAM poliocy that spinnaker will use.
# TO-DO: Go through and verify all of these statements are needed for Control Plane
# This was copied from the original individual spinnaker IAM roles.
data "aws_iam_policy_document" "spinnaker" {
  statement {
    sid    = "ParameterStoreAccess"
    effect = "Allow"

    actions = [
      "ssm:DescribeParameters",
      "ssm:GetParameters",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "EksAllAccess"
    effect = "Allow"

    actions = [
      "eks:*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "SpinnakerBucketAccess"
    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.spinnaker_bucket.arn,
      "${aws_s3_bucket.spinnaker_bucket.arn}/*",
    ]
  }

  statement {
    sid    = "DecryptSecrets"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
    ]

    resources = [
      var.kms_parameter_store_key_arn,
    ]
  }
}

# Provision the spinnaker role allowing the worker-iam-role to assume it
resource "aws_iam_role" "spinnaker-role" {
  name                  = local.name
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.worker_iam_role_assume_policy.json
  permissions_boundary  = local.permissions_boundary
  tags                  = module.adsk_tags.tags
}

# Creates the spinnaker iam policy as defined in the data source document above
resource "aws_iam_policy" "spinnaker-policy" {
  name   = "${local.name}-spinnaker-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.spinnaker.json
}

# Attach the spinnaker policy above to the spinnaker iam role
resource "aws_iam_role_policy_attachment" "spinnaker-policy-attachment" {
  role       = aws_iam_role.spinnaker-role.name
  policy_arn = aws_iam_policy.spinnaker-policy.arn
}
