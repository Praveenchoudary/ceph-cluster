# Day 2 — Prerequisites and Node Setup (3 Ubuntu Machines)

This guide prepares **3 Ubuntu machines** before installing Ceph using `cephadm`.

---

## 2.1 Lab Topology

| Hostname | Role                  | Example IP     |
|----------|-----------------------|----------------|
| ceph1    | MON, MGR, OSD (bootstrap node) | 192.168.1.11 |
| ceph2    | MON, OSD              | 192.168.1.12   |
| ceph3    | MON, OSD              | 192.168.1.13   |

> Replace IPs and hostnames with your actual environment values.

Each node should have:

- Ubuntu 22.04 LTS (or 24.04 LTS)
- Minimum 2 vCPU / 4 GB RAM (lab), 8+ GB RAM recommended for production
- At least **one extra raw/unused disk** (not the OS disk) to be used as an OSD
- Network connectivity between all 3 nodes

---

## 2.2 Set Hostnames

Run on each node (replace with the correct hostname per node):

```bash
sudo hostnamectl set-hostname ceph1   # run on node 1
sudo hostnamectl set-hostname ceph2   # run on node 2
sudo hostnamectl set-hostname ceph3   # run on node 3
```

---

## 2.3 Configure /etc/hosts

On **all 3 nodes**, edit `/etc/hosts`:

```bash
sudo tee -a /etc/hosts <<EOF
192.168.1.11 ceph1
192.168.1.12 ceph2
192.168.1.13 ceph3
EOF
```

Verify:

```bash
ping -c 2 ceph1
ping -c 2 ceph2
ping -c 2 ceph3
```

---

## 2.4 Update System Packages

On all 3 nodes:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl vim net-tools chrony
```

---

## 2.5 Time Synchronization (NTP)

Ceph is sensitive to clock drift between nodes. Ensure `chrony` is running:

```bash
sudo systemctl enable --now chrony
timedatectl
```

---

## 2.6 Set Up SSH Key-Based Access

`cephadm` uses SSH to manage nodes. On the **bootstrap node (ceph1)**, generate a key and copy it to the other nodes:

```bash
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

ssh-copy-id root@ceph1
ssh-copy-id root@ceph2
ssh-copy-id root@ceph3
```

Test passwordless SSH:

```bash
ssh root@ceph2 hostname
ssh root@ceph3 hostname
```

---

## 2.7 Install Container Runtime (Podman/Docker)

`cephadm` deploys all Ceph daemons as containers, so a container runtime is required on **all nodes**.

```bash
sudo apt install -y podman
podman --version
```

> Podman is the default recommended runtime for `cephadm` on modern Ubuntu releases. Docker CE also works if preferred.

---

## 2.8 Install Python3

Required by `cephadm`:

```bash
sudo apt install -y python3
python3 --version
```

---

## 2.9 Identify the Raw Disk for OSD

On **each** node, identify the extra unused disk that will become an OSD (do **not** use the OS disk):

```bash
lsblk
```

Example output:

```
NAME    SIZE  TYPE
sda     40G   disk   ← OS disk, do not touch
└─sda1  40G   part
sdb     20G   disk   ← unused, will become OSD
```

Confirm the disk has no filesystem/partitions:

```bash
sudo wipefs -n /dev/sdb
```

> `-n` performs a dry run. Actual wiping happens automatically when Ceph claims the disk in Day 4 — no manual formatting needed.

---

## 2.10 Open Required Firewall Ports

If `ufw` is enabled, allow the Ceph ports on all 3 nodes:

```bash
sudo ufw allow 3300/tcp   # Monitor (msgr2)
sudo ufw allow 6789/tcp   # Monitor (legacy)
sudo ufw allow 6800:7300/tcp   # OSD/MGR daemons
sudo ufw allow 8443/tcp   # Dashboard (HTTPS)
sudo ufw allow 22/tcp     # SSH
sudo ufw reload
```

---

## 2.11 Checklist Before Moving On

- [ ] All 3 nodes can ping each other by hostname
- [ ] Passwordless SSH from ceph1 → ceph2, ceph3 works
- [ ] Podman installed on all nodes
- [ ] Python3 installed on all nodes
- [ ] Time is in sync (chrony running)
- [ ] Each node has one unused disk identified for OSD
- [ ] Firewall ports opened

---

## What's Next

Continue to [`Day-3-Cephadm-Bootstrap.md`](./Day-3-Cephadm-Bootstrap.md) to bootstrap the Ceph cluster on `ceph1`.
