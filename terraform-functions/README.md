# Terraform Functions - When to Use Them (Real-World Scenarios)

This project demonstrates **when and why** to use common Terraform built-in functions, with a real, runnable VPC + EC2 + IAM example combining all of them.

> **Repository structure**
>
> ```text
> terraform-functions-usecases/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── variables.tf
> ├── main.tf
> ├── outputs.tf
> └── setup.sh
> ```

---

## What are Terraform Functions?

Built-in helpers used inside expressions to transform, combine, or calculate values. Terraform does **not** support custom user-defined functions — only the ones it ships with.

Test any function instantly:
```bash
terraform console
```
```
> upper("hello")
"HELLO"
> exit
```

---

## When Each Function is Actually Useful

### `join()` — Building consistent resource names
**Use it when:** naming conventions need to stay consistent across environments/teams instead of typing names by hand everywhere.
```hcl
tags = {
  Name = join("-", [var.environment, var.app_name, "web"])
}
# → "dev-payments-web"
```
Change `var.environment` once — every resource name using it updates automatically.

---

### `merge()` — Combining default tags with resource-specific tags
**Use it when:** every resource needs common tags (owner, cost-center) PLUS its own specific tags.
```hcl
locals {
  default_tags = {
    ManagedBy = "terraform"
    Team      = "platform"
  }
}

resource "aws_instance" "web" {
  tags = merge(local.default_tags, { Name = "web-server" })
}
```
Define common tags once; every resource merges in its own name — no copy-pasting the same tags everywhere.

---

### `length()` — Making `count` dynamic instead of hardcoded
**Use it when:** the number of resources should scale with a list, not a hardcoded number.
```hcl
resource "aws_subnet" "public" {
  count      = length(var.subnet_cidrs)
  cidr_block = var.subnet_cidrs[count.index]
}
```
Add a 4th CIDR to the list → automatically creates a 4th subnet. No manual `count = 4` update needed.

---

### `lookup()` — Safe map access with a fallback default
**Use it when:** different environments need different values, but you want a safe default if one's missing.
```hcl
instance_type = lookup(var.instance_sizes, var.environment, "t2.micro")
```
If `var.environment = "staging"` isn't in the map, falls back to `"t2.micro"` instead of erroring.

---

### `format()` — Building strings with specific patterns
**Use it when:** you need consistent, padded naming across multiple resources.
```hcl
tags = {
  Name = format("${var.environment}-subnet-%02d", count.index + 1)
}
# → dev-subnet-01, dev-subnet-02, dev-subnet-03
```

---

### `file()` — Injecting scripts without pasting them inline
**Use it when:** you have a setup script and don't want 50 lines of bash pasted inside your `.tf` file.
```hcl
resource "aws_instance" "web" {
  user_data = file("${path.module}/setup.sh")
}
```
Keeps `.tf` clean; the script lives in its own file, editable separately.

---

### `jsonencode()` — Writing IAM policies without manual JSON escaping
**Use it when:** writing IAM/resource policies, since raw JSON strings in HCL require painful quote-escaping.
```hcl
policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect   = "Allow"
    Action   = ["s3:GetObject"]
    Resource = "*"
  }]
})
```
Write it as a normal HCL object; `jsonencode()` converts it automatically.

---

### `coalesce()` — Pick the first non-null value
**Use it when:** you want a variable's value, but need to fall back to something else if it's not set.
```hcl
final_instance_type = coalesce(var.custom_instance_type, local.instance_type_from_env)
```
If `var.custom_instance_type` is `null`, uses the fallback value instead.

---

## The Pattern Across All of These

Reach for a function whenever you'd otherwise have to:
- **Repeat the same value/logic** in multiple places → `join`, `format`, `merge`
- **Hardcode something that should scale with data** → `length`, `count`
- **Handle a "what if this is missing" case** → `lookup`, `coalesce`
- **Convert between formats** → `jsonencode`, `tostring`, `file`

---

## How to Run

```bash
terraform init
terraform plan
terraform apply
```

### Check the results
```bash
terraform output
```

Expected (values will vary slightly):
```text
default_tags = {
  "ManagedBy" = "terraform"
  "Team" = "platform"
}
final_instance_type = "t2.micro"
instance_id = "i-0abcdef1234567890"
instance_name = "dev-payments-web"
instance_type_from_env = "t2.micro"
subnet_count = 3
subnet_names = [
  "dev-subnet-01",
  "dev-subnet-02",
  "dev-subnet-03",
]
```

### Clean up
```bash
terraform destroy
```

---

## Interview Answer (Quick Reference)

> "I use functions whenever I'd otherwise be hardcoding something that should be dynamic. `join` and `format` build consistent resource names from variables instead of typing them by hand. `merge` combines common default tags with resource-specific tags so I don't repeat the same tags everywhere. `length` drives `count` dynamically based on a list, so adding an item automatically creates a new resource. `lookup` and `coalesce` give me safe fallback defaults instead of the plan failing when a value is missing. `file` keeps long scripts out of my `.tf` code, and `jsonencode` lets me write IAM policies as normal HCL objects instead of manually escaping JSON strings."

---

## Note on the AMI

The AMI ID in `main.tf` is hardcoded and may become invalid over time. Verify it's current for your region:

```bash
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'Images | sort_by(@, &CreationDate)[-1].[ImageId,Name]' \
  --output table \
  --region ap-south-1
```
