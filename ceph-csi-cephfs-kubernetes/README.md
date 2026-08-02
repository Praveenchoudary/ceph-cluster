# CephFS + ceph-csi deployment (namespace: ceph-csi)

Working, verified setup — CephFS (shared, ReadWriteMany) storage integrated
into Kubernetes via ceph-csi.

Cluster details already filled in:
- clusterID (fsid): `130c0b6a-8c50-11f1-9d8b-0200d830b26e`
- monitors: `10.9.2.19:6789`, `10.9.2.18:6789`, `10.9.2.17:6789`
- fsName: `cephfs`
- pool: `cephfs_data`

This is **CephFS only** (`cephfs.csi.ceph.com`, `ReadWriteMany`). It is not
the RBD (block storage, `ReadWriteOnce`) driver.

## ⚠️ Secret handling — read this before pushing to git

`02-csi-cephfs-secret.yaml` in this repo has a **placeholder** key on
purpose. Never replace that placeholder and commit it — anyone with the
real key gets read/write access to your CephFS pools.

Instead, do one of:

**Option A — local untracked copy**
```bash
cp 02-csi-cephfs-secret.yaml 02-csi-cephfs-secret.local.yaml
# edit 02-csi-cephfs-secret.local.yaml with the real key
kubectl apply -f 02-csi-cephfs-secret.local.yaml
```
`.gitignore` already excludes `*.local.yaml`.

**Option B — create directly via kubectl, never touch the file**
```bash
KEY=$(ssh root@ceph1 "ceph auth get-key client.k8s")
kubectl -n ceph-csi create secret generic csi-cephfs-secret \
  --from-literal=userID=k8s \
  --from-literal=userKey="$KEY" \
  --from-literal=adminID=k8s \
  --from-literal=adminKey="$KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Step 0 — on the Ceph cluster: create the client with correct caps

This is the exact set of caps confirmed working. `client.k8s` needs `mgr`
access because ceph-csi calls the mgr volumes module (`ceph fs subvolume
...`) to create/delete volumes — narrower caps (`mgr 'allow rw'` with
`osd tag cephfs ...`) failed with `Operation not permitted` in testing.

```bash
ceph auth get-or-create client.k8s \
  mon 'allow r' \
  mgr 'allow *' \
  osd 'allow rw pool=cephfs_data, allow rw pool=cephfs_metadata' \
  mds 'allow *' \
  -o /etc/ceph/ceph.client.k8s.keyring

ceph auth get-key client.k8s
```

If you already created the user with narrower caps, widen them:

```bash
ceph auth caps client.k8s \
  mon 'allow r' \
  mgr 'allow *' \
  osd 'allow rw pool=cephfs_data, allow rw pool=cephfs_metadata' \
  mds 'allow *'
```

## Step 1 — apply the manifests

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-csi-config-map.yaml
kubectl apply -f 06-ceph-config.yaml
# apply your real secret here (see options above), NOT the placeholder file
kubectl apply -f 03-csi-provisioner-rbac.yaml
kubectl apply -f 04-csi-nodeplugin-rbac.yaml
kubectl apply -f 04b-csidriver.yaml
kubectl apply -f 05-csi-cephfsplugin-provisioner.yaml
kubectl apply -f 07-csi-cephfsplugin.yaml
kubectl apply -f 08-storageclass.yaml
```

## Step 2 — verify the driver is healthy

```bash
kubectl -n ceph-csi get pods
kubectl get csidrivers
```

Expect `csi-cephfsplugin-provisioner-*` at `4/4 Running` (x3) and
`csi-cephfsplugin-*` at `2/2 Running` on every node.

**If you change caps on an existing `client.k8s` user after the provisioner
pods are already running, restart them** — the provisioner keeps
persistent RADOS connections and won't automatically pick up new caps:

```bash
kubectl -n ceph-csi delete pod -l app=csi-cephfsplugin-provisioner
```

## Step 3 — test provisioning

```bash
kubectl apply -f 09-test-pvc.yaml
kubectl get pvc cephfs-pvc -w
```

Once `Bound`:

```bash
kubectl apply -f 10-test-pod.yaml
kubectl exec -it cephfs-test-pod -- sh -c "echo hello > /data/test.txt && cat /data/test.txt"
```

Confirm from the Ceph side:

```bash
ceph fs subvolume ls cephfs csi
```

## Troubleshooting notes from actual debugging

- `missing ID field 'adminID' in secrets` → the Secret needs both
  `userID/userKey` (mount) AND `adminID/adminKey` (provisioning), not
  just one pair.
- `rados: ret=-1, Operation not permitted` on `CreateVolume` → almost
  always a caps issue on `client.k8s`. `mgr 'allow rw'` was not enough;
  `mgr 'allow *'` was needed for the volumes module calls. If caps look
  correct but the error persists, restart the provisioner pods — they
  cache RADOS connections and don't reload caps live.
- `cannot change roleRef` on `kubectl apply` for a ClusterRoleBinding →
  roleRef is immutable; `kubectl delete clusterrolebinding <name>` then
  reapply.
- `FailedAttachVolume ... timed out waiting for external-attacher` →
  the `CSIDriver` object for `cephfs.csi.ceph.com` has
  `attachRequired: true` (the Kubernetes API default when no CSIDriver
  is explicitly applied). CephFS is mount-based, not attach-based, and
  this deployment does not run a `csi-attacher` sidecar, so the attach
  step will hang forever. Fix: apply `04b-csidriver.yaml`, which sets
  `attachRequired: false`. `CSIDriver.spec` is immutable, so if one
  already exists with the wrong value:
  ```bash
  kubectl delete csidriver cephfs.csi.ceph.com
  kubectl apply -f 04b-csidriver.yaml
  kubectl get volumeattachment | grep cephfs   # delete any stale ones
  ```

- `unable to get monitor info from DNS SRV with service name: ceph-mon`
  + `mount error 22 = Invalid argument` on `FailedMount` → this is a
  **misleading, generic fallback error** in ceph-csi's kernel mount
  path. It fires whenever `mount.ceph` argument parsing fails for any
  reason — most commonly an invalid/unsupported entry in the
  StorageClass's `mountOptions` (e.g. `debug`, `discard`,
  `ms_mode=secure`), not an actual DNS problem. Fix: remove
  `mountOptions` from the StorageClass entirely (already done in
  `08-storageclass.yaml`). Since `mountOptions` is immutable on an
  existing StorageClass, delete and recreate it, and delete/recreate
  any PVC that was already provisioned under the broken version.

## Network requirement

Every k8s node must reach the Ceph monitors on `6789/tcp` and the OSDs
(typically `6800-7300/tcp`).

```bash
nc -zv 10.9.2.19 6789
nc -zv 10.9.2.18 6789
nc -zv 10.9.2.17 6789
```

## Cleanup

```bash
kubectl delete -f 10-test-pod.yaml -f 09-test-pvc.yaml
kubectl delete -f .
```
