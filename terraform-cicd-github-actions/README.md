# Terraform CI/CD with GitHub Actions

This project demonstrates running Terraform through **GitHub Actions** — separate dev and prod workflows, PR plan comments, a manual approval gate before prod applies, and a scheduled drift-detection job.

> **Repository structure**
>
> ```text
> terraform-cicd-github-actions/
> ├── README.md
> ├── .github/
> │   └── workflows/
> │       ├── terraform-dev.yml
> │       ├── terraform-prod.yml
> │       └── drift-check.yml
> └── terraform/
>     ├── versions.tf
>     ├── provider.tf
>     ├── variables.tf
>     ├── main.tf
>     └── outputs.tf
> ```

---

## Why GitHub Actions for Terraform?

| Manual (from a laptop) | GitHub Actions |
|---|---|
| Anyone can `apply` any time | Only the pipeline, using OIDC-scoped roles, can apply |
| No review before changes go live | Plan output posted as a PR comment automatically |
| Easy to skip `fmt`/`validate` | Every run enforces format check + validation |
| No approval gate for prod | GitHub **Environments** provide a native manual approval step |
| Credentials often long-lived on a laptop | OIDC federation — no stored AWS access keys at all |

---

## Prerequisites

1. **An IAM OIDC identity provider** trusting GitHub Actions, plus IAM roles the workflows can assume (`terraform-dev-ci`, `terraform-prod-ci`).
2. **An existing S3 bucket + DynamoDB table** for remote state (see the `terraform-remote-backend-full` guide). Update `bucket` in `terraform/versions.tf` to match yours.
3. **A GitHub Environment** named `prod-approval` with required reviewers configured (Settings → Environments → New environment → Required reviewers).
4. (Optional) A `SLACK_WEBHOOK_URL` repo secret, for drift alerts.

---

## Workflow 1: `terraform-dev.yml` — Auto-Apply on Merge

Triggers on any PR or push touching `terraform/**`.

```yaml
on:
  pull_request:
    branches: [main]
    paths: ["terraform/**"]
  push:
    branches: [main]
    paths: ["terraform/**"]
```

**On a Pull Request:**
1. `terraform init`, `fmt -check`, `validate`
2. `terraform plan` — result posted as a **PR comment** for review

**On merge to `main`:**
3. `terraform apply` runs automatically — no approval needed for dev

```yaml
- name: Terraform Apply
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  run: terraform apply -auto-approve tfplan
```

---

## Workflow 2: `terraform-prod.yml` — Plan → Manual Approval → Apply

This one is split into **two jobs**: `plan` and `apply`.

### `plan` job
- Runs `terraform plan`, posts it as a PR comment
- On merge to `main`, uploads the plan as a build **artifact** (not applied yet)

### `apply` job
```yaml
apply:
  needs: plan
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'
  environment: prod-approval   # <-- this line is what pauses the pipeline
```
Because this job targets the `prod-approval` **GitHub Environment**, and that environment has **required reviewers** configured, the job **pauses** and waits for someone to click "Approve and deploy" in the GitHub Actions UI before running.

```yaml
- name: Download plan artifact
  uses: actions/download-artifact@v4
  with:
    name: tfplan-prod

- name: Terraform Apply
  run: terraform apply -auto-approve tfplan
```
It applies the **exact plan file** generated and reviewed earlier — never a fresh plan — so there's zero drift between what was reviewed and what actually gets applied.

---

## Workflow 3: `drift-check.yml` — Scheduled Drift Detection

```yaml
on:
  schedule:
    - cron: '0 2 * * *'   # every day at 2 AM UTC
  workflow_dispatch:
```

Runs `terraform plan -detailed-exitcode` daily:
- Exit code `0` → no drift, nothing happens
- Exit code `2` → drift detected → posts a Slack alert

```yaml
- name: Notify if drift detected
  if: steps.drift.outputs.exitcode == '2'
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"Drift detected in prod!"}' \
      ${{ secrets.SLACK_WEBHOOK_URL }}
```

This catches cases where someone manually changed something in the AWS Console outside of Terraform.

---

## Setting Up the OIDC Role (Instead of Storing AWS Keys)

Rather than storing long-lived `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` as GitHub secrets, use **OIDC federation** — GitHub issues a short-lived token that AWS trusts directly.

### 1. Create the OIDC identity provider in AWS (one-time, per AWS account)
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create an IAM role with a trust policy scoped to your repo
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/terraform-aws:*"
        }
      }
    }
  ]
}
```
Repeat this for both `terraform-dev-ci` and `terraform-prod-ci` roles, attaching appropriately scoped permissions to each (dev role gets broader dev permissions; prod role is tightly scoped and often requires additional approval logic).

### 3. Reference the role in the workflow
```yaml
permissions:
  id-token: write   # required for OIDC
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/terraform-dev-ci
      aws-region: ap-south-1
```

---

## How to Set Up the Manual Approval Gate

1. Go to your repo → **Settings → Environments → New environment**
2. Name it `prod-approval`
3. Under **Deployment protection rules**, check **Required reviewers** and add yourself/your team
4. Save

Now any job in a workflow referencing `environment: prod-approval` will pause and wait for one of those reviewers to approve before continuing.

---

## Files in This Project

### `terraform/versions.tf`
```hcl
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state-prod"
    key            = "prod/github-actions-demo/terraform.tfstate"
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
    Name        = "${var.environment}-github-actions-demo"
    Environment = var.environment
    ManagedBy   = "github-actions"
  }
}
```

---

## What Happens Internally (End to End, Prod Flow)

```
Developer opens PR touching terraform/**
        │
        ▼
GitHub Actions: init, fmt check, validate, plan
        │
        ▼
Plan posted as PR comment for review
        │
        ▼
PR approved and merged to main
        │
        ▼
plan job runs again, uploads plan as artifact
        │
        ▼
apply job requests approval (prod-approval environment)
        │
        ▼
Reviewer clicks "Approve and deploy" in GitHub UI
        │
        ▼
apply job downloads the SAME plan artifact and applies it
        │
        ▼
AWS creates/updates real infrastructure
```

---

## Interview Answer (Quick Reference)

> "I run Terraform through GitHub Actions using OIDC federation instead of storing long-lived AWS keys as secrets — GitHub issues a short-lived token that an IAM role trusts directly, scoped to my specific repo. Every PR triggers init, format check, validate, and plan, with the plan posted as a PR comment for review. On merge, dev applies automatically, but prod goes through a separate job tied to a GitHub Environment with required reviewers — so the pipeline pauses and waits for a human to click approve before running. Critically, the apply step downloads and applies the exact plan artifact generated earlier, not a fresh plan, so there's no drift between what was reviewed and what's actually applied. I also run a scheduled workflow daily that does a plan-only run with `-detailed-exitcode` to catch manual changes made outside Terraform, and alerts the team via Slack if drift is detected."
