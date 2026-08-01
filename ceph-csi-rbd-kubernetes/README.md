# Ceph CSI (RBD) — Kubernetes Deployment

Dynamically provision Ceph RBD block storage volumes on Kubernetes using the Ceph CSI driver, deployed via raw manifests .

Tested against:

- **Ceph:** Squid (v19.x)
- **Kubernetes:** v1.35
- **Ceph CSI:** v3.16.2

---

## 📖 Reference

Manifests here are based on the official upstream project:

> **Upstream source:** [ceph/ceph-csi — `deploy/rbd/kubernetes`](https://github.com/ceph/ceph-csi/tree/release-v3.17/deploy/rbd/kubernetes) (branch: `release-v3.17`)

This repo adds: the exact working **deployment order**, environment-specific **fixes** (e.g. read-only `/etc/ceph`), **verification commands**, and a **troubleshooting** section built from real errors hit during setup.

---

## 📂 Repo Structure

```
.
├── README.md
├── .gitignore
├── manifests/
│   ├── 01-namespace.yaml
│   ├── 02-ceph-conf.yaml
│   ├── 03-csi-config-map.yaml
│   ├── 04-kms-config.yaml
│   ├── 05-secret.yaml.example        ← copy to 05-secret.yaml, fill in, never commit
│   ├── 06-csi-nodeplugin-rbac.yaml
│   ├── 07-csi-provisioner-rbac.yaml
│   ├── 08-csidriver.yaml
│   ├── 09-csi-rbdplugin.yaml
│   ├── 10-csi-rbdplugin-provisioner.yaml
│   ├── 11-storage-class.yaml
│   ├── 12-pvc.yaml
│   └── 13-test-pod.yaml
└── docs/
    └── Ceph-CSI-Manual-Manifests-Deployment.md   ← full step-by-step walkthrough
```

---

## ✅ Prerequisites

- A healthy external Ceph cluster (Squid v19.x) with monitor IPs reachable from your Kubernetes nodes
- A running Kubernetes cluster (v1.35) with `kubectl` access
- `ceph` CLI access to the Ceph cluster (admin node or `cephadm shell`)

---

## 🚀 Quick Start

**1. Get your Ceph cluster details:**

```bash
ceph fsid
ceph mon dump
```

**2. Create the pool CSI will use:**

```bash
ceph osd pool create kubernetes 32 32
rbd pool init kubernetes
ceph osd pool set kubernetes pg_autoscale_mode on   # optional
```

**3. Create a scoped CephX user:**

```bash
ceph auth get-or-create client.kubernetes \
  mon 'allow r' \
  osd 'allow rwx pool=kubernetes'
```

**4. Fill in your real values:**

- `manifests/03-csi-config-map.yaml` → `<CEPH_FSID>`, `<MON1_IP>`, `<MON2_IP>`, `<MON3_IP>`
- `manifests/11-storage-class.yaml` → `<CEPH_FSID>`
- Copy `manifests/05-secret.yaml.example` → `manifests/05-secret.yaml` → fill in `<CEPH_USER_KEY>`

**5. Apply everything in order:**

```bash
kubectl apply -f manifests/01-namespace.yaml
kubectl apply -f manifests/02-ceph-conf.yaml
kubectl apply -f manifests/03-csi-config-map.yaml
kubectl apply -f manifests/04-kms-config.yaml
kubectl apply -f manifests/05-secret.yaml
kubectl apply -f manifests/06-csi-nodeplugin-rbac.yaml
kubectl apply -f manifests/07-csi-provisioner-rbac.yaml
kubectl apply -f manifests/08-csidriver.yaml
kubectl apply -f manifests/09-csi-rbdplugin.yaml
kubectl apply -f manifests/10-csi-rbdplugin-provisioner.yaml
kubectl apply -f manifests/11-storage-class.yaml
kubectl apply -f manifests/12-pvc.yaml
kubectl apply -f manifests/13-test-pod.yaml
```

**6. Verify:**

```bash
kubectl get pods -n ceph-csi
kubectl get pvc rbd-pvc
kubectl exec -it csi-rbd-test-pod -- df -h /data
```

If the PVC shows `Bound` and the pod can write to `/data`, everything's working end-to-end.

📄 Full walkthrough with explanations for every file: [`docs/Ceph-CSI-Manual-Manifests-Deployment.md`](./docs/Ceph-CSI-Manual-Manifests-Deployment.md)

---

## 🩺 Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `RoleBinding ... apiGroup: Unsupported value: "rbac.authorization.k8s.iO"` | Typo — capital `O` | Fix casing in the file, re-apply |
| `open /etc/ceph/keyring: read-only file system` | `/etc/ceph` mounted from a read-only ConfigMap | Already fixed here via `emptyDir: {}` in `09-` and `10-` manifests |
| `pool not found: pool (kubernetes) not found in Ceph cluster` | Pool never created on the Ceph side | `ceph osd pool create kubernetes 32 32 && rbd pool init kubernetes` |
| `rados: ret=-13, Permission denied` | Wrong CephX key or `userID` includes `client.` prefix | `userID` must be `kubernetes`, not `client.kubernetes` |
| PVC stuck `Pending` | Any of the above, or provisioner not running | `kubectl describe pvc rbd-pvc` + `kubectl logs -n ceph-csi deployment/csi-rbdplugin-provisioner -c csi-rbdplugin` |
| `csi-rbdplugin` pod IP equals node IP | Expected — uses `hostNetwork: true` | Not an issue; provisioner pods get normal pod-network IPs |

---

## 🔒 Security Notes

- `manifests/05-secret.yaml` (once created) contains a live CephX key and is excluded via `.gitignore` — never commit it.
- The `client.kubernetes` CephX user is scoped only to the `kubernetes` pool — no cluster-admin access.
- Rotate the key if it's ever exposed:
  ```bash
  ceph auth rm client.kubernetes
  ceph auth get-or-create client.kubernetes mon 'allow r' osd 'allow rwx pool=kubernetes'
  ```
- For production, consider managing this secret with **Sealed Secrets**, **External Secrets Operator**, or **Vault** instead of a plain manifest.

---

## 📚 Further Reading

- [Ceph CSI GitHub repo](https://github.com/ceph/ceph-csi)
- [Ceph CSI RBD documentation](https://github.com/ceph/ceph-csi/blob/devel/docs/deploy-rbd.md)
- [Ceph documentation](https://docs.ceph.com/)
- [Kubernetes CSI documentation](https://kubernetes-csi.github.io/docs/)
