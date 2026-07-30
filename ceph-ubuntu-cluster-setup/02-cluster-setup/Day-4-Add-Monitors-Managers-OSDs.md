# Day 4 — Add Monitors, Managers, and OSDs (Scale to 3 Nodes)

This guide expands the single-node bootstrap from Day 3 into a full **3-node cluster** with MONs, MGRs, and OSDs on every host.

---

## 4.1 Add ceph2 and ceph3 to the Cluster

Run from **ceph1**:

```bash
ceph orch host add ceph2 192.168.1.12
ceph orch host add ceph3 192.168.1.13
```

Verify all hosts are recognized:

```bash
ceph orch host ls
```

Expected:

```
HOST   ADDR            LABELS  STATUS
ceph1  192.168.1.11    _admin
ceph2  192.168.1.12
ceph3  192.168.1.13
```

---

## 4.2 Deploy Additional Monitors

By default, `cephadm` will try to place MONs automatically, but it's best to be explicit for a 3-node cluster:

```bash
ceph orch apply mon --placement="ceph1,ceph2,ceph3"
```

Verify quorum:

```bash
ceph mon stat
```

You should see all 3 MONs in quorum:

```
e3: 3 mons at {ceph1=...,ceph2=...,ceph3=...}, election epoch 6, leader 0 ceph1, quorum 0,1,2 ceph1,ceph2,ceph3
```

---

## 4.3 Deploy an Additional Manager (for HA)

```bash
ceph orch apply mgr --placement="ceph1,ceph2"
```

Check active/standby MGRs:

```bash
ceph -s | grep mgr
```

---

## 4.4 Add OSDs (One Disk per Node)

Recall from Day 2 that each node has one unused disk identified (e.g., `/dev/sdb`).

**Option A — Let Ceph auto-claim all available unused disks (recommended for lab):**

```bash
ceph orch apply osd --all-available-devices
```

**Option B — Add a specific disk per host explicitly (recommended for production):**

```bash
ceph orch daemon add osd ceph1:/dev/sdb
ceph orch daemon add osd ceph2:/dev/sdb
ceph orch daemon add osd ceph3:/dev/sdb
```

---

## 4.5 Verify OSDs

```bash
ceph osd tree
```

Expected output:

```
ID  CLASS  WEIGHT   TYPE NAME       STATUS
-1         0.05878  root default
-3         0.01959      host ceph1
 0    hdd  0.01959          osd.0        up
-5         0.01959      host ceph2
 1    hdd  0.01959          osd.1        up
-7         0.01959      host ceph3
 2    hdd  0.01959          osd.2        up
```

---

## 4.6 Set Replication Size (Pool Default)

For a 3-node cluster, replication size 3 is standard:

```bash
ceph config set global osd_pool_default_size 3
ceph config set global osd_pool_default_min_size 2
```

This means: 3 copies of data, and the cluster remains writable as long as at least 2 copies are available.

---

## 4.7 Final Health Check

```bash
ceph -s
```

You should now see:

```
  cluster:
    id:     <uuid>
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph1,ceph2,ceph3
    mgr: ceph1(active), standbys: ceph2
    osd: 3 osds: 3 up, 3 in
```

`HEALTH_OK` confirms the 3-node cluster is fully operational with quorum, redundancy, and storage active.

---

## What's Next

Continue to [`03-dashboard-access/Day-5-Dashboard-NGINX-LetsEncrypt.md`](../03-dashboard-access/Day-5-Dashboard-NGINX-LetsEncrypt.md) to expose the Ceph Dashboard securely via NGINX and Let's Encrypt.
