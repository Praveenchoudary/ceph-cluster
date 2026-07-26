# Terraform Provisioners - EC2 + Install Nginx Example

This project explains **Terraform provisioners**, the different types available, and demonstrates all of them using a real EC2 instance that installs and configures nginx.

> **Repository structure**
>
> ```text
> terraform-provisioners/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── variables.tf
> ├── main.tf
> ├── outputs.tf
> └── nginx.conf
> ```

---

## What is a Provisioner?

A **provisioner** lets Terraform run scripts or commands **after a resource is created** (or before it's destroyed) — for example, installing software, copying config files, or running a setup script on a freshly created EC2 instance.

Terraform's normal job is to create/manage **infrastructure** (the EC2 instance itself). A provisioner steps outside that and lets you configure **what's running inside** that infrastructure — like installing nginx after the instance boots.

> **Important:** HashiCorp officially recommends provisioners as a **last resort**. Prefer baking software into a custom AMI (with Packer), using `user_data`, or a dedicated configuration tool (Ansible, Chef, Puppet) instead. Provisioners are useful to know and do show up in interviews and real legacy codebases, but modern setups increasingly avoid them in favor of these alternatives.

---

## Types of Provisioners

### 1. `remote-exec` — Run commands ON the resource itself

Connects to the resource (usually via SSH) and runs shell commands directly on it.

```hcl
provisioner "remote-exec" {
  inline = [
    "sudo yum install -y nginx",
    "sudo systemctl start nginx"
  ]
}
```

**Use it for:** installing packages, starting services, running setup scripts on the machine you just created.

---

### 2. `local-exec` — Run commands on YOUR machine (where Terraform is running)

Does **not** connect to the remote resource — it runs a command locally, on whatever machine is executing `terraform apply`.

```hcl
provisioner "local-exec" {
  command = "echo Instance ${self.id} is up >> instance_log.txt"
}
```

**Use it for:** logging, triggering a local notification/webhook, writing output to a local file, calling another local script after a resource is created.

---

### 3. `file` — Copy a file from your machine to the resource

Uploads a local file (or directory) onto the remote resource, so `remote-exec` can then use it.

```hcl
provisioner "file" {
  source      = "nginx.conf"
  destination = "/tmp/nginx.conf"
}
```

**Use it for:** pushing config files, scripts, or small assets onto a server before running setup commands against them.

---

## The `connection` Block (Required for `remote-exec` and `file`)

Since `remote-exec` and `file` need to reach into the resource, you must tell Terraform **how to connect** (SSH details):

```hcl
connection {
  type        = "ssh"
  user        = "ec2-user"
  private_key = file(var.private_key_path)
  host        = self.public_ip
}
```

- `self.public_ip` → refers to this same resource's own public IP (only valid inside a provisioner/connection block attached to that resource)
- `user` → depends on the AMI (`ec2-user` for Amazon Linux, `ubuntu` for Ubuntu AMIs)
- `private_key` → the matching `.pem` file for the EC2 key pair used

---

## Hands-On: EC2 + Install Nginx (All 3 Provisioner Types)

### `main.tf` (key parts)

```hcl
resource "aws_instance" "web" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_path)
    host        = self.public_ip
  }

  # file: copy a local nginx config onto the instance
  provisioner "file" {
    source      = "${path.module}/nginx.conf"
    destination = "/tmp/nginx.conf"
  }

  # remote-exec: install and configure nginx ON the instance
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo cp /tmp/nginx.conf /etc/nginx/conf.d/demo.conf",
      "sudo systemctl start nginx",
      "sudo systemctl enable nginx"
    ]
  }

  # local-exec: log the result on YOUR machine, not the EC2
  provisioner "local-exec" {
    command = "echo Instance ${self.id} is up with public IP ${self.public_ip} >> instance_log.txt"
  }
}
```

---

## Prerequisites Before Running

1. **An existing EC2 key pair** in your AWS account/region.
2. **The matching `.pem` private key file** downloaded locally.
3. Update `terraform.tfvars` (create one) with your values:

```hcl
key_name          = "my-demo-key"
private_key_path  = "/home/you/keys/my-demo-key.pem"
```

4. Make sure the `.pem` file has correct permissions:
```bash
chmod 400 /home/you/keys/my-demo-key.pem
```

---

## How to Run

```bash
terraform init
terraform plan
terraform apply
```

Terraform will:
1. Create a security group allowing SSH (22) and HTTP (80)
2. Launch the EC2 instance
3. **Copy** `nginx.conf` onto the instance (`file` provisioner)
4. **SSH in and run commands** to install + configure + start nginx (`remote-exec` provisioner)
5. **Log locally** on your own machine that the instance is up (`local-exec` provisioner)

### Verify nginx is running
```bash
terraform output nginx_url
curl $(terraform output -raw nginx_url)
```
Expected response:
```text
Hello from Terraform provisioner demo!
```

### Check the local log file
```bash
cat instance_log.txt
```
```text
Instance i-0abc123xyz is up with public IP 3.109.211.90
```

---

## Clean Up

```bash
terraform destroy
```

---

## Quick Reference Table

| Provisioner | Runs where | Common use |
|---|---|---|
| `remote-exec` | On the resource itself (via SSH/WinRM) | Install packages, start services |
| `local-exec` | On the machine running Terraform | Logging, local scripts, webhooks |
| `file` | Copies from local machine → resource | Push config files/scripts before running remote-exec |

---

## When (Not) to Use Provisioners

| Use provisioners when | Prefer alternatives when |
|---|---|
| Quick demo/lab setups | Production workloads |
| No other tooling available | You already use Ansible/Chef/Puppet |
| One-off, simple bootstrap commands | Complex, repeatable configuration management |
| Learning/interview prep | Building golden AMIs is possible (via Packer + `user_data`) |

Most production teams prefer **baking a custom AMI** (with the software pre-installed via Packer) or using **`user_data`** for simple bootstrap scripts, since provisioners depend on network connectivity at apply time and can make `apply` fail or hang if SSH isn't reachable — something baked-in AMIs and `user_data` don't suffer from.

---

## Interview Answer (Quick Reference)

> "A provisioner lets Terraform run commands after a resource is created — for example, installing nginx on a fresh EC2 instance. There are three main types: `remote-exec`, which runs commands directly on the resource over SSH; `local-exec`, which runs a command on the machine running Terraform itself, not the resource; and `file`, which copies a local file onto the resource before running commands against it. Provisioners need a `connection` block to know how to SSH in. That said, HashiCorp recommends provisioners as a last resort — in real production setups, I'd rather bake software into a custom AMI or use `user_data` for simple bootstrap scripts, since provisioners depend on live network connectivity during apply and can make the apply fail or hang if SSH isn't reachable."
