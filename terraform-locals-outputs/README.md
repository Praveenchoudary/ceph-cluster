# Terraform Locals & Outputs

This project explains **`locals`** and **`output`** blocks — two things used in almost every Terraform project, but rarely explained on their own.

> **Repository structure**
>
> ```text
> terraform-locals-outputs/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── variables.tf
> ├── main.tf
> └── outputs.tf
> ```

---

## What is a `locals` Block?

A **local value** is a named value computed **inside** your Terraform code — not passed in from outside like a variable, and not something AWS returns like a resource attribute. It's Terraform's version of a helper variable.

```hcl
locals {
  name_prefix = "${var.environment}-${var.app_name}"
}
```

Reference it anywhere in the same module with `local.<name>` (singular `local`, not `locals`):
```hcl
resource "aws_instance" "web" {
  tags = {
    Name = local.name_prefix
  }
}
```

### `variable` vs `local` vs resource attribute

| | `variable` | `local` | resource attribute |
|---|---|---|---|
| Where it comes from | Passed in from outside (tfvars, CLI, env) | Computed inside your code | Returned by the cloud provider after creation |
| Can be overridden by the caller? | Yes | No | No |
| Example | `var.environment` | `local.name_prefix` | `aws_instance.web.id` |

---

## Why Use `locals`?

### 1. Avoid repeating the same expression everywhere
Without locals:
```hcl
resource "aws_instance" "web" {
  tags = { Name = "${var.environment}-${var.app_name}-web" }
}

resource "aws_security_group" "web_sg" {
  name = "${var.environment}-${var.app_name}-sg"
}
```
With locals:
```hcl
locals {
  name_prefix = "${var.environment}-${var.app_name}"
}

resource "aws_instance" "web" {
  tags = { Name = "${local.name_prefix}-web" }
}

resource "aws_security_group" "web_sg" {
  name = "${local.name_prefix}-sg"
}
```
Change the prefix logic once, every resource using it updates.

### 2. Simplify a complex expression into a readable name
```hcl
locals {
  instance_type = var.environment == "prod" ? "t3.medium" : "t2.micro"
}
```
Instead of repeating that ternary in every resource, you compute it once and reference `local.instance_type`.

### 3. Combine values into a reusable structure
```hcl
locals {
  common_tags = {
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "web" {
  tags = merge(local.common_tags, { Name = "web-server" })
}
```

---

## What is an `output` Block?

An **output** exposes a value from your Terraform configuration — either to display in the CLI after `apply`, or for another Terraform project to read (via `terraform_remote_state`), or for use in scripts/CI pipelines.

```hcl
output "instance_id" {
  description = "The ID of the created EC2 instance"
  value       = aws_instance.web.id
}
```

After `terraform apply`:
```text
Outputs:

instance_id = "i-0abc123xyz"
```

### Common Output Patterns

**1. Simple single value**
```hcl
output "instance_id" {
  value = aws_instance.web.id
}
```

**2. Referencing a local**
```hcl
output "name_prefix_used" {
  value = local.name_prefix
}
```

**3. A whole object/map as one output**
```hcl
output "instance_summary" {
  value = {
    id            = aws_instance.web.id
    public_ip     = aws_instance.web.public_ip
    instance_type = aws_instance.web.instance_type
  }
}
```
Useful for grouping related values instead of creating many separate small outputs.

**4. Sensitive output**
```hcl
output "security_group_id" {
  value     = aws_security_group.web_sg.id
  sensitive = true
}
```
Hides the value from normal CLI output — Terraform prints `(sensitive value)` instead. Still visible via `terraform output security_group_id` explicitly, or in the raw state file, so this is about hiding it from casual/log output, not encrypting it.

---

## Why Outputs Matter

| Use case | How outputs help |
|---|---|
| Quick visibility after `apply` | See key IDs/IPs immediately without checking the AWS Console |
| Feeding another Terraform project | `terraform_remote_state` reads another project's outputs |
| CI/CD pipelines | Scripts can parse `terraform output -json` to get values for later steps |
| Module reuse | A module's outputs are the only way calling code can access what it created |

### Reading outputs from the CLI
```bash
terraform output                     # show all outputs
terraform output instance_id          # show one specific output
terraform output -json                # machine-readable JSON, useful in scripts/CI
terraform output -raw instance_id     # raw value, no quotes - useful for piping into other commands
```

---

## Files in This Project

### `main.tf`
```hcl
locals {
  name_prefix = "${var.environment}-${var.app_name}"

  common_tags = {
    Environment = var.environment
    Application = var.app_name
    ManagedBy   = "terraform"
  }

  instance_type = var.environment == "prod" ? "t3.medium" : "t2.micro"

  full_config = {
    name          = "${local.name_prefix}-web"
    instance_type = local.instance_type
    tags          = local.common_tags
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = local.full_config.instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = merge(local.common_tags, { Name = local.full_config.name })
}
```

---

## How to Run

```bash
terraform init
terraform plan
terraform apply
```

### Check the outputs
```bash
terraform output
```
```text
instance_id       = "i-0abc123xyz"
instance_summary  = {
  "id" = "i-0abc123xyz"
  "instance_type" = "t2.micro"
  "public_ip" = "3.109.211.90"
  "tags" = { ... }
}
name_prefix_used  = "dev-payments"
security_group_id = <sensitive>
```

### See the sensitive one explicitly
```bash
terraform output security_group_id
```

### Try prod sizing
```bash
terraform apply -var="environment=prod"
```
`local.instance_type` automatically becomes `t3.medium`, and every tag/name using `local.name_prefix` updates too.

### Clean up
```bash
terraform destroy
```

---

## Interview Answer (Quick Reference)

> "`locals` let me compute a value once inside my code and reuse it everywhere, instead of repeating the same expression — like building a consistent name prefix from environment and app name, or picking an instance type with a conditional. Unlike variables, locals aren't set from outside; they're derived internally. `output` blocks expose values after apply — either for quick visibility in the CLI, for another Terraform project to read via `terraform_remote_state`, or for CI/CD scripts to consume with `terraform output -json`. I mark outputs `sensitive = true` when they shouldn't print in normal CLI output, like IDs tied to sensitive resources."
