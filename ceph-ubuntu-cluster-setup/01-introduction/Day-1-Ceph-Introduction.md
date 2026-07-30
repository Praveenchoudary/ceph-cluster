# Day 1 — Introduction to Ceph

**Version:** Ceph Squid (v19.x)

---

## 1.1 What is Ceph?

Ceph is an open-source distributed storage platform designed to provide:

- **Block Storage** (RBD)
- **File Storage** (CephFS)
- **Object Storage** (RGW / S3 Compatible)

Unlike a traditional storage server, Ceph stores data across multiple servers, providing high availability, scalability, and fault tolerance.

---

## 1.2 Why Use Ceph?

**Traditional storage** relies on a single server, which is a single point of failure:

```mermaid
graph TD
    S[Storage Server] --> VM1
    S --> VM2
    S --> VM3
```

**Problems:**

- Single point of failure
- Limited scalability
- Expensive storage appliances
- Difficult expansion

**Ceph** distributes data across multiple nodes instead:

```mermaid
graph TD
    subgraph Ceph Cluster
        C1[ceph1<br/>MON + OSD]
        C2[ceph2<br/>MON + OSD]
        C3[ceph3<br/>MON + OSD]
    end
    C1 <--> C2
    C2 <--> C3
    C1 <--> C3
```

**Advantages:**

- No single point of failure
- Automatic replication
- Horizontal scaling
- Self-healing
- Open source

---

## 1.3 Ceph Architecture

A production Ceph cluster consists of multiple services:

```mermaid
graph TD
    Client[Client] --> Access[ceph / RBD / CephFS]
    Access --> Monitor[Monitor - MON]
    Access --> Manager[Manager - MGR]
    Access --> OSDs[OSDs]
    Monitor --- Cluster((Cluster))
    Manager --- Cluster
    OSDs --- Cluster
```

Each service has a specific role.

---

## 1.4 Ceph Components

### Monitor (MON)

The Monitor maintains the cluster state.

**Responsibilities:**

- Cluster membership
- Quorum
- Authentication
- Cluster map

Without a healthy Monitor quorum, the cluster cannot operate normally.

```mermaid
graph LR
    MON1((MON1)) --- MON2((MON2))
    MON2 --- MON3((MON3))
    MON1 --- MON3
```

Two out of three MONs must be available to maintain quorum.

### Manager (MGR)

The Manager provides:

- Dashboard
- REST APIs
- Monitoring
- Metrics
- Orchestration support

**Without the Manager:**

- Storage continues to work.
- Dashboard and management features are unavailable.

### OSD (Object Storage Daemon)

OSDs store the actual data. Each storage disk usually corresponds to one OSD.

```mermaid
graph TD
    subgraph ceph1
        D1[Disk] --> O1[OSD.0]
    end
    subgraph ceph2
        D2[Disk] --> O2[OSD.1]
    end
    subgraph ceph3
        D3[Disk] --> O3[OSD.2]
    end
```

### Placement Groups (PGs)

Ceph does not place data directly onto OSDs. Instead:

```mermaid
graph LR
    File --> Object --> PG[Placement Group] --> OSD
```

Placement Groups help distribute and rebalance data efficiently.

### CRUSH

CRUSH stands for:

**Controlled Replication Under Scalable Hashing**

CRUSH determines:

- Which OSD stores an object
- Where replicas are placed

No central lookup table is required.

---

## 1.5 Data Flow

Suppose an application writes a file:

```mermaid
graph TD
    App[Application] --> K8s[Kubernetes]
    K8s --> PVC[PVC]
    PVC --> RBD[Ceph RBD]
    RBD --> Obj[Object]
    Obj --> CRUSH[CRUSH]
    CRUSH --> OSDs[OSDs]
```

---

## 1.6 Replication

Assume a replication size of 3:

```mermaid
graph TD
    Client[Client writes 1 GB] --> Object
    Object --> Primary[Primary OSD]
    Primary --> R1[Replica - OSD2]
    Primary --> R2[Replica - OSD3]
```

**Example:**

| OSD  | Data Stored |
|------|-------------|
| OSD1 | 1 GB        |
| OSD2 | 1 GB        |
| OSD3 | 1 GB        |

The application writes 1 GB, but Ceph stores 3 GB of raw data.

---

## 1.7 CephX Authentication

Ceph uses **CephX** for authentication.

**Example users:**

```
client.admin
client.kubernetes
```

Each user has:

- Username
- Secret key
- Permissions

**Example capabilities:**

```
mon:
  allow r

osd:
  allow rwx pool=kubernetes
```

---

## 1.8 Ceph Services Used in This Guide

In this guide, we'll configure:

- **MON** – Cluster monitoring and quorum
- **MGR** – Dashboard and management
- **OSD** – Data storage
- **Dashboard** – Web UI
- **cephadm** – Cluster deployment and orchestration
- **NGINX** – Reverse proxy
- **Let's Encrypt** – HTTPS for the dashboard

---

## What's Next

Continue to [`02-cluster-setup/`](../02-cluster-setup/Day-2-Prerequisites-and-Node-Setup.md) to begin preparing the 3 Ubuntu machines for the Ceph cluster.
