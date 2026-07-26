# Terraform Variables & tfvars - Deep Dive

This project covers Terraform **variables** in depth — types, validation, sensitive values, and every way to set variable values (`tfvars`, CLI flags, environment variables) — using a real security group + EC2 example.

> **Repository structure**
>
> ```text
> terraform-variables/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── variables.tf
> ├── main.tf
> ├── outputs.tf
> ├── terraform.tfvars
> ├── prod.tfvars
> └── secrets.tfvars.example
> ```

---

## What is a Variable?

A **variable** is an input to your Terraform configuration — it lets you avoid hardcoding values like region, instance type, or environment name directly in your `.tf` files.

```hcl
variable "instance_type" {
  type    = string
  default = "t2.micro"
}

resource "aws_instance" "web" {
  instance_type = var.instance_type   # reference it with var.<name>
}
```

Instead of hardcoding `"t2.micro"` in 10 places, you define it once and reuse `var.instance_type` everywhere — change the default (or override it) once, and everything updates.

---

## Variable Types

### 1. `string`
```hcl
variable "aws_region" {
  type    = string
  default = "ap-south-1"
}
```

### 2. `number`
```hcl
variable "instance_count" {
  type    = number
  default = 1
}
```

### 3. `bool`
```hcl
variable "enable_monitoring" {
  type    = bool
  default = false
}
```

### 4. `list(...)`
```hcl
variable "allowed_ports" {
  type    = list(number)
  default = [22, 80]
}
```
Access an item: `var.allowed_ports[0]`

### 5. `map(...)`
```hcl
variable "instance_type_map" {
  type = map(string)
  default = {
    dev  = "t2.micro"
    prod = "t3.large"
  }
}
```
Access a value: `var.instance_type_map["dev"]` or `var.instance_type_map[var.environment]`

### 6. `object({...})` — structured/complex type
```hcl
variable "server_config" {
  type = object({
    name          = string
    instance_type = string
    monitoring    = bool
  })
  default = {
    name          = "web-server"
    instance_type = "t2.micro"
    monitoring    = false
  }
}
```
Access a field: `var.server_config.name`

---

## Validation Blocks

You can enforce rules on a variable's value, so `plan`/`apply` fails early with a clear message instead of a confusing AWS error later:

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}
```

If someone runs `terraform apply -var="environment=staging"`, they'll immediately see:
```text
Error: Invalid value for variable

environment must be one of: dev, qa, prod.
```

---

## Sensitive Variables

Mark a variable `sensitive = true` to hide its value from `plan`/`apply` console output and logs:

```hcl
variable "db_password" {
  type      = string
  sensitive = true
  default   = "changeme123"
}
```

Terraform will show:
```text
db_password = (sensitive value)
```
instead of printing the real password.

> Note: `sensitive = true` hides the value from CLI output — it does **not** encrypt it inside the state file. The state file itself must still be protected (via a remote backend with encryption, like S3 with `encrypt = true`).

If you reference a sensitive variable in an `output`, that output must also be marked sensitive, or Terraform will error:
```hcl
output "db_password_is_set" {
  value     = var.db_password
  sensitive = true
}
```

---

## Ways to Set Variable Values (in Precedence Order)

Terraform checks these sources, and **later ones override earlier ones**:

| Priority (low → high) | Source | Example |
|---|---|---|
| 1 (lowest) | `default` value in `variable` block | `default = "t2.micro"` |
| 2 | `terraform.tfvars` file | auto-loaded, no flag needed |
| 3 | `*.auto.tfvars` files | auto-loaded, no flag needed |
| 4 | `-var-file` flag | `terraform apply -var-file="prod.tfvars"` |
| 5 | `-var` flag | `terraform apply -var="environment=prod"` |
| 6 (highest) | `TF_VAR_<name>` environment variable | `export TF_VAR_environment=prod` |

### `terraform.tfvars` (auto-loaded, no flag needed)
```hcl
environment    = "dev"
instance_count = 2
```
Just having this file present is enough — Terraform loads it automatically on every `plan`/`apply` in that directory.

### Named `.tfvars` file (must be passed explicitly)
```hcl
# prod.tfvars
environment       = "prod"
instance_count    = 3
enable_monitoring = true
```
```bash
terraform apply -var-file="prod.tfvars"
```

### Inline `-var` flag (highest common override, good for quick overrides)
```bash
terraform apply -var="environment=qa" -var="instance_count=1"
```

### Environment variable (useful in CI/CD pipelines)
```bash
export TF_VAR_environment=prod
terraform apply
```

---

## Handling Secrets Safely

Never commit real secrets into `terraform.tfvars` or any tracked file. The pattern used in this project:

```text
secrets.tfvars.example   ← committed to git, shows the expected format
secrets.tfvars           ← gitignored, contains real values, never committed
```

```bash
cp secrets.tfvars.example secrets.tfvars
# edit secrets.tfvars with real values
terraform apply -var-file="secrets.tfvars"
```

In real production pipelines, secrets usually come from a secrets manager (AWS Secrets Manager, HashiCorp Vault) or CI/CD secret variables (`TF_VAR_db_password` set as a masked CI secret) — not from a `.tfvars` file at all.

---

## Files in This Project

### `variables.tf`
Defines every type shown above: `string`, `number`, `bool`, `list`, `map`, `object`, plus a `sensitive` variable and a `validation` block.

### `main.tf`
```hcl
resource "aws_security_group" "web_sg" {
  name = "${var.environment}-web-sg"

  dynamic "ingress" {
    for_each = var.allowed_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  count                  = var.instance_count
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = var.instance_type_map[var.environment]
  monitoring             = var.enable_monitoring
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name        = "${var.environment}-${var.server_config.name}-${count.index}"
    Environment = var.environment
  }
}
```

This ties together: `var.environment` (with validation), `var.instance_count` (number, drives `count`), `var.instance_type_map[var.environment]` (map lookup), `var.enable_monitoring` (bool), `var.allowed_ports` (list, drives a dynamic block), and `var.server_config.name` (object field).

---

## How to Run

### Default (dev, from `terraform.tfvars`)
```bash
terraform init
terraform plan
terraform apply
```

### Override with the named prod file
```bash
terraform apply -var-file="prod.tfvars"
```

### Quick one-off override without any file
```bash
terraform apply -var="environment=qa" -var="instance_count=1"
```

### Using an environment variable
```bash
export TF_VAR_environment=prod
terraform apply
```

### Check outputs
```bash
terraform output
```
Notice `db_password_is_set` prints as `(sensitive value)`.

### Clean up
```bash
terraform destroy
```

---

## Interview Answer (Quick Reference)

> "Variables let me parameterize Terraform code instead of hardcoding values. Terraform supports simple types like string, number, and bool, as well as collection types like list and map, and structured types like object. I use `validation` blocks to catch bad input early with a clear error message, and mark sensitive values like passwords with `sensitive = true` so they don't print in plan or apply output — though that alone doesn't encrypt them in the state file, so I still rely on an encrypted remote backend for that. For setting values, Terraform checks multiple sources in order: the variable's default, `terraform.tfvars` which loads automatically, a named `.tfvars` file passed with `-var-file`, the `-var` flag, and finally `TF_VAR_` environment variables, which take the highest precedence and are especially useful in CI/CD pipelines."
