# Terraform Import - Import an Existing EC2 Instance into Terraform

This guide demonstrates how to import an **existing EC2 instance** (created manually from the AWS Console) into Terraform so that Terraform can manage it.

> **Repository**
>
> ```text
> terraform-aws/
> └── terraform-import/
>     ├── README.md
>     ├── versions.tf
>     ├── provider.tf
>     └── main.tf
> ```

---

# What is Terraform Import?

`terraform import` is used to bring **existing infrastructure** under Terraform management.

Imagine your company already has an EC2 instance that was created manually through the AWS Console. Terraform doesn't know about that resource because it only manages resources that are stored in its **state file**.

Without importing:

```text
AWS Console
      │
      ▼
EC2 Instance

Terraform
      │
      ▼
No knowledge of this EC2
```

After importing:

```text
AWS Console
      │
      ▼
EC2 Instance
      │
terraform import
      │
      ▼
Terraform State
      │
      ▼
Terraform can now manage the EC2
```

> **Important:** `terraform import` **does not generate Terraform code**. It only adds the existing resource to the Terraform state file. You are responsible for writing the Terraform configuration that matches the imported resource.

---

# Prerequisites

Before starting, make sure:

* Terraform is installed.
* AWS credentials are already configured.
* You have an EC2 instance created manually using the AWS Console.

---

# Step 1: Create an EC2 Instance

Create an EC2 instance manually from the AWS Console.

Recommended configuration:

| Setting        | Value                 |
| -------------- | --------------------- |
| Region         | ap-south-1            |
| AMI            | Amazon Linux 2023     |
| Instance Type  | t2.micro              |
| Name           | terraform-import-demo |
| Key Pair       | Existing Key Pair     |
| Security Group | Allow SSH (22)        |

After the instance is created, copy the **Instance ID**.
<img width="1667" height="204" alt="image" src="https://github.com/user-attachments/assets/ed310440-c219-4296-8f62-0a33f1a10113" />

Example:

```text
i-0ed95f9189bfdf014
```

---

# Step 2: Create the Project Structure

```text
terraform-import/
├── versions.tf
├── provider.tf
└── main.tf
```

---

# Step 3: Create versions.tf

```hcl
terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

---

# Step 4: Create provider.tf

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

---

# Step 5: Create main.tf

Initially, create only an empty resource block.

```hcl
resource "aws_instance" "my_ec2" {

}
```

At this point, Terraform knows the **resource name**, but it does **not** know which EC2 instance it should manage.

---

# Step 6: Initialize Terraform

```bash
terraform init
```

Expected output:

```text
Terraform has been successfully initialized!
```

---

# Step 7: Import the Existing EC2 Instance

Run the following command by replacing the instance ID with your own.

```bash
terraform import aws_instance.my_ec2 i-0ed95f9189bfdf014
```

Explanation:

* `aws_instance` → Terraform resource type
* `my_ec2` → Resource name in `main.tf`
* `i-0ed95f9189bfdf014` → Existing EC2 Instance ID

Expected output:

```text
Import successful!

Imported aws_instance.my_ec2
```
<img width="1195" height="213" alt="image" src="https://github.com/user-attachments/assets/28787b8e-71cd-4c45-98ee-17f8592a9d17" />

Terraform now records the mapping between your Terraform resource and the existing EC2 instance.


---

# Step 8: Verify the Import

List all resources managed by Terraform.

```bash
terraform state list
```
<img width="1243" height="91" alt="image" src="https://github.com/user-attachments/assets/c5210a51-8c83-48f8-a704-9fc84b39cd56" />

Expected output:

```text
aws_instance.my_ec2
```

---

# Step 9: View the Imported Resource

```bash
terraform state show aws_instance.my_ec2
```

Example output:

```text
id = i-0ed95f9189bfdf014:

ami = ami-0f5ee92e2d63afc18

instance_type = t2.micro

subnet_id = subnet-0123456789abc

availability_zone = ap-south-1a

private_ip = 172.31.1.100

public_ip = 13.xx.xx.xx

vpc_security_group_ids = [
  sg-0123456789abcdef0
]
```

This command displays the actual configuration of the imported EC2 instance stored in the Terraform state.

---

# Step 10: Update main.tf

Copy the important attributes from the previous step into your Terraform configuration.

Example:

```hcl
resource "aws_instance" "my_ec2" {
  ami               = "ami-0b6d9d3d33ba97d99"
  availability_zone = "us-east-1d"
  instance_type     = "t3.micro"
  key_name          = "praveeenuuuu"

  tags = {
    "Name" = "test"
  }

  vpc_security_group_ids = [
    "sg-088a9d0a2acd87acb",
  ]

}

```

Your Terraform configuration should match the actual EC2 configuration as closely as possible.

---

# Step 11: Verify There Is No Configuration Drift

Run:

```bash
terraform plan
```

If everything matches, Terraform should display:

```text
No changes.

Your infrastructure matches the configuration.
```
<img width="1205" height="166" alt="image" src="https://github.com/user-attachments/assets/53eb9d8e-b2f4-4774-a82b-f3587628e14a" />

This confirms Terraform is now managing the manually created EC2 instance successfully.

---

# Useful Commands

Initialize Terraform:

```bash
terraform init
```

Import an EC2 instance:

```bash
terraform import aws_instance.my_ec2 <INSTANCE_ID>
```

List imported resources:

```bash
terraform state list
```

Show imported resource details:

```bash
terraform state show aws_instance.my_ec2
```

Check for configuration drift:

```bash
terraform plan
```

Apply changes:

```bash
terraform apply
```

Destroy the imported EC2 (optional):

```bash
terraform destroy
```

> **Warning:** `terraform destroy` permanently deletes the imported EC2 instance from AWS.

---

# Key Takeaways

* `terraform import` is used to bring existing infrastructure under Terraform management.
* Import updates only the **Terraform state**; it does **not** create Terraform configuration.
* After importing, update your `.tf` files to match the existing resource.
* Run `terraform plan` until Terraform reports **No changes**.
* This workflow is commonly used when migrating manually created infrastructure to Infrastructure as Code.
