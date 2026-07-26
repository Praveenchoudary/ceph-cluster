# What is Terraform?

Terraform is an **Infrastructure as Code (IaC)** tool developed by **HashiCorp**.

It allows you to create, update, and delete infrastructure using code. Instead of creating resources manually in the AWS Console, you write code, and Terraform creates the resources for you.

---

## Simple Definition

> Terraform is a tool that automates infrastructure creation.

---

## Real-Life Example

Imagine you are building a house.

**Without a Machine**
- Workers carry bricks manually.
- It takes more time.

**With a Machine**
- A machine helps move bricks quickly.
- It saves time and reduces effort.

Terraform is like that machine. It automates infrastructure creation.

---

## What Can Terraform Create?

Terraform can create many AWS resources.

| Resource | AWS Service |
|---|---|
| Server | EC2 |
| Network | VPC |
| Storage | S3 |
| Database | RDS |
| Firewall | Security Group |
| Load Balancer | ALB |
| DNS | Route 53 |
| IAM | Users, Roles, Policies |

---

## Does Terraform Work Only with AWS?

**No.** Terraform supports many platforms.

Examples:
- AWS
- Azure
- Google Cloud (GCP)
- Kubernetes
- VMware
- GitHub
- Cloudflare

This is why Terraform is called a **multi-cloud tool**.

---

## Does Terraform Create Servers?

**No.** Terraform does not create servers itself.

- Terraform sends a request to AWS.
- AWS creates the server.

Think of Terraform as a **manager**. AWS is the **worker**.

---

## Understanding the Architecture

### 1. Terraform Code
You write the infrastructure configuration.
Example: EC2, VPC, S3

### 2. Terraform CLI
The Terraform command-line tool reads your code.
Example commands: `terraform init`, `terraform plan`, `terraform apply`

### 3. AWS Provider
The provider acts as a translator. Terraform speaks to the provider. The provider understands AWS.

### 4. AWS API
AWS receives the request. AWS creates the resources.

### 5. Infrastructure
Your resources are created.
Examples: EC2, VPC, RDS, S3

---

## Terraform Workflow

Terraform mainly follows four steps.

```
Write Code
     │
     ▼
terraform init
     │
     ▼
terraform plan
     │
     ▼
terraform apply
```

Later, if you no longer need the resources:
```
terraform destroy
```

---

## What Happens Internally?

**Step 1**
You write Terraform code.
```
     │
     ▼
```
**Step 2**
Terraform reads the code.
```
     │
     ▼
```
**Step 3**
Terraform contacts AWS.
```
     │
     ▼
```
**Step 4**
AWS creates the resources.
```
     │
     ▼
```
**Step 5**
Terraform saves the resource information (state file).

---

## Why Do Companies Use Terraform?

Companies use Terraform because it:

- Automates infrastructure
- Saves time
- Reduces manual work
- Creates consistent environments
- Supports version control with Git
- Works with multiple cloud providers
