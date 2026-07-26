# Terraform State - Basics and Hands-On

This project explains **what Terraform state is**, why it's needed, and how to inspect/manage it — using a simple EC2 example.

> **Repository structure**
>
> ```text
> terraform-state-basics/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── main.tf
> └── outputs.tf
> ```

---

## What is a State File?

Terraform's **state file** (`terraform.tfstate`) is a JSON file that acts as Terraform's "memory." It maps every resource block in your `.tf` code to the actual real-world resource it created.

When you write:
```hcl
resource "aws_instance" "web" {
  ami           = "ami-123"
  instance_type = "t2.micro"
}
```

Terraform needs to remember: *"this `aws_instance.web` block = the real instance `i-0abc123xyz` in AWS."* That mapping lives in the state file.

---

## Why State is Required

| Purpose | Explanation |
|---|---|
| **Mapping** | Links `.tf` code to real infrastructure IDs |
| **Diffing** | On `terraform plan`, compares code vs state vs real infra to show what changed |
| **Performance** | Avoids querying every single resource from the cloud provider every time |
| **Dependency tracking** | Knows what depends on what, for correct create/destroy order |
| **Metadata** | Stores outputs and resource attributes |

Without state, Terraform has no idea what it already created — it might try to recreate everything from scratch, or fail to update/destroy things properly.

---

## Anatomy of `terraform.tfstate`

It's a JSON file. Key parts look like this:

```json
{
  "version": 4,
  "terraform_version": "1.7.5",
  "serial": 3,
  "lineage": "a1b2c3d4-....",
  "resources": [
    {
      "type": "aws_instance",
      "name": "web",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "attributes": { "id": "i-0abc123", "ami": "ami-xyz" },
          "dependencies": ["aws_security_group.web_sg"]
        }
      ]
    }
  ],
  "outputs": {}
}
```

| Field | What it means |
|---|---|
| `serial` | Increments every time state changes — used to detect stale state |
| `lineage` | Unique ID for this state's "history" — protects against mixing unrelated state files |
| `resources` | The actual tracked infrastructure |
| `dependencies` | What each resource depends on, for correct ordering |

---

## Local Backend (Default)

If you don't configure a backend, Terraform uses the **local backend** automatically — state is saved as a plain file on your machine:
```text
./terraform.tfstate
```
Problems: no team sharing, no locking, easy to lose, plaintext secrets sit on your laptop. (See the separate `terraform-backend` guide for the remote/S3 backend setup.)

---

## Files in This Project

### `main.tf`
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-state-demo"
  }
}
```

---

## Hands-On: Exploring State

### Step 1: Initialize and apply
```bash
terraform init
terraform apply
```
This creates `terraform.tfstate` locally, tracking your new EC2 instance.

### Step 2: List everything Terraform is tracking
```bash
terraform state list
```
```text
aws_instance.web
```

### Step 3: View one resource's full details
```bash
terraform state show aws_instance.web
```
```text
resource "aws_instance" "web" {
    id            = "i-0abc123xyz"
    ami           = "ami-0f5ee92e2d63afc18"
    instance_type = "t2.micro"
    public_ip     = "3.109.211.90"
    tags          = {
        "Name" = "terraform-state-demo"
    }
    ...
}
```

### Step 4: Print the raw state as JSON
```bash
terraform show -json | jq .
```
(requires `jq` installed — or omit `| jq .` to see raw unformatted JSON)

### Step 5: Rename a resource in code without destroying it
Say you rename the resource block from `web` to `app_server`:
```hcl
resource "aws_instance" "app_server" {
  ...
}
```
Without telling Terraform, it would think `web` was deleted and `app_server` is brand new — and try to destroy + recreate. Instead, tell Terraform it's the same resource:
```bash
terraform state mv aws_instance.web aws_instance.app_server
```
Now run:
```bash
terraform plan
```
```text
No changes. Your infrastructure matches the configuration.
```

### Step 6: Stop tracking a resource without destroying it
```bash
terraform state rm aws_instance.app_server
```
This removes it from Terraform's state only — the real EC2 instance in AWS is untouched. Terraform simply "forgets" about it. (Useful if you want to hand a resource off to be managed manually or by another project.)

### Step 7: Refresh state to match real-world changes
If someone manually changed something in the AWS Console, sync your state without changing infrastructure:
```bash
terraform apply -refresh-only
```

### Step 8: Clean up
```bash
terraform destroy
```

---

## Quick Command Reference

| Command | Purpose |
|---|---|
| `terraform state list` | List everything tracked in state |
| `terraform state show <resource>` | View one resource's full attributes |
| `terraform state mv <old> <new>` | Rename a resource in state (after refactoring code) |
| `terraform state rm <resource>` | Stop tracking a resource (does NOT delete real infra) |
| `terraform state pull` | Download raw state as JSON (read-only) |
| `terraform apply -refresh-only` | Sync state with real-world changes, without modifying infra |
| `terraform show` | Human-readable view of everything in current state |

---

## Interview Answer (Quick Reference)

> "State is a JSON file Terraform uses to map my code to real infrastructure — it's how Terraform knows what it already created, so `plan` and `apply` can compute an accurate diff instead of trying to recreate everything every time. Day to day, I use `terraform state list` and `state show` to inspect what's tracked, `state mv` when I rename a resource in code so Terraform doesn't destroy and recreate it, and `state rm` if I need Terraform to stop tracking something without touching the real resource. For local setups, Terraform also keeps a `.tfstate.backup` automatically, but in team/production setups I rely on a remote backend like S3 with versioning instead, since that keeps full history, not just the last version."
