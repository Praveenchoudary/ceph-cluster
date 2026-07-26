# What is Infrastructure as Code (IaC)?

## Before IaC

Suppose you need to create a new server in AWS. Without Terraform, you would:

1. Login to AWS Console
2. Open EC2
3. Click Launch Instance
4. Select AMI
5. Select Instance Type
6. Configure Network
7. Create Security Group
8. Click Launch

Now imagine creating:
- 50 Servers
- 20 Databases
- 10 Load Balancers

Doing everything manually takes a lot of time.

---

## What is Infrastructure as Code (IaC)?

**Infrastructure as Code (IaC)** means creating and managing infrastructure using code instead of manually clicking in the cloud console.

Instead of clicking buttons, you write a configuration file. The tool reads the file and creates the infrastructure automatically.

---

## Simple Example

**Manual Method**
```
AWS Console
     │
     ▼
   Click
     │
     ▼
   Click
     │
     ▼
   Click
     │
     ▼
Server Created
```

**IaC Method**
```
Write Code
     │
     ▼
Run Command
     │
     ▼
Server Created
```

---

## Real-Life Example

Imagine you want to build 100 identical houses.

**Manual Method**
- Build each house separately.
- Takes more time
- Mistakes are possible

**Blueprint Method**
- Create one blueprint.
- Use the same blueprint to build all 100 houses.
- Fast and consistent.

Terraform is like the blueprint for your infrastructure.

---

## Manual vs IaC

| Manual | Infrastructure as Code |
|---|---|
| Click in Console | Write Code |
| Slow | Fast |
| Easy to make mistakes | Consistent |
| Hard to repeat | Easy to repeat |
| No version history | Can be stored in Git |

---

## Example

**Without IaC:**
```
Engineer
   │
   ▼
AWS Console
   │
   ▼
Create EC2
   │
   ▼
Create VPC
   │
   ▼
Create Database
```

**With IaC:**
```
Engineer
   │
   ▼
Terraform Code
   │
   ▼
terraform apply
   │
   ▼
AWS Creates Everything
```

---

## Why Companies Use IaC

Imagine your company has:
- Development Environment
- Testing Environment
- Production Environment

All environments should be the same. Instead of creating each one manually, companies use IaC to create identical environments every time.

---

## Benefits of IaC

✅ **Automation** — No manual clicking.

✅ **Faster Deployment** — Create infrastructure in minutes.

✅ **Consistency** — Every environment is the same.

✅ **Version Control** — Infrastructure code can be stored in Git.

✅ **Easy Recovery** — If infrastructure is deleted accidentally, it can be recreated using the same code.

---

## Real-World Example

Suppose your company needs:
- 10 EC2 Instances
- 1 VPC
- 2 Databases
- 5 Security Groups

**Without IaC:** You create each resource manually.

**With IaC:** You write the configuration once and Terraform creates everything automatically.

---

## Summary

- Infrastructure as Code (IaC) means managing infrastructure using code.
- IaC replaces manual configuration with automation.
- Terraform is one of the most popular IaC tools.
- IaC makes infrastructure faster, repeatable, and easier to manage.

---

## Key Terms

| Term | Meaning |
|---|---|
| Infrastructure | Resources required to run an application |
| IaC | Managing infrastructure using code |
| Manual Provisioning | Creating resources through the cloud console |
| Automation | Creating resources automatically using code |
| Terraform | An Infrastructure as Code tool |
