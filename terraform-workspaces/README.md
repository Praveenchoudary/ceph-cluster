# Terraform Workspaces - Simple EC2 Module Example

This project demonstrates **Terraform workspaces** using a simple EC2 module, and explains when to use them — and why most real production teams avoid them for managing environments.

> **Repository structure**
>
> ```text
> terraform-workspaces/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── backend.tf
> ├── main.tf
> ├── variables.tf
> ├── outputs.tf
> ├── terraform.tfvars
> └── modules/
>     └── ec2/
>         ├── main.tf
>         ├── variables.tf
>         └── outputs.tf
> ```

---

## What is a Terraform Workspace?

A **workspace** is a way to maintain **multiple, separate state files** using the **same configuration code** (same `.tf` files), without needing separate folders per environment.

By default, every Terraform project has one workspace called `default`. When you create additional workspaces, Terraform keeps a **separate state file per workspace**, all using the exact same code.

```bash
terraform workspace list
# * default

terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace list
#   default
# * dev
#   staging
#   prod
```

Each workspace's state is stored separately:
```
terraform.tfstate.d/
├── dev/terraform.tfstate
├── staging/terraform.tfstate
└── prod/terraform.tfstate
```
(Or, if using an S3 backend, under a workspace-specific key path automatically managed by Terraform.)

---

## How It Works With This EC2 Example

### `modules/ec2/main.tf`
```hcl
resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = {
    Name        = "${var.env}-ec2"
    Environment = var.env
  }
}
```

### `main.tf` (root)
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

module "ec2" {
  source        = "./modules/ec2"
  env           = terraform.workspace
  ami_id        = var.ami_id
  instance_type = var.instance_type
}
```

Notice: `env = terraform.workspace` — this automatically uses whichever workspace is currently active (`dev`, `staging`, or `prod`) as the tag/name, without you passing it manually.

### Switching workspaces and applying

```bash
terraform workspace select dev
terraform apply
# creates: dev-ec2

terraform workspace select staging
terraform apply
# creates: staging-ec2 (separate state, doesn't touch dev-ec2)

terraform workspace select prod
terraform apply
# creates: prod-ec2 (separate state again)
```

Each workspace has its **own state file**, so `dev-ec2`, `staging-ec2`, and `prod-ec2` are tracked completely independently — but they all come from the **exact same `.tf` code**.

---

## When to Use Workspaces

Workspaces are genuinely useful for:

| Use case | Why it fits |
|---|---|
| **Personal/sandbox testing** | Quickly spin up a throwaway copy of infra to test a change, without writing a new folder |
| **Short-lived feature branches** | A temporary workspace per feature branch/PR that gets destroyed after testing |
| **Identical, low-risk environments** | Simple projects where dev/staging/prod truly only differ by name/size, nothing structural |
| **Learning/small personal projects** | Simple, low overhead — no need for a full folder-per-env structure |

---

## Why Most Production Teams Do NOT Use Workspaces for dev/staging/prod

### 1. Same code runs everywhere — no natural safety barrier
Because all workspaces share the same `.tf` files, a mistake or a bad `terraform apply` targeting the wrong workspace can happen with just **one wrong command**:
```bash
terraform workspace select prod   # meant to select "dev" — one typo, wrong environment
terraform apply
```
There's no folder boundary forcing you to consciously `cd` into a different, clearly-labeled directory — it's just an invisible "current workspace" state that's easy to forget or mistype.

### 2. Variables still need to differ per environment — and workspaces don't handle that well
Prod usually needs different instance sizes, different scaling, different feature flags. With workspaces, you end up writing conditional logic like:
```hcl
instance_type = terraform.workspace == "prod" ? "m5.large" : "t2.micro"
```
This gets messy fast as more values need to differ — real teams end up needing a separate `.tfvars` per environment anyway, which defeats much of the workspace simplicity benefit.

### 3. No separate access control per environment
With folder-per-environment, you can restrict IAM/CI permissions per **folder path** (e.g., only CI can write to `envs/prod/`). With workspaces, it's all one folder — much harder to enforce "only CI can apply to prod, developers can self-serve dev."

### 4. Blast radius risk
If your workspace-based code has a bug, applying it can affect **every workspace** the next time each one is applied — since they all share the same logic. Folder-per-environment isolates code changes better; you can test in `envs/dev/` thoroughly before ever touching `envs/prod/`.

### 5. Harder to review in Pull Requests
With separate folders, a PR diff clearly shows: "this change only touches `envs/dev/`." With workspaces, the diff shows a change to shared code — you can't as easily tell from the PR alone which environments are affected, since it depends on which workspace someone later selects.

### 6. State file naming/locking is less explicit
With folder-per-environment + S3 backend, your `key` paths are explicit (`prod/network/terraform.tfstate`). With workspaces, Terraform manages the state path for you automatically, which is convenient but gives you less direct visibility/control over exactly where and how each environment's state is stored.

---

## The Real-World Standard Instead: Folder-per-Environment

```text
envs/
├── dev/
│   ├── backend.tf
│   ├── main.tf
│   └── terraform.tfvars
├── staging/
│   ├── backend.tf
│   ├── main.tf
│   └── terraform.tfvars
└── prod/
    ├── backend.tf
    ├── main.tf
    └── terraform.tfvars
```

Each environment is a **separate directory** with its own backend `key`, its own `.tfvars`, and its own IAM permissions — you must deliberately `cd` into the right folder, making accidental cross-environment changes much harder. This is the pattern most companies use for dev/staging/prod, reserving **workspaces** for short-lived, low-risk, same-config scenarios like personal testing or feature-branch sandboxes.

---

## How to Run This Example

```bash
terraform init

terraform workspace new dev
terraform apply -var-file="terraform.tfvars"

terraform workspace new staging
terraform apply -var-file="terraform.tfvars"

terraform workspace new prod
terraform apply -var-file="terraform.tfvars"
```

Check what's running per workspace:
```bash
terraform workspace list
terraform workspace select dev
terraform state list
```

Clean up:
```bash
terraform workspace select dev
terraform destroy

terraform workspace select staging
terraform destroy

terraform workspace select prod
terraform destroy

terraform workspace select default
terraform workspace delete dev
terraform workspace delete staging
terraform workspace delete prod
```

---

## Interview Answer (Quick Reference)

> "A Terraform workspace lets you maintain multiple separate state files using the same configuration code — useful for quick, low-risk, identical environments like personal sandboxes or feature-branch testing. I generally avoid using workspaces for dev/staging/prod in production, though, because they share the same code with no folder-level separation — so it's easy to accidentally apply to the wrong environment with a typo, there's no clean way to enforce different IAM access per environment, and variables that need to differ per environment end up requiring messy conditional logic. Instead, for real dev/staging/prod setups, I use a folder-per-environment structure, where each environment has its own directory, its own backend state path, and its own `.tfvars` — this makes the boundary between environments explicit and reviewable in a PR, rather than relying on remembering which workspace is currently selected."

---

## Quick Reference Table

| | Workspaces | Folder-per-environment |
|---|---|---|
| Same code, multiple states | ✅ Yes | ❌ No (separate code per folder, though modules are shared) |
| Safe from typos/wrong-env applies | ❌ Risky | ✅ Safer (explicit `cd`) |
| Per-environment variables | ⚠️ Awkward (conditionals) | ✅ Clean (`.tfvars` per env) |
| Per-environment IAM/access control | ❌ Hard | ✅ Easy (scoped by folder path) |
| Best for | Sandboxes, feature branches, learning | Real dev/staging/prod in production |
