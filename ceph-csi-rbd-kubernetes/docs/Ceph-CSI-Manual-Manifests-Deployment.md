# Ceph CSI (RBD) — Manual Manifest Deployment Walkthrough

**Ceph Version:** Squid (v19.x)
**Kubernetes Version:** v1.35
**Ceph CSI Image:** `quay.io/cephcsi/cephcsi:v3.16.2`

This walks through every manifest in [`../manifests/`](../manifests/), in order, with the command to apply it, how to verify it worked, and what it's actually doing.

> Fill in `<CEPH_FSID>`, `<MON1_IP>` / `<MON2_IP>` / `<MON3_IP>`, and `<CEPH_USER_KEY>` with your own cluster's real values before applying — see Steps 3 and 5 for how to retrieve them. Never commit the filled-in `secret.yaml` (it's already `.gitignore`d).

---

## 1. `01-namespace.yaml`

Creates the namespace all Ceph CSI resources live in.

```bash
kubectl apply -f manifests/01-namespace.yaml
kubectl get ns ceph-csi
```

Expected:
```
NAME        STATUS   AGE
ceph-csi    Active
```

---

## 2. `02-ceph-conf.yaml`

Base `ceph.conf` enabling CephX authentication, mounted into the CSI pods.

```bash
kubectl apply -f manifests/02-ceph-conf.yaml
kubectl get configmap -n ceph-csi
```

> Note: the node plugin and provisioner actually mount `/etc/ceph` via `emptyDir` rather than this ConfigMap directly, to avoid a read-only filesystem error — but this ConfigMap is still required to exist.

---

## 3. `03-csi-config-map.yaml`

The most important ConfigMap — tells the driver how to reach your Ceph cluster.

**Get your values first:**

```bash
ceph fsid          # → clusterID
ceph mon dump      # → monitor IPs
```

Edit `manifests/03-csi-config-map.yaml` and replace `<CEPH_FSID>`, `<MON1_IP>`, `<MON2_IP>`, `<MON3_IP>` with the real values, then:

```bash
kubectl apply -f manifests/03-csi-config-map.yaml
kubectl get configmap ceph-csi-config -n ceph-csi -o yaml
```

> If the FSID or monitor IPs are wrong, PVC provisioning will fail with a connection error.

---

## 4. `04-kms-config.yaml`

Required even without encryption — an empty KMS config satisfies the volume mount both the node plugin and provisioner expect.

```bash
kubectl apply -f manifests/04-kms-config.yaml
kubectl get configmap -n ceph-csi
```

---

## 5. `05-secret.yaml`

Stores the CephX credentials used to create/attach/expand/delete RBD images.

**Create the Ceph user first (on your Ceph cluster):**

```bash
ceph auth get-or-create client.kubernetes \
  mon 'allow r' \
  osd 'allow rwx pool=kubernetes'
```

Copy `manifests/05-secret.yaml.example` → `manifests/05-secret.yaml`, fill in the real `userKey` from the output above, then:

```bash
kubectl apply -f manifests/05-secret.yaml
kubectl get secret -n ceph-csi
```

**Common mistakes:**
- `userID` must be `kubernetes`, **not** `client.kubernetes` (drop the `client.` prefix)
- Wrong key → `rados: ret=-13, Permission denied`

---

## 6. `06-csi-nodeplugin-rbac.yaml`

ServiceAccount + ClusterRole + ClusterRoleBinding for the node plugin (DaemonSet).

```bash
kubectl apply -f manifests/06-csi-nodeplugin-rbac.yaml
kubectl get sa,clusterrole,clusterrolebinding -n ceph-csi | grep rbd-csi-nodeplugin
```

---

## 7. `07-csi-provisioner-rbac.yaml`

RBAC for the provisioner — creates/deletes/expands RBD volumes and handles leader election.

```bash
kubectl apply -f manifests/07-csi-provisioner-rbac.yaml
kubectl get sa,role,rolebinding -n ceph-csi
```

> ⚠️ Watch for typos if you hand-edit this file — `apiGroup: rbac.authorization.k8s.io` is case-sensitive. A stray capital letter (`k8s.iO`) will fail with:
> ```
> Unsupported value: "rbac.authorization.k8s.iO": supported values: "rbac.authorization.k8s.io"
> ```

---

## 8. `08-csidriver.yaml`

Registers the `rbd.csi.ceph.com` driver with Kubernetes.

```bash
kubectl apply -f manifests/08-csidriver.yaml
kubectl get csidriver
```

Expected:
```
NAME                 ATTACHREQUIRED   PODINFOONMOUNT   MODES
rbd.csi.ceph.com     true             false            Persistent
```

---

## 9. `09-csi-rbdplugin.yaml`

Deploys the **node plugin** as a DaemonSet — one pod per node, handles mapping/mounting RBD volumes.

```bash
kubectl apply -f manifests/09-csi-rbdplugin.yaml
kubectl get ds -n ceph-csi
kubectl get pods -n ceph-csi -o wide
```

> These pods use `hostNetwork: true`, so their pod IP will equal the node's real IP. This is expected.

---

## 10. `10-csi-rbdplugin-provisioner.yaml`

Deploys the **provisioner** as a Deployment (3 replicas) — creates/deletes/expands RBD images and manages snapshots.

```bash
kubectl apply -f manifests/10-csi-rbdplugin-provisioner.yaml
kubectl get deployment -n ceph-csi
kubectl get pods -n ceph-csi -o wide
```

Expected:
```
NAME                          READY   UP-TO-DATE   AVAILABLE
csi-rbdplugin-provisioner     3/3     3            3
```

> These pods use normal pod-network IPs (via your CNI, e.g. Cilium) — not `hostNetwork`, so their IPs will differ from the node plugin pods even on the same node.

---

## 11. `11-storage-class.yaml`

**Before applying, create the pool it references on the Ceph side:**

```bash
ceph osd pool create kubernetes 32 32
rbd pool init kubernetes
ceph osd pool set kubernetes pg_autoscale_mode on   # optional but recommended
```

Edit `manifests/11-storage-class.yaml`, replace `<CEPH_FSID>`, then:

```bash
kubectl apply -f manifests/11-storage-class.yaml
kubectl get storageclass
```

> Skipping the pool-creation step causes:
> ```
> rpc error: code = Internal desc = pool not found: pool (kubernetes) not found in Ceph cluster
> ```

---

## 12. `12-pvc.yaml`

Requests 2Gi from `csi-rbd-sc`.

```bash
kubectl apply -f manifests/12-pvc.yaml
kubectl get pvc rbd-pvc -w
```

Expected once bound:
```
NAME      STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
rbd-pvc   Bound    2Gi        RWO            csi-rbd-sc
```

Verify the RBD image was actually created on the Ceph side:

```bash
rbd ls kubernetes
```

---

## 13. `13-test-pod.yaml`

A BusyBox pod mounting the PVC, to prove read/write access works end-to-end.

```bash
kubectl apply -f manifests/13-test-pod.yaml
kubectl exec -it csi-rbd-test-pod -- sh -c "echo 'hello ceph' > /data/test.txt && cat /data/test.txt"
```

If that prints `hello ceph`, the entire stack — Ceph pool → CephX auth → CSI driver → StorageClass → PVC → Pod — is working.

---

## Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|---|---|---|
| `apiGroup: Unsupported value: "...k8s.iO"` | Typo — capital `O` | Fix casing, re-apply |
| `open /etc/ceph/keyring: read-only file system` | `/etc/ceph` mounted from ConfigMap directly | Already fixed via `emptyDir` in `09-csi-rbdplugin.yaml` / `10-csi-rbdplugin-provisioner.yaml` |
| `pool not found: pool (kubernetes) not found` | Pool never created on Ceph | `ceph osd pool create kubernetes 32 32 && rbd pool init kubernetes` |
| `rados: ret=-13, Permission denied` | Wrong key or `userID` | Check `ceph auth get-or-create` output vs `05-secret.yaml` |
| PVC stuck `Pending` | Any of the above | `kubectl describe pvc rbd-pvc` + provisioner logs |
