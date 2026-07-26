# Terraform IAM - Roles, Policies, and Instance Profiles

This project explains **IAM (Identity and Access Management)** in AWS, and how to manage it with Terraform — using `aws_iam_policy_document` instead of hand-written JSON strings, an EC2 instance role, and a scoped IAM user.

> **Repository structure**
>
> ```text
> terraform-iam/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── iam.tf
> ├── main.tf
> └── outputs.tf
> ```

---

## Core IAM Concepts

| Concept | What it is |
|---|---|
| **IAM User** | An identity for a person (or an app using long-lived credentials) |
| **IAM Role** | An identity that can be **assumed** temporarily — by an EC2 instance, a Lambda function, another AWS account, etc. — no long-lived keys involved |
| **IAM Policy** | A JSON document listing exactly what actions are allowed/denied on which resources |
| **Trust Policy (assume role policy)** | Defines **who** is allowed to assume a role |
| **Instance Profile** | The mechanism that actually attaches an IAM Role to an EC2 instance |

### The Golden Rule: Roles > Users for Applications

For anything running on AWS infrastructure (EC2, Lambda, ECS), always prefer an **IAM Role** over an IAM User with access keys. Roles provide **temporary, automatically-rotated credentials** — nothing to leak, nothing to rotate manually. IAM Users with access keys are for humans or truly external systems that can't assume a role.

---

## Why `aws_iam_policy_document` Instead of Raw JSON?

You *can* write IAM policies as raw JSON strings:
```hcl
resource "aws_iam_policy" "example" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "*"
    }
  ]
}
EOF
}
```
This works, but it's error-prone (easy to break JSON syntax) and doesn't get validated by Terraform until you actually apply it.

**`aws_iam_policy_document`** is a data source that lets you build the same policy using normal HCL blocks — it gets validated at `plan` time, and you can compose it with variables, loops, and conditionals:

```hcl
data "aws_iam_policy_document" "example" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "example" {
  policy = data.aws_iam_policy_document.example.json
}
```

---

## The Trust Policy — "Who Can Assume This Role?"

Every IAM Role needs an **assume role policy** (trust policy) defining who's allowed to use it:

```hcl
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

resource "aws_iam_role" "ec2_s3_role" {
  name               = "ec2-s3-read-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}
```

`identifiers = ["ec2.amazonaws.com"]` means: **only EC2 instances** can assume this role — not Lambda, not another AWS account, not a random IAM user.

---

## The Permissions Policy — "What Can This Role Do?"

Separate from the trust policy, this defines the **actual permissions**:

```hcl
data "aws_iam_policy_document" "s3_read_only" {
  statement {
    sid       = "AllowListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::my-example-bucket"]
  }

  statement {
    sid       = "AllowReadObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::my-example-bucket/*"]
  }
}

resource "aws_iam_policy" "s3_read_only" {
  name   = "s3-read-only-policy"
  policy = data.aws_iam_policy_document.s3_read_only.json
}
```

Notice **two separate statements**: one for listing the bucket (needs the bucket ARN itself), one for reading objects (needs the bucket ARN + `/*`). This is a very common IAM pattern — bucket-level and object-level permissions use different resource ARN formats.

---

## Attaching the Policy to the Role

A policy by itself does nothing until it's attached:

```hcl
resource "aws_iam_role_policy_attachment" "attach_s3_read" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}
```

---

## Instance Profile — Attaching the Role to an EC2 Instance

An IAM Role can't be directly attached to an EC2 instance — you need an **Instance Profile** as the bridge:

```hcl
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-read-profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_instance" "app_server" {
  ami                  = "ami-0f5ee92e2d63afc18"
  instance_type        = "t2.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
}
```

Once launched, any AWS CLI/SDK call made **from inside** this EC2 instance automatically uses these permissions — no access keys stored anywhere on the instance.

---

## Bonus: IAM User With Scoped Permissions (for a human)

```hcl
resource "aws_iam_user" "developer" {
  name = "demo-developer"
}

data "aws_iam_policy_document" "developer_permissions" {
  statement {
    sid       = "AllowEC2ReadOnly"
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
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
```

This user can only **view/describe** EC2 resources (`ec2:Describe*`) — nothing else. This is the least-privilege principle in action: grant only what's needed, nothing more.

---

## The Full Picture

```text
EC2 Instance
     │
     │ uses
     ▼
Instance Profile
     │
     │ wraps
     ▼
IAM Role  ◄──── Trust Policy (who can assume it: EC2 service)
     │
     │ has attached
     ▼
IAM Policy  ◄──── Permissions Policy (what it can do: read S3 bucket X)
```

---

## How to Run

```bash
terraform init
terraform plan
terraform apply
```

### Check outputs
```bash
terraform output
```
```text
app_server_instance_id = "i-0abc123xyz"
developer_user_arn     = "arn:aws:iam::123456789012:user/demo-developer"
iam_policy_arn         = "arn:aws:iam::123456789012:policy/s3-read-only-policy"
iam_role_arn           = "arn:aws:iam::123456789012:role/ec2-s3-read-role"
instance_profile_name  = "ec2-s3-read-profile"
```

### Verify from inside the EC2 instance (optional)
SSH into `app_server` and run:
```bash
aws s3 ls s3://my-example-bucket
```
This works **without any AWS credentials configured on the instance** — it automatically uses the attached IAM role.

### Clean up
```bash
terraform destroy
```

---

## Common Interview Confusions, Clarified

| Question | Answer |
|---|---|
| Can I attach an IAM Role directly to an EC2 instance? | No — you need an **Instance Profile** as the bridge |
| What's the difference between a trust policy and a permissions policy? | Trust policy = who can assume the role. Permissions policy = what the role can do once assumed |
| Why use a Role instead of an IAM User with access keys on an EC2 instance? | Roles give temporary, auto-rotated credentials — nothing to leak or rotate manually |
| Can one role have multiple policies attached? | Yes — attach as many `aws_iam_role_policy_attachment` resources as needed |
| Why use `aws_iam_policy_document` instead of raw JSON? | Validated at plan time, composable with HCL logic (loops, conditionals, variables) instead of string interpolation into JSON |

---

## Interview Answer (Quick Reference)

> "For any AWS service like EC2, I always prefer an IAM Role over a User with static access keys, since roles provide temporary credentials that rotate automatically. A role needs two policies: a trust policy, defining who can assume it — like the EC2 service — and a permissions policy, defining what it's allowed to do, like reading from a specific S3 bucket. I build both using `aws_iam_policy_document` instead of raw JSON strings, since it's validated at plan time and composes better with HCL. To actually attach a role to an EC2 instance, you need an Instance Profile as the bridge — you can't attach a role directly. Once that's wired up, anything running on that EC2 instance automatically gets those permissions without any credentials stored on the machine itself."
