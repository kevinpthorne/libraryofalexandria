# SeaweedFS Migration: Longhorn to Local-Path-Provisioner

## 1. Architectural Overview

Originally, SeaweedFS was deployed via the ArgoCD `loa-core` application atop Longhorn storage (`storageClass: longhorn`). This created a circular dependency and storage overhead where object storage and filer data sat inside replicated block devices.

In the new architecture:
- **Longhorn** remains the primary block storage provider and default `StorageClass` in Kubernetes. Workloads using Longhorn are completely untouched.
- **SeaweedFS** runs *next to* Longhorn, managed as a foundational control-plane module (`modules/submodules/k8s/control-plane/seaweedfs.nix`).
- SeaweedFS master, volume, and filer pods store data directly on node local disks via **`local-path-provisioner`** (`storageClass: local-path`, backed by `/var/lib/local-path-provisioner`).
- **SeaweedFS CSI Driver** remains in the ArgoCD layer (`apps/loa-core/templates/seaweedfs-csi.yml`) for applications like Immich that need SeaweedFS mounts, with `isDefaultStorageClass: false`.

```
Workload Pods (PostgreSQL, Immich DB, etc.)
       │
       ▼ (PV / PVC)
┌──────────────┐
│   Longhorn   │  <-- Primary StorageClass (Default)
└──────┬───────┘
       │
       ▼
  Node Disks

SeaweedFS (Master, Volume, Filer, S3 Gateway)
       │
       ▼ (PV / PVC)
┌────────────────────────┐
│ local-path-provisioner │  <-- StorageClass: local-path
└──────────┬─────────────┘
           │
           ▼
 /var/lib/local-path-provisioner (Host Local Disk)
```

---

## 2. Configurable Node-Aware Replication

Replication is automatically calculated in `modules/submodules/k8s/control-plane/seaweedfs.nix` based on the cluster node count (`masters.count + workers.count`):

| Cluster Node Count | Effective Replication | Volume Replicas | Pod Anti-Affinity | Example Clusters |
| :--- | :--- | :--- | :--- | :--- |
| **1 node** | `"000"` (1 copy, no replication) | `1` | Disabled | `g`, `test` |
| **> 1 nodes** | `"001"` (1 replica across racks/nodes) | `2` | Enabled (`requiredDuringSchedulingIgnoredDuringExecution`) | `k` |

### Single-Source-of-Truth Linking
The control-plane module injects the computed replication setting into `loa-core`'s values:
```nix
libraryofalexandria.cluster.apps.loa-core.valuesOverrides.seaweedfs.replication = effectiveReplication;
```
The SeaweedFS CSI driver in `apps/loa-core/templates/seaweedfs-csi.yml` then consumes this value automatically:
```yaml
storageClassParameters:
  replication: {{ .Values.seaweedfs.replication | default "000" | quote }}
```

Users can also override the defaults per cluster in `clusters/<cluster>/default.nix`:
```nix
control-plane.seaweedfs.extraOptions = {
  replication = "001";
  volumeReplicas = 5;
  size = "1G"; # e.g. for testing
};
```

---

---

## 3. Operational Sequence (When to Apply Colmena vs. When to Push to Git)

> [!WARNING]
> **DO NOT push your Git changes to origin before running the migration.**
> If you push to GitHub first, ArgoCD will detect that `seaweedfs-operator.yml` and `seaweedfs/` have been deleted from `loa-core`. Because `loa-core` has `prune: true` and `resources-finalizer.argocd.argoproj.io`, **ArgoCD will immediately delete the operator and the `Seaweed` CR**, tearing down your volume servers before you can migrate the data!

The correct operational sequence is:

```
[Phase 0] Operator Handover (From Workstation or master0)
   │
   ├─► Orphan ArgoCD's seaweedfs-operator Application (stops ArgoCD selfHeal)
   ├─► Strip tracking annotations from seaweed-cluster CR
   └─► Delete old Deployment/seaweedfs-operator (SeaweedFS storage continues running uninterrupted!)
   │
   ▼
[Phase 1] Deploy via Colmena (Local Working Tree)
   │
   ├─► Deploys local-path-provisioner (StorageClass ready)
   ├─► Deploys new seaweedfs-operator (v0.1.42) via Helm cleanly into empty slot (zero conflict)
   ├─► Installs migrate-seaweedfs-to-localpath on master0
   └─► Updates Seaweed CR with local-path storageClass
   │
   ▼
[Phase 2] Run Migration Script on master0
   │
   ├─► Quiesces Immich (unmounts CSI FUSE cleanly)
   ├─► Backs up volume chunks (*.dat, *.idx) and filer metadata
   ├─► Swaps StatefulSets to local-path & restores all data
   └─► Resumes Immich
   │
   ▼
[Phase 3] Commit & Push to Git (ArgoCD Sync)
   │
   └─► ArgoCD syncs loa-core: prune is a safe no-op because resources were orphaned
   └─► ArgoCD updates seaweedfs-csi with new replication parameter
```

### Detailed Walkthrough

#### Step 0: Pre-Colmena Handover (Prevent Operator Collision & Resync)
Because `loa-core` is the parent ArgoCD application that defines `seaweedfs-operator.yml`, its auto-sync/self-heal will immediately recreate `seaweedfs-operator` if deleted while Git still has the old templates.

**First, disable Auto-Sync on `loa-core`**:
- **Via ArgoCD UI**: Go to Applications → **`loa-core`** → **App Details** (top bar) → under **Sync Policy**, click **Disable Auto-Sync** (or toggle off Self-Heal).
- **Or via CLI**:
  ```bash
  kubectl patch app loa-core -n argo-cd -p '{"spec":{"syncPolicy":{"automated":null}}}' --type=merge
  ```

**Next, adopt all existing resources into Helm so the Helm installer succeeds without ownership errors**:
```bash
# 1. Remove finalizers and orphan the ArgoCD seaweedfs-operator application
kubectl patch app seaweedfs-operator -n argo-cd -p '{"metadata":{"finalizers":[]}}' --type=merge || true
kubectl delete app seaweedfs-operator -n argo-cd --cascade=orphan || true

# 2. Adopt all SeaweedFS CRDs for Helm release seaweedfs-operator
for crd in $(kubectl get crd -o name 2>/dev/null | grep -i seaweed || true); do
  kubectl annotate "$crd" meta.helm.sh/release-name=seaweedfs-operator meta.helm.sh/release-namespace=seaweedfs-system --overwrite 2>/dev/null || true
  kubectl label "$crd" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

# 3. Adopt all ClusterRoles and ClusterRoleBindings
for cr in $(kubectl get clusterrole -o name 2>/dev/null | grep -i seaweed || true); do
  kubectl annotate "$cr" meta.helm.sh/release-name=seaweedfs-operator meta.helm.sh/release-namespace=seaweedfs-system --overwrite 2>/dev/null || true
  kubectl label "$cr" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

for crb in $(kubectl get clusterrolebinding -o name 2>/dev/null | grep -i seaweed || true); do
  kubectl annotate "$crb" meta.helm.sh/release-name=seaweedfs-operator meta.helm.sh/release-namespace=seaweedfs-system --overwrite 2>/dev/null || true
  kubectl label "$crb" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

# 4. Adopt namespaced resources in seaweedfs-system
for item in $(kubectl get all,sa,secret,configmap,role,rolebinding -n seaweedfs-system -o name 2>/dev/null || true); do
  if echo "$item" | grep -q -E "seaweed-cluster|s3"; then
    rel="seaweedfs-cluster"
  else
    rel="seaweedfs-operator"
  fi
  kubectl annotate "$item" -n seaweedfs-system meta.helm.sh/release-name="$rel" meta.helm.sh/release-namespace=seaweedfs-system --overwrite 2>/dev/null || true
  kubectl label "$item" -n seaweedfs-system app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

# 5. Adopt Seaweed CR and strip ArgoCD annotations
if kubectl get seaweed seaweed-cluster -n seaweedfs-system >/dev/null 2>&1; then
  kubectl annotate seaweed seaweed-cluster -n seaweedfs-system argocd.argoproj.io/tracking-id- 2>/dev/null || true
  kubectl annotate seaweed seaweed-cluster -n seaweedfs-system meta.helm.sh/release-name=seaweedfs-cluster meta.helm.sh/release-namespace=seaweedfs-system --overwrite 2>/dev/null || true
  kubectl label seaweed seaweed-cluster -n seaweedfs-system app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
fi
```
> [!NOTE]
> Adopting these resources into Helm prevents `INSTALLATION FAILED: ... invalid ownership metadata` errors. SeaweedFS storage continues serving files and Immich without interruption. Because Auto-Sync is disabled on `loa-core`, ArgoCD will not re-add the operator.

#### Step 1: Deploy NixOS Infrastructure via Colmena (Do Not Push Git)
From your workstation containing the modified files, deploy the NixOS configuration using Colmena:
```bash
# Example for cluster k:
nix run .#apps.aarch64-linux.colmena -- apply --on @cluster=k -v --show-trace
```
*What this does*:
- Colmena evaluates your local working tree.
- Configures `/var/lib/local-path-provisioner` permissions and storage on the host nodes.
- Deploys `local-path-provisioner` so the `local-path` StorageClass is ready.
- Deploys the new `seaweedfs-operator` (v0.1.42) cleanly via Helm into the empty slot.
- Installs `migrate-seaweedfs-to-localpath` onto `master0`.
- Updates the `Seaweed` CR to request `local-path` (the existing StatefulSets remain running because Kubernetes rejects immutable `volumeClaimTemplates` updates without manual recreation).

#### Step 2: Execute Migration on `master0`
SSH into `master0` and run the migration tool:
```bash
sudo migrate-seaweedfs-to-localpath
```
*(Alternatively, run `./scripts/migrate-seaweedfs-to-localpath.sh` from your workstation).*

*What this does*:
1. **Verifies pre-flight state**: Checks `local-path` StorageClass and checks for Longhorn PVCs.
2. **Quiesces Immich**: Temporarily scales down Immich deployments to cleanly disconnect FUSE mounts.
3. **Backs up volume chunks & filer metadata**: Streams `/data/*` (`*.dat`, `*.idx`, `*.vif`) from all volume pods and exports filer metadata.
4. **Swaps storage**: Deletes old StatefulSets and Longhorn PVCs, resumes the operator to create new StatefulSets backed by `local-path`.
5. **Restores all data**: Injects the volume chunks into the new volume pods, triggers volume indexing, and restores filer metadata.
6. **Restores Immich**: Scales Immich back up with full access to all photos.

#### Step 3: Commit and Push Changes to Git (ArgoCD)
Now that SeaweedFS is running entirely on `local-path` and completely detached from ArgoCD's old tracking inventory, push your repository changes:
```bash
git add .
git commit -m "feat: migrate seaweedfs to control plane on local-path"
git push origin master
```
*What this does*:
- Pushes the removal of `seaweedfs-operator.yml` and `seaweedfs/` to Git.

**Finally, re-enable Auto-Sync and sync `loa-core`**:
- **Via ArgoCD UI**: Go to Applications → **`loa-core`** → click **Sync** (with Prune enabled), then in **App Details** → under **Sync Policy**, click **Enable Auto-Sync**.
- **Or via CLI**:
  ```bash
  kubectl patch app loa-core -n argo-cd -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}' --type=merge
  ```
- Because `app/seaweedfs-operator` was already orphaned and `seaweed-cluster` has no tracking annotations, ArgoCD's prune is a **complete no-op**. It will not touch your running cluster or operator.
- ArgoCD updates `seaweedfs-csi` with the node-aware replication setting (`000` or `001`).

---

## 4. What the Migration Tool Does Step-by-Step
1. **Pre-flight Check**: Confirms the `local-path` StorageClass is present and ready.
2. **Idempotency Check**: Inspects all PVCs in `seaweedfs-system`. If no Longhorn PVCs exist (or if the cluster is fresh), it exits cleanly with code `0` (safe no-op).
3. **Decouple ArgoCD Ownership**: Strips finalizers from ArgoCD `seaweedfs-operator` Application and deletes it with `--cascade=orphan`. Strips tracking annotations (`argocd.argoproj.io/tracking-id` and `app.kubernetes.io/instance`) from the `Seaweed` CR `seaweed-cluster`. This prevents ArgoCD from cascade-pruning the operator or the cluster when `loa-core` syncs.
4. **Quiesce Immich Workloads**: If the `immich` namespace exists, scales down all Immich deployments to cleanly unmount and disconnect CSI FUSE volume mounts, preventing frozen or hung I/O.
5. **Data Safety (PV Retain)**: Patches existing Longhorn PersistentVolumes to `reclaimPolicy: Retain` so that Longhorn block volumes cannot be deleted by Kubernetes.
6. **Volume Chunks Backup**: Streams all volume chunk files (`*.dat`, `*.idx`, `*.vif`) from each running volume pod (`seaweed-cluster-volume-*`) under `/data` into tar archives in `/var/tmp/seaweedfs-migration-*/`.
7. **Metadata Backup**: Backs up filer metadata using `weed filer.meta.backup` from the running filer pod to `/var/tmp/seaweedfs-migration-*/filer.meta`.
8. **Operator Pause**: Scales `seaweedfs-operator` down to 0 replicas to prevent reconciliation races while swapping StatefulSets.
9. **StatefulSet Swap**: Deletes the old `seaweed-cluster-volume` and `seaweed-cluster-filer` StatefulSets with `--cascade=orphan`.
10. **Old PVC Cleanup**: Deletes the old Longhorn PVCs (the underlying PVs remain safely preserved in Longhorn).
11. **Operator Resume**: Scales `seaweedfs-operator` back to 1 replica. The operator reconciles the `Seaweed` CR, creating new StatefulSets that request `storageClass: local-path`. `local-path-provisioner` dynamically provisions new PVCs and mounts host local directories under `/var/lib/local-path-provisioner`.
12. **Restore Volume Chunks**: Streams the saved `.dat`, `.idx`, and `.vif` tarballs directly into `/data` of the newly created volume pods, then restarts the pods so the volume servers scan their local files, load needle indexes into memory, and register all volumes with the master.
13. **Restore Filer Metadata**: Once the new filer pod is ready, restores the filer metadata using `weed filer.meta.restore`.
14. **Resume Immich Workloads**: Scales Immich deployments back to 1 replica. Immich pods mount the restored filer via CSI and find all libraries and photos completely intact.

---

## 5. Idempotency & Safety Guarantees

- **No-Op on Migrated Clusters**: If all PVCs in `seaweedfs-system` are already using `local-path`, running the script does nothing:
  ```text
  [+] All SeaweedFS PVCs in 'seaweedfs-system' are already using local-path (or non-Longhorn) storage.
  [+] SeaweedFS is already migrated! Exiting (no-op).
  ```
- **Zero Workload Disruption to Longhorn Apps**: Workload StatefulSets (like PostgreSQL, Vault, or other applications on Longhorn) are **not** touched.
- **Complete Immich Data Preservation**: Both the Haystack chunk store (`.dat` and `.idx` files) and the filer metadata tree are preserved and migrated to the host disk.
- **ArgoCD Conflict-Free**: By stripping tracking annotations and removing finalizers before syncing, ArgoCD and the Nix control-plane Helm installer will not conflict or fight over resource ownership.

---

## 6. Rollback Plan

If unexpected issues occur during cutover before metadata restoration:
1. Scale down `seaweedfs-operator`:
   ```bash
   kubectl scale deployment seaweedfs-operator -n seaweedfs-system --replicas=0
   ```
2. Delete the new `local-path` volume and filer StatefulSets:
   ```bash
   kubectl delete sts seaweed-cluster-volume seaweed-cluster-filer -n seaweedfs-system --cascade=orphan
   ```
3. Re-bind or recreate PVCs pointing to the retained Longhorn PVs.
4. Restore `apps/loa-core/values.yaml` `seaweedfs.storageClass: longhorn`.
