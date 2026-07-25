# Terraform Data Sources - Read Existing Infrastructure

This project demonstrates how to use **data sources** in Terraform to read/fetch information about existing infrastructure, without creating or managing it.

> **Repository structure**
>
> ```text
> terraform-data-sources/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── data.tf
> ├── main.tf
> └── outputs.tf
> ```

---

## What is a Data Source?

A **data source** lets Terraform **read information about existing infrastructure** that Terraform did NOT create — without managing or owning it. It's **read-only** — Terraform just looks up the info and uses it; it never creates, modifies, or destroys what a data source points to.

## `resource` vs `data`

| | `resource` | `data` |
|---|---|---|
| Purpose | **Create/manage** infrastructure | **Read/fetch** existing infrastructure |
| Terraform owns it? | Yes — tracked in state, can be destroyed | No — just referenced, never destroyed by Terraform |
| Example | Create a new VPC | Look up the ID of an already-existing default VPC |
| Plan output | "will be created / changed / destroyed" | "Reading..." |

---

## Why You Need This

Imagine you want to launch an EC2 instance into your company's **existing default VPC** — one that already exists in AWS, created outside this Terraform project.

**Without a data source (hardcoded, brittle):**
```hcl
resource "aws_instance" "web" {
  subnet_id = "subnet-0d78ac8f78970cc0b"   # breaks if this changes or doesn't exist elsewhere
}
```

**With a data source (dynamic, safe):**
```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_instance" "web" {
  subnet_id = data.aws_subnets.default.ids[0]
}
```

No hardcoding — Terraform queries AWS at `plan`/`apply` time and gets the real, current values.

---

## Files in This Project

### `versions.tf`
```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

### `provider.tf`
```hcl
provider "aws" {
  region = "ap-south-1"
}
```

### `data.tf`
```hcl
# Fetch the latest Amazon Linux 2023 AMI (don't hardcode it!)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Fetch the existing default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch subnets inside that default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Fetch the current AWS account ID
data "aws_caller_identity" "current" {}

# Fetch available Availability Zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}
```

### `main.tf`
```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = data.aws_subnets.default.ids[0]

  tags = {
    Name = "web-using-data-source"
  }
}
```

### `outputs.tf`
```hcl
output "ami_id_used" {
  value = data.aws_ami.amazon_linux.id
}

output "default_vpc_id" {
  value = data.aws_vpc.default.id
}

output "default_subnet_ids" {
  value = data.aws_subnets.default.ids
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "availability_zones" {
  value = data.aws_availability_zones.available.names
}

output "instance_id" {
  value = aws_instance.web.id
}
```

---

## How to Run

```bash
terraform init
terraform plan
```

You'll see something like:
```text
data.aws_ami.amazon_linux: Reading...
data.aws_vpc.default: Reading...
data.aws_caller_identity.current: Reading...
data.aws_availability_zones.available: Reading...
data.aws_ami.amazon_linux: Read complete after 1s [id=ami-0abcdef1234567890]
data.aws_vpc.default: Read complete after 1s [id=vpc-0123456789abcdef0]
data.aws_subnets.default: Reading...
data.aws_subnets.default: Read complete after 1s

Plan: 1 to add, 0 to change, 0 to destroy.
```

Notice: data sources always show **"Reading..."** — they never appear as "to add / change / destroy," because Terraform isn't creating them, just reading current values.

```bash
terraform apply
```

To clean up (only destroys the EC2 instance — data sources are never "destroyed" since Terraform never owned them):
```bash
terraform destroy
```

---

## Common Data Sources You'll Use in Real Projects

| Data source | Purpose |
|---|---|
| `data "aws_ami"` | Get latest/specific AMI ID instead of hardcoding |
| `data "aws_vpc"` | Reference an existing VPC (e.g., default VPC) |
| `data "aws_subnets"` | Get subnet IDs inside a VPC |
| `data "aws_availability_zones"` | Get list of AZs available in the region |
| `data "aws_caller_identity"` | Get current AWS account ID (useful for building ARNs) |
| `data "aws_iam_policy_document"` | Build IAM policy JSON dynamically instead of hardcoding |
| `data "terraform_remote_state"` | Read outputs from another Terraform project's state file |

---

## Simple Analogy

> **`resource`** = "build me a house" (Terraform owns it, can knock it down later)
> **`data`** = "look up the address of the house next door" (Terraform just reads it, never touches it)

---

## Interview Answer (Quick Reference)

> "A data source is a way for Terraform to read information about infrastructure it doesn't manage, without creating or modifying it. For example, instead of hardcoding an AMI ID which changes over time, I use `data "aws_ami"` to always fetch the latest one at plan time. Or if I need to reference an existing VPC that another team created, I use `data "aws_vpc"` to look it up dynamically instead of hardcoding the ID. The key difference from a `resource` block is that Terraform only reads the data — it never creates, updates, or destroys what a data source points to."
