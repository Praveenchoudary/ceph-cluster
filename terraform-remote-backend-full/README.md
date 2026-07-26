# Terraform Remote State & Backends

This project covers everything needed to understand and set up a **production-ready remote backend** for Terraform — including creating the S3 bucket and DynamoDB table yourself.

> **Repository structure**
>
> ```text
> terraform-remote-backend-full/
> ├── README.md
> ├── bootstrap/          ← creates the S3 bucket + DynamoDB table (run once, local state)
> │   ├── versions.tf
> │   ├── provider.tf
> │   ├── variables.tf
> │   ├── main.tf
> │   └── outputs.tf
> └── app/                ← your real infrastructure, using the bucket as its backend
>     ├── versions.tf
>     ├── backend.tf
>     ├── provider.tf
>     ├── main.tf
>     └── outputs.tf
> ```

---

## 1. What is a Backend?

A **backend** determines **where Terraform stores its state file** and **how operations (plan/apply) are executed**.

By default, Terraform uses the **local backend** — state is saved as a plain JSON file on your machine:
```text
./terraform.tfstate
```

A **remote backend** stores that same state file somewhere centralized instead — like AWS S3 — so a whole team can share one consistent source of truth instead of everyone having their own local copy.

```hcl
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state-prod"
    key            = "prod/app/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

---

## 2. Why Teams Store State in S3

| Problem with local state | How S3 solves it |
|---|---|
| State file only exists on one person's laptop | S3 is centrally accessible to the whole team / CI pipeline |
| No backup if the laptop is lost or the file is deleted | S3 **versioning** keeps every historical version of the state file |
| Plaintext secrets sitting on a local machine | S3 **encryption at rest** protects sensitive data in state |
| No audit trail of who changed what | S3 access logs + versioning show a history of changes |
| Can't run Terraform from CI/CD easily | A pipeline can read/write the same shared state over HTTPS |

S3 also has 99.999999999% durability, making it very unlikely you'll ever lose your state file, as long as versioning is enabled.

---

## 3. Why DynamoDB (or Another Locking Mechanism) is Needed

S3 by itself has **no locking mechanism** — it can't stop two people from writing to the same file at the same time. DynamoDB provides that missing piece: **state locking**.

When Terraform starts an `apply`, it writes a **lock record** into DynamoDB (keyed by the state file's path). Any other `apply` attempting to touch the *same* state file has to **wait** until the lock is released.

```hcl
dynamodb_table = "terraform-locks"
```

DynamoDB is used because it's:
- Extremely fast for simple key lookups (perfect for a lock check)
- Cheap — `PAY_PER_REQUEST` billing means you pay pennies for this
- Fully managed — no server to maintain

> Note: Newer versions of the S3 backend (Terraform 1.10+) can also do native S3 locking without DynamoDB, but DynamoDB-based locking remains the most common, widely-supported pattern in real production setups.

---

## 4. What Happens When Two Engineers Run `terraform apply` at the Same Time

**Without locking (no DynamoDB):**
```text
Engineer A: reads state → starts creating resources → writes new state
Engineer B: reads the SAME old state → starts creating resources → OVERWRITES A's changes
```
Result: **state corruption** — Terraform's record no longer matches what's actually in AWS. Some resources become "orphaned" (exist in AWS but not in state), and future applies behave unpredictably.

**With locking (DynamoDB enabled):**
```text
Engineer A: terraform apply
   → acquires lock in DynamoDB (LockID = state file path)
   → makes changes
   → writes new state to S3
   → releases lock

Engineer B: terraform apply (at the same time)
   → tries to acquire the SAME lock
   → sees it's already held
   → gets blocked with an error:

Error: Error acquiring the state lock

Lock Info:
  ID:        d1b3f9e2-xxxx
  Path:      mycompany-terraform-state-prod/prod/app/terraform.tfstate
  Operation: OperationTypeApply
  Who:       alice@her-laptop
  Created:   2026-07-21 10:15:32 UTC
```
Engineer B simply waits and retries once Engineer A's apply finishes — **no corruption, no overwritten changes.**

If a lock ever gets stuck (e.g. a CI job crashed mid-apply), it can be manually released:
```bash
terraform force-unlock <LOCK_ID>
```
⚠️ Only do this if you're certain no other apply is genuinely still running.

---

## 5. How to Configure a Production-Ready Remote Backend (Step by Step)

### Step 1: Create the S3 bucket + DynamoDB table (the `bootstrap/` project)

This is a **separate, one-time project** — it can't create the bucket and use that same bucket as its own backend in one step (chicken-and-egg problem). This project uses **local state** and is typically run once by a platform/DevOps admin.

**`bootstrap/main.tf`**
```hcl
resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
```

Run it:
```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

This creates:
- An **S3 bucket** with versioning, encryption, and public access fully blocked
- A **DynamoDB table** (`terraform-locks`) with `LockID` as its primary key

`prevent_destroy = true` on both resources stops anyone from accidentally running `terraform destroy` and wiping out the state infrastructure itself.

---

### Step 2: Point your real project's backend at the bucket you just created (the `app/` project)

**`app/backend.tf`**
```hcl
terraform {
  backend "s3" {
    bucket         = "mycompany-terraform-state-prod"   # must match bootstrap's output
    key            = "prod/app/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"                  # must match bootstrap's output
    encrypt        = true
  }
}
```

Run it:
```bash
cd ../app
terraform init
```
Terraform connects to the S3 bucket and DynamoDB table from Step 1.

```bash
terraform plan
terraform apply
```

This creates a simple EC2 instance, with its state now safely stored in S3 with locking enabled.

---

### Step 3: Verify state landed in S3

```bash
aws s3 ls s3://mycompany-terraform-state-prod/prod/app/
```
You should see `terraform.tfstate` sitting there.

### Step 4: Verify locking works

Run `terraform apply` in one terminal, and quickly run it again in a second terminal before the first finishes — the second one should show the "Error acquiring the state lock" message described in section 4.

---

## Production Best Practices Recap

| Practice | Why |
|---|---|
| `prevent_destroy = true` on the state bucket/table | Prevents accidental deletion of critical infrastructure |
| S3 **versioning** enabled | Recover previous state versions if corrupted |
| S3 **encryption** enabled | Protects secrets that may live inside state |
| S3 **public access fully blocked** | State should never be publicly readable |
| Separate `key` per project/environment | Limits blast radius — one project's mistake doesn't touch another's state |
| DynamoDB locking always enabled | Prevents concurrent applies from corrupting state |
| Bootstrap run separately, rarely touched | Keeps the "foundation" stable while day-to-day projects change often |

---

## Interview Answer (Quick Reference)

> "A backend determines where Terraform stores its state — locally by default, or remotely for teams. We store state in S3 because it's centrally accessible, durable, versioned so we can recover from corruption, and encrypted at rest since state can contain sensitive data. S3 alone has no locking though, so we pair it with DynamoDB, which stores a lock record for the state file path during every apply. If two engineers run apply at the same time without locking, the second one can overwrite the first one's changes and corrupt state; with DynamoDB locking, the second apply is blocked with a clear error until the first one finishes. To set this up in production, I first run a one-time bootstrap project — using local state — that creates the S3 bucket with versioning and encryption, plus the DynamoDB table. Then every real project points its backend block at that bucket and table, each with its own unique `key` path so state stays isolated per project or environment."
