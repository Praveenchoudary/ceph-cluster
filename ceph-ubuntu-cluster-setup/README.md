# Ceph Cluster Setup on Ubuntu (3-Node) — Squid v19.x

A hands-on, day-by-day guide to deploying a production-style **Ceph Squid (v19.x)** cluster across **3 Ubuntu machines** using `cephadm`, with a secured Dashboard behind NGINX + Let's Encrypt.

---

## 📁 Repo Structure

```
ceph-ubuntu-cluster-setup/
├── README.md
├── 01-introduction/
│   └── Day-1-Ceph-Introduction.md
├── 02-cluster-setup/
│   ├── Day-2-Prerequisites-and-Node-Setup.md
│   ├── Day-3-Cephadm-Bootstrap.md
│   └── Day-4-Add-Monitors-Managers-OSDs.md
└── 03-dashboard-access/
    └── Day-5-Dashboard-NGINX-LetsEncrypt.md
```

---

## 📖 Guide Index

| Day | Topic | Link |
|-----|-------|------|
| 1 | Introduction to Ceph — concepts, architecture, components | [01-introduction](./01-introduction/Day-1-Ceph-Introduction.md) |
| 2 | Prerequisites & preparing 3 Ubuntu nodes | [02-cluster-setup](./02-cluster-setup/Day-2-Prerequisites-and-Node-Setup.md) |
| 3 | Bootstrapping the cluster with `cephadm` | [02-cluster-setup](./02-cluster-setup/Day-3-Cephadm-Bootstrap.md) |
| 4 | Scaling to 3 MONs/MGRs and adding OSDs | [02-cluster-setup](./02-cluster-setup/Day-4-Add-Monitors-Managers-OSDs.md) |
| 5 | Dashboard + NGINX reverse proxy + Let's Encrypt HTTPS | [03-dashboard-access](./03-dashboard-access/Day-5-Dashboard-NGINX-LetsEncrypt.md) |

---

## 🖥️ Lab Topology

| Hostname | Role | IP |
|----------|------|-----|
| ceph1 | MON, MGR, OSD (bootstrap node) | 192.168.1.11 |
| ceph2 | MON, OSD | 192.168.1.12 |
| ceph3 | MON, OSD | 192.168.1.13 |

---

## ✅ What You'll End Up With

- A 3-node Ceph cluster with MON quorum, MGR HA, and OSDs on every node
- `HEALTH_OK` cluster status with replication size 3
- Ceph Dashboard reachable securely over HTTPS via NGINX + Let's Encrypt

---

## 🛠️ Requirements

- 3x Ubuntu 22.04/24.04 LTS machines
- Root or sudo access on all nodes
- One unused disk per node (for OSD)
- A domain name pointing to the dashboard/proxy node (for Let's Encrypt)

---

## License

MIT (or update to match your preference).

## Contributing

Issues and PRs are welcome — feel free to open one if you spot an error or want to add a section (e.g., CephFS, RGW/S3, backup/DR).
