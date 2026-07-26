# Terraform CI/CD with Jenkins

This project demonstrates a complete **Jenkins pipeline** for running Terraform — with plan/apply/destroy actions, environment selection, and manual approval before touching production.

> **Repository structure**
>
> ```text
> terraform-cicd-jenkins/
> ├── README.md
> ├── Jenkinsfile
> └── terraform/
>     ├── versions.tf
>     ├── provider.tf
>     ├── variables.tf
>     ├── main.tf
>     └── outputs.tf
> ```

---

## Why Run Terraform Through Jenkins Instead of Manually?

| Manual (from a laptop) | Through Jenkins |
|---|---|
| Anyone can run `apply` any time | Only the pipeline (with proper credentials) can apply |
| No review before changes go live | `plan` output is visible before `apply` runs |
| Easy to forget `terraform fmt`/`validate` | Pipeline enforces these checks every time |
| No approval gate for prod | Manual approval step required before prod apply |
| No audit trail of who ran what | Jenkins build history shows every run, params, and output |

---

## Prerequisites

1. **Jenkins installed** with these plugins:
   - Pipeline
   - AWS Credentials
   - Terraform (optional, for syntax highlighting — not required to run `sh` commands)
2. **AWS credentials stored in Jenkins Credentials Manager**, one per environment:
   - `aws-dev-ci`
   - `aws-prod-ci`
   (Manage Jenkins → Credentials → Add Credentials → AWS Credentials, using an IAM user/role scoped to that environment)
3. **Terraform CLI installed on the Jenkins agent** (the machine actually running the pipeline steps).
4. An existing **S3 bucket + DynamoDB table** for remote state (see the `terraform-remote-backend-full` guide if not set up yet). Update the `bucket` value in `terraform/versions.tf` to match yours.

---

## The Jenkins Pipeline (`Jenkinsfile`)

### Parameters
```groovy
parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Select environment')
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action to run')
}
```
When you trigger a build, Jenkins shows a dropdown to pick the environment and the action — no need for separate pipelines per environment.

### Stage-by-stage breakdown

| Stage | What it does |
|---|---|
| **Checkout** | Pulls the latest code from your Git repo |
| **AWS Credentials Check** | Verifies the pipeline can authenticate to AWS (`aws sts get-caller-identity`) |
| **Terraform Init** | Downloads providers, connects to the S3 backend |
| **Terraform Format Check** | Fails the build if code isn't formatted (`terraform fmt -check`) |
| **Terraform Validate** | Catches syntax errors before planning |
| **Terraform Plan** | Generates and saves a plan file (`tfplan`) |
| **Manual Approval** | **Only runs if environment = prod AND action = apply** — pipeline pauses here |
| **Terraform Apply** | Applies the exact plan saved earlier — only runs if action = apply |
| **Terraform Destroy** | Runs `terraform destroy`, with its own confirmation prompt — only if action = destroy |

### Manual approval gate (the key safety feature)
```groovy
stage('Manual Approval') {
    when {
        allOf {
            expression { params.ACTION == 'apply' }
            expression { params.ENVIRONMENT == 'prod' }
        }
    }
    steps {
        input message: "Approve Terraform APPLY on PROD?", ok: "Apply"
    }
}
```
This stage **pauses the pipeline** and waits for a human to click "Apply" in the Jenkins UI — but only when targeting prod. Dev applies go straight through without waiting.

### Applying the exact plan that was reviewed
```groovy
sh 'terraform apply -input=false tfplan'
```
Notice it applies the **saved plan file** (`tfplan`), not a fresh plan — this guarantees whatever a human approved is exactly what gets applied, with zero chance of drift between the review and the actual apply.

---

## How to Set This Up in Jenkins

### Step 1: Create a new Pipeline job
- Jenkins Dashboard → New Item → Pipeline → name it `terraform-cicd-demo`

### Step 2: Point it at your repo
- Pipeline section → Definition: **Pipeline script from SCM**
- SCM: **Git**
- Repository URL: your `terraform-aws` repo URL
- Script Path: `terraform-cicd-jenkins/Jenkinsfile`

### Step 3: Add AWS credentials
- Manage Jenkins → Credentials → System → Global credentials → Add Credentials
- Kind: **AWS Credentials**
- ID: `aws-dev-ci` (and separately `aws-prod-ci`)
- Fill in Access Key ID / Secret Access Key for an IAM user/role scoped to that environment

### Step 4: Run the pipeline
- Click **Build with Parameters**
- Choose `ENVIRONMENT = dev`, `ACTION = plan` → run it first to verify everything works
- Then try `ENVIRONMENT = dev`, `ACTION = apply`
- Then try `ENVIRONMENT = prod`, `ACTION = apply` — you'll see the pipeline pause at **Manual Approval**, waiting for you to click "Apply" in the Jenkins UI

---

## Files in This Project

### `terraform/versions.tf` (includes the remote backend)
```hcl
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state-prod"
    key            = "prod/jenkins-demo/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### `terraform/main.tf`
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18"
  instance_type = var.instance_type

  tags = {
    Name        = "${var.environment}-jenkins-demo"
    Environment = var.environment
    ManagedBy   = "jenkins-pipeline"
  }
}
```

---

## What Happens Internally (End to End)

```
Developer clicks "Build with Parameters"
        │
        ▼
Jenkins checks out code
        │
        ▼
Jenkins authenticates to AWS using stored credentials
        │
        ▼
terraform init  →  connects to S3 backend
        │
        ▼
terraform fmt -check + terraform validate
        │
        ▼
terraform plan  →  saved as tfplan artifact
        │
        ▼
  [If prod + apply]  →  Pipeline PAUSES, waits for human approval
        │
        ▼
terraform apply tfplan  →  AWS creates/updates real infrastructure
        │
        ▼
Plan file archived as a build artifact for audit history
```

---

## Interview Answer (Quick Reference)

> "I run Terraform through a Jenkins pipeline instead of manually from a laptop, so every change goes through the same repeatable process: checkout, format check, validate, plan, and only then apply. The pipeline takes `ENVIRONMENT` and `ACTION` as parameters, so one Jenkinsfile handles dev and prod instead of duplicating pipelines. For prod applies specifically, there's a manual approval stage that pauses the pipeline and requires a human to click approve in the Jenkins UI before anything actually changes — and it applies the exact plan file that was reviewed, not a fresh plan, so there's no drift between what was approved and what gets applied. AWS credentials are stored in Jenkins' credentials manager per environment, scoped with least privilege, rather than using long-lived keys on anyone's machine."

---

## Note on the AMI

The AMI ID in `main.tf` is an example and may become invalid over time. Verify it's current for your region before running:

```bash
aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" \
  --query 'Images | sort_by(@, &CreationDate)[-1].[ImageId,Name]' \
  --output table \
  --region ap-south-1
```
