# Terraform Modules - Reusable EC2 Module Example

This project demonstrates **Terraform modules** using a simple, reusable EC2 module — called twice with different inputs (dev + prod).

> **Repository structure**
>
> ```text
> terraform-modules-ec2/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── main.tf
> ├── outputs.tf
> └── modules/
>     └── ec2/
>         ├── main.tf
>         ├── variables.tf
>         └── outputs.tf
> ```

---

## What is a Module?

A **module** is a reusable, self-contained package of Terraform code (resources, variables, outputs) that you can call from other Terraform configurations — instead of copy-pasting the same resource block every time you need similar infrastructure.

Think of it like a **function** in programming:
- You define it once (with inputs and outputs)
- You call it multiple times with different input values
- Each call creates its own independent set of resources

**Without a module** — copy-pasted code for dev and prod:
```hcl
resource "aws_instance" "dev_server" {
  ami           = "ami-123"
  instance_type = "t2.micro"
  tags = { Name = "dev-web-server" }
}

resource "aws_instance" "prod_server" {
  ami           = "ami-123"
  instance_type = "t3.medium"
  tags = { Name = "prod-web-server" }
}
```
Both blocks are nearly identical — only the name and instance type differ. If you need to fix a bug or add a new setting, you have to update it in **every copy**.

**With a module** — write the EC2 logic once, reuse it:
```hcl
module "dev_server" {
  source        = "./modules/ec2"
  instance_name = "dev-web-server"
  ami_id        = "ami-123"
  instance_type = "t2.micro"
}

module "prod_server" {
  source        = "./modules/ec2"
  instance_name = "prod-web-server"
  ami_id        = "ami-123"
  instance_type = "t3.medium"
}
```
One EC2 module definition, called twice with different values. Fix a bug once in the module → both dev and prod automatically benefit.

---

## Anatomy of a Module

Every module typically has 3 files:

| File | Purpose |
|---|---|
| `main.tf` | The actual resource(s) the module creates |
| `variables.tf` | Inputs the module accepts |
| `outputs.tf` | Values the module returns to whoever calls it |

---

## The EC2 Module in This Project

### `modules/ec2/variables.tf`
```hcl
variable "instance_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}
```

### `modules/ec2/main.tf`
```hcl
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name = var.instance_name
  }
}
```

### `modules/ec2/outputs.tf`
```hcl
output "instance_id" {
  value = aws_instance.this.id
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
```

---

## Calling the Module (Root `main.tf`)

```hcl
module "dev_server" {
  source        = "./modules/ec2"
  instance_name = "dev-web-server"
  ami_id        = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"
}

module "prod_server" {
  source        = "./modules/ec2"
  instance_name = "prod-web-server"
  ami_id        = "ami-0f5ee92e2d63afc18"
  instance_type = "t3.medium"
}
```

- `source = "./modules/ec2"` → path to the module's folder
- Everything else (`instance_name`, `ami_id`, `instance_type`) matches the module's `variables.tf` — these are the inputs you're passing in

### Reading module outputs
```hcl
output "dev_instance_id" {
  value = module.dev_server.instance_id
}
```
Syntax: `module.<module_name>.<output_name>`

---

## How to Run

```bash
terraform init
```
This also initializes the local module (`./modules/ec2`).

```bash
terraform plan
```
You'll see **two separate EC2 instances** planned — one from each module call.

```bash
terraform apply
```

### Check outputs
```bash
terraform output
```
```text
dev_instance_id  = "i-0abc111..."
dev_public_ip    = "3.109.x.x"
prod_instance_id = "i-0abc222..."
prod_public_ip   = "13.235.x.x"
```

### Clean up
```bash
terraform destroy
```

---

## Why Companies Use Modules

| Without modules | With modules |
|---|---|
| Copy-paste same resource block everywhere | Write once, reuse everywhere |
| Bug fix = update every copy manually | Bug fix = update the module once, everyone benefits |
| Hard to keep dev/staging/prod consistent | Same tested module, different input values per environment |
| No clear reusable "unit" of infrastructure | Modules become building blocks (VPC module, EC2 module, RDS module, etc.) |

This is exactly the same modules pattern used in the `infra/modules/` + `infra/envs/` structure from the earlier Terraform environment setup — one module, called from `dev`, `staging`, and `prod` folders with different `.tfvars`.

---

## Interview Answer (Quick Reference)

> "A module is a reusable, self-contained piece of Terraform code — like a function — that takes inputs, creates resources, and returns outputs. Instead of copy-pasting the same EC2 resource block for dev and prod, I write the EC2 logic once inside a module, then call that module twice with different inputs, like instance size or name. This means if I need to fix something or add a new setting, I update it in one place — the module — and every environment that uses it automatically gets the fix. This is the standard pattern for keeping infrastructure DRY and consistent across environments."
