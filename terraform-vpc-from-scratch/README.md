# Terraform VPC From Scratch - Public + Private Subnets, IGW, NAT Gateway

This project builds a complete, real-world **VPC** from the ground up — public subnets, private subnets, an Internet Gateway, a NAT Gateway, and the route tables that tie it all together — with one EC2 instance in each subnet type.

> **Repository structure**
>
> ```text
> terraform-vpc-from-scratch/
> ├── README.md
> ├── versions.tf
> ├── provider.tf
> ├── variables.tf
> ├── vpc.tf
> ├── main.tf
> └── outputs.tf
> ```

---

## The Big Picture

```text
                         Internet
                             │
                             │
                   ┌─────────▼─────────┐
                   │ Internet Gateway   │
                   └─────────┬─────────┘
                             │
                     ┌───────┴────────┐
                     │  Public Route  │  0.0.0.0/0 -> IGW
                     │     Table      │
                     └───────┬────────┘
                             │
              ┌──────────────┴───────────────┐
              │                              │
       ┌──────▼──────┐               ┌───────▼──────┐
       │Public Subnet │               │Public Subnet │
       │ 10.0.1.0/24  │               │ 10.0.2.0/24  │
       │  [EC2 web]   │               │              │
       │  [NAT GW]    │               │              │
       └──────┬───────┘               └──────────────┘
              │
      ┌───────┴────────┐
      │ Private Route  │  0.0.0.0/0 -> NAT Gateway
      │     Table      │
      └───────┬────────┘
              │
      ┌───────▼───────┐              ┌───────────────┐
      │Private Subnet │              │Private Subnet │
      │10.0.11.0/24   │              │10.0.12.0/24   │
      │ [EC2 app]     │              │               │
      └───────────────┘              └───────────────┘
```

---

## Core Concepts

### VPC (Virtual Private Cloud)
An isolated, private network inside AWS — your own slice of the cloud, with its own IP address range (CIDR block).
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```
`10.0.0.0/16` gives you 65,536 IP addresses to divide up into subnets.

---

### Subnets — Public vs Private

A **subnet** is a smaller slice of the VPC's IP range, tied to a specific Availability Zone.

| | Public Subnet | Private Subnet |
|---|---|---|
| Gets a public IP? | Yes (`map_public_ip_on_launch = true`) | No |
| Reachable directly from internet? | Yes (if security group allows) | No |
| Outbound internet access? | Yes, via Internet Gateway | Yes, but only via NAT Gateway |
| Typical use | Load balancers, bastion hosts, public web servers | App servers, databases — anything that shouldn't be directly exposed |

```hcl
resource "aws_subnet" "public" {
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  cidr_block = "10.0.11.0/24"
  # no map_public_ip_on_launch - stays private
}
```

---

### Internet Gateway (IGW)

The door between your VPC and the public internet. Without it, nothing in your VPC — public or private — can reach the internet at all.

```hcl
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}
```

---

### NAT Gateway

Lets **private** subnets reach the internet **outbound only** (e.g., to download OS updates or call an external API) — without allowing anything from the internet to initiate a connection **into** the private subnet.

```hcl
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # NAT Gateway itself lives in a PUBLIC subnet
}
```

**Why does the NAT Gateway sit in a public subnet, even though it serves private subnets?** Because the NAT Gateway itself needs a path to the internet (via the IGW) to forward traffic on behalf of private instances. It acts as a middleman: private instance → NAT Gateway (in public subnet) → Internet Gateway → internet.

---

### Route Tables

A **route table** is the actual set of rules deciding where traffic goes based on destination IP. Every subnet must be associated with one.

**Public route table** — sends all outbound traffic (`0.0.0.0/0`) to the Internet Gateway:
```hcl
resource "aws_route_table" "public" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
```

**Private route table** — sends all outbound traffic to the NAT Gateway instead:
```hcl
resource "aws_route_table" "private" {
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}
```

Each subnet is then explicitly **associated** with the matching route table:
```hcl
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public.id
}
```

This association is what actually makes a subnet "public" or "private" in practice — the CIDR block and `map_public_ip_on_launch` matter, but it's the **route table** that determines whether traffic can actually reach the internet directly or only through NAT.

---

## Files in This Project

### `vpc.tf`
Contains, in order:
1. `aws_vpc` — the network itself
2. `aws_internet_gateway` — internet access point
3. `aws_subnet.public` (x2, via `count`) — public subnets across 2 AZs
4. `aws_subnet.private` (x2, via `count`) — private subnets across 2 AZs
5. `aws_eip` + `aws_nat_gateway` — outbound-only access for private subnets
6. `aws_route_table.public` + associations — routes public subnets to the IGW
7. `aws_route_table.private` + associations — routes private subnets to the NAT Gateway

### `main.tf`
- A security group allowing SSH (22) and HTTP (80)
- `aws_instance.public_web` — EC2 in the **public** subnet (gets a public IP, directly reachable)
- `aws_instance.private_app` — EC2 in the **private** subnet (no public IP, reachable only from inside the VPC)

---

## How to Run

```bash
terraform init
terraform plan
terraform apply
```

This creates (in order, following dependencies automatically):
```text
VPC
Internet Gateway
2 Public Subnets
2 Private Subnets
Elastic IP
NAT Gateway
Public Route Table + associations
Private Route Table + associations
Security Group
EC2 (public)
EC2 (private)
```

### Check outputs
```bash
terraform output
```
```text
vpc_id                  = "vpc-0123456789abcdef0"
public_subnet_ids       = ["subnet-0aaa...", "subnet-0bbb..."]
private_subnet_ids      = ["subnet-0ccc...", "subnet-0ddd..."]
nat_gateway_id          = "nat-0eee..."
public_web_public_ip    = "3.109.211.90"
private_app_private_ip  = "10.0.11.15"
```

### Verify connectivity
```bash
# SSH into the public instance
ssh -i your-key.pem ec2-user@$(terraform output -raw public_web_public_ip)

# From INSIDE the public instance, you could then SSH to the private one
# (private_app_private_ip), since they're in the same VPC
```

Notice `private_app` has **no public IP output** at all — because it doesn't have one. That's the point of a private subnet.

---

## Clean Up

```bash
terraform destroy
```
⚠️ NAT Gateways cost money **per hour** even when idle (plus data processing charges) — don't leave this running if you're just testing.

---

## Common Interview Confusions, Clarified

| Question | Answer |
|---|---|
| Does a public subnet automatically mean internet access? | No — it needs `map_public_ip_on_launch = true` AND a route table pointing `0.0.0.0/0` to an Internet Gateway |
| Can a private subnet reach the internet at all? | Yes, outbound only, via a NAT Gateway — never inbound |
| Where does the NAT Gateway live? | In a **public** subnet, even though it serves private subnets |
| What actually makes a subnet "public"? | Its route table association — routing `0.0.0.0/0` to the IGW is what makes it public in practice |
| Do you need one NAT Gateway per AZ? | For high availability, yes — this demo uses one NAT Gateway for simplicity, but production setups typically deploy one per AZ so an AZ outage doesn't take down all private subnet internet access |

---

## Interview Answer (Quick Reference)

> "I build a VPC starting with the network itself and its CIDR block, then create public and private subnets across multiple availability zones for redundancy. Public subnets get `map_public_ip_on_launch` enabled and are associated with a route table that sends `0.0.0.0/0` traffic to an Internet Gateway. Private subnets have no public IPs and are associated with a separate route table that sends outbound traffic to a NAT Gateway instead — which itself sits in a public subnet, since it needs its own path to the internet to forward traffic on behalf of private instances. This setup lets private resources like app servers or databases make outbound calls, like downloading updates, without ever being directly reachable from the internet."
