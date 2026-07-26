# Your First Terraform Project - Creating an EC2 Instance

Now that Terraform and AWS CLI are installed and authenticated (see the previous topics), let's create your **first real resource** — an EC2 instance — using Terraform.

> **Repository structure**
>
> ```text
> terraform-first-project/
> ├── README.md
> ├── provider.tf
> └── main.tf
> ```

---

## What We're Building

A single, simple EC2 instance in AWS — no VPC setup, no modules, no variables yet. Just the smallest possible working Terraform project, so you can see the full workflow end to end.

---

## Step 1: Create the Project Folder

```bash
mkdir terraform-first-project
cd terraform-first-project
```

---

## Step 2: Create `provider.tf`

The **provider** tells Terraform which cloud platform to talk to, and which region to create resources in.

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

---

## Step 3: Create `main.tf`

The **resource** block is where you describe the actual infrastructure you want.

```hcl
resource "aws_instance" "my_first_ec2" {
  ami           = "ami-0f5ee92e2d63afc18"   # Amazon Linux 2023, ap-south-1
  instance_type = "t2.micro"

  tags = {
    Name = "my-first-terraform-ec2"
  }
}
```

### Breaking this down

| Part | Meaning |
|---|---|
| `resource` | Keyword telling Terraform to create something |
| `"aws_instance"` | The resource type — an EC2 instance |
| `"my_first_ec2"` | A name YOU choose, used to refer to this resource inside your code |
| `ami` | Which OS image to launch (Amazon Linux 2023 here) |
| `instance_type` | The size/type of server (`t2.micro` = free-tier eligible) |
| `tags` | Labels attached to the resource — `Name` shows up in the AWS Console |

---

## Step 4: Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider plugin so Terraform knows how to talk to AWS.

Expected output:
```text
Terraform has been successfully initialized!
```

---

## Step 5: Preview What Will Be Created

```bash
terraform plan
```

Terraform reads your code and shows you **exactly what it's about to do**, without actually doing it yet:

```text
Terraform will perform the following actions:

  # aws_instance.my_first_ec2 will be created
  + resource "aws_instance" "my_first_ec2" {
      + ami           = "ami-0f5ee92e2d63afc18"
      + instance_type = "t2.micro"
      + tags          = {
          + "Name" = "my-first-terraform-ec2"
        }
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

This is your safety check before making real changes.

---

## Step 6: Create the Resource

```bash
terraform apply
```

Terraform shows the same plan again and asks for confirmation:
```text
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

Type `yes`. Terraform will now actually create the EC2 instance in your AWS account.

```text
aws_instance.my_first_ec2: Creating...
aws_instance.my_first_ec2: Still creating... [10s elapsed]
aws_instance.my_first_ec2: Creation complete after 15s [id=i-0abcdef1234567890]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

---

## Step 7: Verify in AWS

Go to the AWS Console → EC2 → Instances, and you should see:
```text
Name: my-first-terraform-ec2
Instance Type: t2.micro
State: running
```

Or verify via CLI:
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=my-first-terraform-ec2" \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,InstanceType]' \
  --output table
```

---

## Step 8: Clean Up (Optional)

When you're done experimenting, destroy the instance so you don't get charged:

```bash
terraform destroy
```

Confirm with `yes`. Terraform deletes exactly what it created — nothing more, nothing less.

---

## What Just Happened, Internally

```
You wrote main.tf + provider.tf
        │
        ▼
terraform init  →  downloads the AWS provider plugin
        │
        ▼
terraform plan  →  compares your code against current AWS state (nothing yet)
        │
        ▼
terraform apply →  Terraform → AWS Provider → AWS API → EC2 instance created
        │
        ▼
Terraform saves the result into terraform.tfstate
```

This `terraform.tfstate` file is how Terraform remembers what it created — covered in detail in the state management topics elsewhere in this repo.

---

## Quick Command Reference

| Command | Purpose |
|---|---|
| `terraform init` | Download provider plugins, set up the working directory |
| `terraform plan` | Preview changes without applying them |
| `terraform apply` | Create/update real infrastructure |
| `terraform destroy` | Delete everything Terraform created in this project |

---

## Next Steps

From here, the natural next topics to explore (also in this repo) are:
- **Variables** — avoid hardcoding values like `ami` and `instance_type`
- **Meta-arguments** (`count`, `for_each`) — create multiple instances
- **State** — understand `terraform.tfstate` in depth
- **Modules** — make this EC2 config reusable across environments

## Note on the AMI

The AMI ID here is an example and may become invalid over time or differ by account/region. Verify it's current before running:

```bash
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'Images | sort_by(@, &CreationDate)[-1].[ImageId,Name]' \
  --output table \
  --region ap-south-1
```
