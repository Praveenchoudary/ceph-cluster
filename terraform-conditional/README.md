# Terraform EC2 - Conditional Instance Sizing by Environment

A real hands-on lab: use a conditional expression to pick the EC2 instance type based on environment.

* **Dev** → `t2.micro`
* **QA** → `t3.small`
* **Prod** → `t3.large`

> **Repository structure**
>
> ```text
> terraform-ec2-conditional/
> ├── README.md
> ├── main.tf
> ├── variables.tf
> ├── provider.tf
> └── terraform.tfvars
> ```

---

## Step 1: `provider.tf`

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

---

## Step 2: `variables.tf`

```hcl
variable "environment" {
  description = "Deployment Environment"
  type        = string
}
```

---

## Step 3: `terraform.tfvars`

Initially keep:

```hcl
environment = "dev"
```

---

## Step 4: `main.tf`

```hcl
resource "aws_instance" "web" {

  ami = "ami-0f58b397bc5c1f2e8"   # Amazon Linux 2023 (Example - ap-south-1)

  instance_type = var.environment == "prod" ? "t3.large" : (
    var.environment == "qa" ? "t3.small" : "t2.micro"
  )

  tags = {
    Name = "${var.environment}-web-server"
  }

}
```

---

## Step 5: Initialize Terraform

```bash
terraform init
```

---

## Step 6: Run Plan (dev)

```bash
terraform plan
```

Terraform reads:
```text
environment = dev
```

Evaluates:
```text
Is dev == prod?  → No
Is dev == qa?    → No
Use default      → t2.micro
```

Plan output (simplified):
```text
+ resource "aws_instance" "web"

instance_type = "t2.micro"

tags = {
   Name = "dev-web-server"
}
```

Nothing magical happens — Terraform simply replaces the expression with its result.

---

## Apply (dev)

```bash
terraform apply
```

Creates:
```text
EC2
Name: dev-web-server
Instance Type: t2.micro
```

---

## Now Deploy QA

Open `terraform.tfvars` and change:

```hcl
environment = "qa"
```

```bash
terraform plan
```

Terraform reads:
```text
environment = qa
```

Evaluates:
```text
Is qa == prod?  → No
Is qa == qa?    → Yes
Result: t3.small
```

```bash
terraform apply
```

Creates:
```text
EC2
Name: qa-web-server
Instance Type: t3.small
```

---

## Now Deploy Production

Change `terraform.tfvars`:

```hcl
environment = "prod"
```

```bash
terraform plan
```

Terraform reads:
```text
environment = prod
```

Checks:
```text
Is prod == prod?  → Yes
Result: t3.large
```

```bash
terraform apply
```

Creates:
```text
EC2
Name: prod-web-server
Instance Type: t3.large
```

---

## What Terraform Does Internally

**When `environment = dev`:**
```text
Read variable
   ↓
environment = dev
   ↓
Is dev == prod?
   ↓
No
   ↓
Is dev == qa?
   ↓
No
   ↓
Use default → t2.micro
   ↓
Create EC2
```

**When `environment = qa`:**
```text
Read variable
   ↓
environment = qa
   ↓
Is qa == prod?
   ↓
No
   ↓
Is qa == qa?
   ↓
Yes
   ↓
Choose t3.small
   ↓
Create EC2
```

**When `environment = prod`:**
```text
Read variable
   ↓
environment = prod
   ↓
Is prod == prod?
   ↓
Yes
   ↓
Choose t3.large
   ↓
Create EC2
```

---

## Full Environment Table

| Environment | Instance Type |
| ----------- | -------------- |
| dev         | t2.micro       |
| qa          | t3.small       |
| prod        | t3.large       |

---

## Why Companies Use This Pattern

Instead of maintaining three different Terraform files:

```text
dev/main.tf
qa/main.tf
prod/main.tf
```

you maintain **one Terraform codebase** and change only the input variable:

```hcl
environment = "dev"
```
or
```hcl
environment = "qa"
```
or
```hcl
environment = "prod"
```

The same code automatically provisions the correct infrastructure for each environment. This reduces code duplication and keeps configurations consistent across environments — a pattern used extensively in real production Terraform projects.

---

## Quick Commands Reference

```bash
terraform init                                    # initialize
terraform plan                                    # preview changes for current environment
terraform apply                                   # apply changes
terraform apply -var="environment=qa"             # override environment inline (no need to edit tfvars)
terraform apply -var="environment=prod"
terraform destroy                                 # clean up
```

---

## Note on the AMI

The AMI ID (`ami-0f58b397bc5c1f2e8`) is an example and may become invalid over time or differ by account. Verify it's current for your region:

```bash
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'Images | sort_by(@, &CreationDate)[-1].[ImageId,Name]' \
  --output table \
  --region ap-south-1
```

---

## Interview Answer (Quick Reference)

> "I used a nested conditional (ternary) expression to pick the EC2 instance type based on an `environment` variable — prod gets `t3.large`, qa gets `t3.small`, and everything else defaults to `t2.micro`. This lets me maintain a single Terraform codebase instead of separate files per environment; I just change the `environment` variable value, and the same code provisions the right-sized infrastructure automatically. This pattern is common in real production Terraform projects because it avoids code duplication and keeps environments consistent."
