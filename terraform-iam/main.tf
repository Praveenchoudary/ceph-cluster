# EC2 instance using the IAM role via an instance profile.
# Any AWS SDK/CLI call made FROM this instance will automatically
# use these permissions - no access keys needed on the instance itself.
resource "aws_instance" "app_server" {
  ami                  = "ami-0f5ee92e2d63afc18" # verify current AMI for your region
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "iam-demo-app-server"
  }
}

############################################
# Bonus: An IAM User with a scoped-down policy (for a human, not EC2)
############################################
resource "aws_iam_user" "developer" {
  name = "demo-developer"

  tags = {
    ManagedBy = "terraform"
  }
}

data "aws_iam_policy_document" "developer_permissions" {
  statement {
    sid    = "AllowEC2ReadOnly"
    effect = "Allow"

    actions = [
      "ec2:Describe*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "developer_permissions" {
  name   = "developer-ec2-readonly"
  policy = data.aws_iam_policy_document.developer_permissions.json
}

resource "aws_iam_user_policy_attachment" "developer_attach" {
  user       = aws_iam_user.developer.name
  policy_arn = aws_iam_policy.developer_permissions.arn
}
