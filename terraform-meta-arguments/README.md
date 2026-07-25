# Terraform Meta-Arguments - EC2 Examples

This project demonstrates Terraform's **meta-arguments** using simple EC2 instance examples.

> **Repository structure**
>
> ```text
> terraform-meta-arguments/
> ├── README.md
> ├── count/
> │   ├── versions.tf
> │   ├── provider.tf
> │   └── main.tf
> ├── for_each/
> │   ├── versions.tf
> │   ├── provider.tf
> │   └── main.tf
> ├── depends_on/
> │   ├── versions.tf
> │   ├── provider.tf
> │   └── main.tf
> ├── lifecycle/
> │   ├── versions.tf
> │   ├── provider.tf
> │   └── main.tf
> └── provider_alias/
>     ├── versions.tf
>     ├── provider.tf
>     └── main.tf
> ```

---

## What are Meta-Arguments?

Meta-arguments are special arguments that work with **any** resource or module block. They control **how Terraform manages** a resource (behavior), not the resource's actual properties.

- **Regular arguments** → define what the resource looks like (`ami`, `instance_type`)
- **Meta-arguments** → define how Terraform creates/tracks/destroys it (`count`, `for_each`, `depends_on`, `lifecycle`, `provider`)

---

## 1. `count`

Creates multiple copies of a resource, indexed numerically (`0, 1, 2...`).

**Folder:** [`count/`](./count)

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "web-${count.index}"
  }
}
```

- `count = 3` → creates 3 EC2 instances
- `count.index` → gives `0`, `1`, `2` to differentiate each instance
- Reference a specific one: `aws_instance.web[0].id`

**Downside:** if you remove an item from the middle of a list-driven count, Terraform may destroy/recreate resources with shifted indexes.

---

## 2. `for_each`

Creates multiple copies based on a **map or set**, indexed by key (not number). Safer than `count` for dynamic lists.

**Folder:** [`for_each/`](./for_each)

```hcl
resource "aws_instance" "web" {
  for_each      = { dev = "t2.micro", prod = "t3.medium" }
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = each.value

  tags = {
    Name = "web-${each.key}"
  }
}
```

- `each.key` → the map key (`dev`, `prod`)
- `each.value` → the map value (`t2.micro`, `t3.medium`)
- Reference a specific one: `aws_instance.web["dev"].id`

---

## 3. `depends_on`

Explicitly declares a dependency Terraform can't automatically detect through attribute references.

**Folder:** [`depends_on/`](./depends_on)

```hcl
resource "aws_security_group" "web_sg" {
  name = "web-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  depends_on = [aws_security_group.web_sg]
}
```

- Normally Terraform infers order automatically when one resource references another's attribute
- `depends_on` is needed when there's a **hidden** dependency not visible through direct attribute references (e.g. an IAM role must exist before an app boots, even if no attribute links them)

---

## 4. `lifecycle`

Controls create/update/destroy behavior for a resource.

**Folder:** [`lifecycle/`](./lifecycle)

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "web-lifecycle-demo"
  }

  lifecycle {
    prevent_destroy        = true
    create_before_destroy  = true
    ignore_changes          = [tags]
  }
}
```

| Sub-argument | What it does |
|---|---|
| `prevent_destroy = true` | Blocks `terraform destroy` from deleting this resource (protects critical prod resources) |
| `create_before_destroy = true` | Creates the replacement resource first, then destroys the old one (avoids downtime) |
| `ignore_changes = [tags]` | Ignores drift in listed fields — Terraform won't try to "fix" changes made outside Terraform |

---

## 5. `provider` (with alias)

Selects a specific provider configuration — useful for multi-region or multi-account setups.

**Folder:** [`provider_alias/`](./provider_alias)

```hcl
provider "aws" {
  region = "ap-south-1"
}

provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

resource "aws_instance" "web_mumbai" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"
}

resource "aws_instance" "web_us" {
  provider      = aws.us_east
  ami           = "ami-0c101f26f147fa7fd"
  instance_type = "t2.micro"
}
```

- Default `provider "aws"` block (no alias) is used unless overridden
- `provider = aws.us_east` tells this specific resource to use the aliased provider instead

---

## How to Run Any Example

```bash
cd count        # or for_each / depends_on / lifecycle / provider_alias
terraform init
terraform plan
terraform apply
```

To clean up:
```bash
terraform destroy
```

⚠️ Note: `lifecycle/main.tf` has `prevent_destroy = true` — you must remove/comment that block before `terraform destroy` will work on it.

---

## Quick Reference Table

| Meta-argument | Purpose |
|---|---|
| `count` | Create N identical copies (indexed 0, 1, 2...) |
| `for_each` | Create copies from a map/set (indexed by key, safer for dynamic lists) |
| `depends_on` | Force explicit ordering when no attribute reference exists |
| `lifecycle` | Control create/destroy behavior (`prevent_destroy`, `create_before_destroy`, `ignore_changes`) |
| `provider` | Choose which provider config (region/account) a resource uses |
