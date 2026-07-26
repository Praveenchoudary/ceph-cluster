############################################
# 1. Trust Policy (assume role policy) - WHO can assume this role
#    Built using aws_iam_policy_document instead of raw JSON strings
############################################
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

############################################
# 2. IAM Role - the identity that EC2 instances will use
############################################
resource "aws_iam_role" "ec2_s3_role" {
  name               = "ec2-s3-read-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    ManagedBy = "terraform"
  }
}

############################################
# 3. Permissions Policy - WHAT the role is allowed to do
#    Built using aws_iam_policy_document instead of raw JSON strings
############################################
data "aws_iam_policy_document" "s3_read_only" {
  statement {
    sid    = "AllowListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::my-example-bucket"
    ]
  }

  statement {
    sid    = "AllowReadObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::my-example-bucket/*"
    ]
  }
}

resource "aws_iam_policy" "s3_read_only" {
  name        = "s3-read-only-policy"
  description = "Allows read-only access to a specific S3 bucket"
  policy      = data.aws_iam_policy_document.s3_read_only.json
}

############################################
# 4. Attach the policy to the role
############################################
resource "aws_iam_role_policy_attachment" "attach_s3_read" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

############################################
# 5. Instance Profile - how an IAM Role gets attached to an EC2 instance
############################################
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-read-profile"
  role = aws_iam_role.ec2_s3_role.name
}
