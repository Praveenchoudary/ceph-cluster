# Terraform Dynamic Blocks - Security Group + EC2 Example

This project demonstrates **dynamic blocks** in Terraform using a security group with multiple ingress rules, attached to a simple EC2 instance.

> **Repository structure**
>
> ```text
> terraform-dynamic-blocks/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── variables.tf
> ├── main.tf
> └── outputs.tf
> ```

---

## Simple Intro: Why Do We Need Dynamic Blocks?

Some Terraform resources have **repeated nested blocks** inside them — like a security group needing multiple `ingress` rules (one per port). Normally, you'd write each one by hand:

```hcl
resource "aws_security_group" "web" {
  name = "web-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

If you need 3 ports, you write `ingress { }` 3 times. Need 10 ports? Write it 10 times. This is:
- Repetitive and hard to maintain
- Painful to update if the list of ports comes from a variable (you'd have to manually add/remove blocks every time the list changes)

**A dynamic block solves this** — it lets you generate these repeated nested blocks automatically from a list or map, so you write the block **once**, and Terraform repeats it for you.

```hcl
dynamic "ingress" {
  for_each = var.ingress_ports
  content {
    from_port   = ingress.value
    to_port     = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Add a 4th port to the list → Terraform automatically creates a 4th `ingress` block. No manual copy-pasting, no editing multiple blocks by hand.

---

## Syntax Breakdown

```hcl
dynamic "ingress" {              # the nested block type you want to repeat
  for_each = var.ingress_ports    # the collection to loop over (list, set, or map)
  content {                        # the actual block content, repeated per item
    from_port = ingress.value      # "ingress" here refers to the current loop item
    ...
  }
}
```

- `dynamic "<block_name>"` → tells Terraform which nested block type to generate (must be a real nested block the resource supports, e.g. `ingress`)
- `for_each` → the list/set/map to iterate over
- Inside `content { }` → use `ingress.value` (or `ingress.key` for a map) to access the current item

---

## Without Dynamic Block vs With Dynamic Block

| Without `dynamic` | With `dynamic` |
|---|---|
| Write `ingress { }` manually for each port | Write it once, loop over a list |
| Adding a port = editing `.tf` code, adding a whole new block | Adding a port = just adding a number to the variable list |
| Hard to maintain with 10+ rules | Scales cleanly to any number of rules |

---

## Files in This Project

### `variables.tf`
```hcl
variable "ingress_ports" {
  type    = list(number)
  default = [22, 80, 443]
}
```

### `main.tf`
```hcl
resource "aws_security_group" "web_sg" {
  name = "web-sg-dynamic-demo"

  dynamic "ingress" {
    for_each = var.ingress_ports
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
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name = "web-dynamic-sg-demo"
  }
}
```

---

## How to Run

```bash
terraform init
terraform plan
```

You'll see **3 `ingress` rules generated automatically** — one for each port in `var.ingress_ports` (22, 80, 443).

```bash
terraform apply
```

### Try adding a port dynamically
Edit `variables.tf`:
```hcl
default = [22, 80, 443, 8080]
```
```bash
terraform plan
```
You'll see a **4th `ingress` rule added automatically** — no other code changes needed.

### Check outputs
```bash
terraform output
```

### Clean up
```bash
terraform destroy
```

---

## When to Use Dynamic Blocks (Real-World Scenarios)

| Scenario | Why dynamic block helps |
|---|---|
| Security group with multiple ports | Add/remove ports by editing a list, not multiple blocks |
| IAM policy with multiple statements | Generate `statement` blocks from a list of permissions |
| Load balancer with multiple listener rules | Generate `listener` blocks per port/protocol combination |
| Route table with multiple routes | Generate `route` blocks from a list of CIDR/gateway pairs |

---

## Interview Answer (Quick Reference)

> "A dynamic block lets me generate repeated nested blocks inside a resource — like multiple `ingress` rules in a security group — based on a list or map, instead of writing each block manually. For example, with a list of ports like `[22, 80, 443]`, I use `dynamic "ingress"` with `for_each = var.ports`, and Terraform generates one `ingress` block per port automatically. This matters because without it, adding a new port means manually writing a whole new nested block; with a dynamic block, it just means adding a value to a list. It's especially useful for resources like security groups, IAM policies, or load balancers, where the number of nested rules can vary."
