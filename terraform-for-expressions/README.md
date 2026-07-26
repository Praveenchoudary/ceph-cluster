# Terraform `for` Expressions (Loops) - vs `for_each`

This project explains **`for` expressions** — a way to loop over and transform lists/maps into new lists or maps — and clarifies how they're different from the `for_each` meta-argument.

> **Repository structure**
>
> ```text
> terraform-for-expressions/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── variables.tf
> ├── main.tf
> └── outputs.tf
> ```

---

## `for` Expression vs `for_each` — The Key Confusion

These sound similar and both involve looping, but they do **completely different jobs**:

| | `for` expression | `for_each` (meta-argument) |
|---|---|---|
| Purpose | **Transform** a list/map into a new list/map | **Create multiple resources/modules** |
| Where it's used | Inside any expression — variables, locals, outputs | Only inside a `resource`, `data`, or `module` block |
| What it produces | A new list or map value | Multiple instances of a resource |
| Example | `[for x in list : upper(x)]` | `for_each = toset(list)` |

**Simple way to remember it:**
> `for` expression = "reshape this data into different data."
> `for_each` = "create one resource per item in this data."

---

## `for` Expression Syntax

### 1. List → List
```hcl
[for item in list : expression]
```
```hcl
upper_environments = [for env in var.environments : upper(env)]
# ["dev","qa","prod"] -> ["DEV","QA","PROD"]
```

### 2. List → Map
```hcl
{for item in list : key_expr => value_expr}
```
```hcl
env_name_lengths = { for env in var.environments : env => length(env) }
# -> { dev = 3, qa = 2, prod = 4 }
```

### 3. With a filter (`if` condition)
```hcl
[for item in list : expression if condition]
```
```hcl
non_dev_environments = [for env in var.environments : env if env != "dev"]
# ["dev","qa","prod"] -> ["qa","prod"]
```

### 4. Looping over a Map (key + value)
```hcl
[for key, value in map : expression]
```
```hcl
instance_type_list = [for env, size in var.instance_sizes : "${env}=${size}"]
# -> ["dev=t2.micro", "qa=t3.small", "prod=t3.large"]
```

### 5. Map → Map
```hcl
{for key, value in map : new_key => new_value}
```
```hcl
port_descriptions = { for p in var.ports : p => "allow-port-${p}" }
# -> { 22 = "allow-port-22", 80 = "allow-port-80", 443 = "allow-port-443" }
```

---

## Why `for` Expressions Are Useful

### 1. Prepare data before `for_each` uses it
`for_each` needs a map or set — sometimes your raw data isn't in that shape yet. A `for` expression reshapes it first:
```hcl
locals {
  port_descriptions = { for p in var.ports : p => "allow-port-${p}" }
}

resource "aws_security_group" "web_sg" {
  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = local.port_descriptions[ingress.value]
    }
  }
}
```

### 2. Reshape resource outputs into something more usable
```hcl
output "instance_ids" {
  value = { for k, v in aws_instance.web : k => v.id }
}
```
Turns a full resource map into a simple `{ dev = "i-abc", qa = "i-def" }` style output.

### 3. Filter out unwanted items without writing an `if` in every resource
```hcl
non_dev_environments = [for env in var.environments : env if env != "dev"]
```

---

## Files in This Project

### `main.tf`
```hcl
locals {
  upper_environments   = [for env in var.environments : upper(env)]
  env_name_lengths     = { for env in var.environments : env => length(env) }
  non_dev_environments = [for env in var.environments : env if env != "dev"]
  instance_type_list   = [for env, size in var.instance_sizes : "${env}=${size}"]
  port_descriptions    = { for p in var.ports : p => "allow-port-${p}" }
}

resource "aws_security_group" "web_sg" {
  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = local.port_descriptions[ingress.value]
    }
  }
  # ...
}

resource "aws_instance" "web" {
  for_each      = var.instance_sizes
  instance_type = each.value
  # ...
}
```
This file deliberately uses **both** `for` expressions (in `locals`) and `for_each` (on the resources) side by side, so you can see they're solving different problems in the same project.

---

## How to Run

```bash
terraform init
terraform plan
```

### Check the `for` expression results directly
```bash
terraform console
```
```
> [for env in ["dev","qa","prod"] : upper(env)]
[
  "DEV",
  "QA",
  "PROD",
]

> {for env in ["dev","qa","prod"] : env => length(env)}
{
  "dev" = 3
  "prod" = 4
  "qa" = 2
}

> [for env in ["dev","qa","prod"] : env if env != "dev"]
[
  "qa",
  "prod",
]

> exit
```

```bash
terraform apply
```

### Check the actual outputs
```bash
terraform output
```
```text
env_name_lengths = {
  "dev" = 3
  "prod" = 4
  "qa" = 2
}
instance_ids = {
  "dev" = "i-0abc111..."
  "prod" = "i-0abc222..."
  "qa" = "i-0abc333..."
}
instance_type_list = [
  "dev=t2.micro",
  "prod=t3.large",
  "qa=t3.small",
]
non_dev_environments = [
  "qa",
  "prod",
]
port_descriptions = {
  "22" = "allow-port-22"
  "443" = "allow-port-443"
  "80" = "allow-port-80"
}
upper_environments = [
  "DEV",
  "QA",
  "PROD",
]
```

### Clean up
```bash
terraform destroy
```

---

## Quick Reference

| Goal | Syntax |
|---|---|
| Transform a list | `[for x in list : expr]` |
| Transform a list into a map | `{for x in list : key => value}` |
| Filter a list | `[for x in list : x if condition]` |
| Loop over a map's keys and values | `[for k, v in map : expr]` |
| Transform a map into a new map | `{for k, v in map : k => new_expr}` |

---

## Interview Answer (Quick Reference)

> "A `for` expression transforms a list or map into a new list or map — for example, `[for env in var.environments : upper(env)]` uppercases every item in a list. It's different from `for_each`, which is a meta-argument used only inside a resource, data, or module block to create multiple copies of that block. I think of `for` expressions as reshaping data, and `for_each` as creating infrastructure from data. In practice I often use them together — a `for` expression inside `locals` prepares or filters data into the right shape, like a map keyed by port number, and then `for_each` or a `dynamic` block uses that prepared data to actually create resources."
