# AWS Account Setup & Authentication

## Why Do We Need Authentication?

Terraform needs permission to create AWS resources.

To give permission, we use an **IAM User** with an **Access Key** and **Secret Access Key**.

---

## Step 1: Create an IAM User

1. Sign in to the AWS Console.
2. Open **IAM**.
3. Click **Users**.
4. Click **Create User**.
5. Enter a user name (Example: `terraform-user`).
6. Click **Next**.

---

## Step 2: Assign Permissions

For learning, attach the policy:

```
AdministratorAccess
```

> **Note:** Use `AdministratorAccess` only for learning or testing. In production, grant only the required permissions (least privilege).

---

## Step 3: Create Access Keys

1. Open the IAM User.
2. Go to the **Security credentials** tab.
3. Click **Create access key**.
4. Select **Command Line Interface (CLI)**.
5. Download or copy:
   - Access Key ID
   - Secret Access Key

> Save the Secret Access Key securely. You won't be able to see it again after leaving the page.

---

## Step 4: Configure AWS CLI

Run:
```bash
aws configure
```

Enter the details:
```text
AWS Access Key ID: AKIAxxxxxxxxxxxx
AWS Secret Access Key: xxxxxxxxxxxxxxxxx
Default region name: us-east-1
Default output format: json
```

---

## Step 5: Test the Connection

Run:
```bash
aws sts get-caller-identity
```

If you see your **Account** and **User ARN**, your AWS CLI is configured successfully.

Example output:
```json
{
    "UserId": "AIDAEXAMPLE123456",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-user"
}
```

---

## Next Step

Your AWS CLI is now authenticated, and Terraform will automatically use these same credentials (via the AWS provider) to create resources. You're ready to write your first Terraform configuration.
