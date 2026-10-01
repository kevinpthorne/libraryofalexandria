#!/usr/bin/env bash
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
NAMESPACE="seaweedfs-system"
ARGO_NAMESPACE="argo-cd"
IMMICH_NAMESPACE="immich"

echo "=============================================================="
echo " SeaweedFS Migration Tool: Longhorn -> local-path-provisioner "
echo "=============================================================="

# 1. Pre-flight check: Verify local-path StorageClass is present
if ! "$KUBECTL" get sc local-path >/dev/null 2>&1; then
  echo "[-] ERROR: StorageClass 'local-path' not found. Ensure local-path-provisioner is deployed." >&2
  exit 1
fi

# 2. Check existing PVCs in seaweedfs-system
PVCS=$("$KUBECTL" get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

if [ -z "$PVCS" ]; then
  echo "[+] No PVCs found in '$NAMESPACE'. Fresh cluster detected. Nothing to migrate."
  exit 0
fi

# Check for PVCs on Longhorn storage
LONGHORN_PVCS=""
for pvc in $PVCS; do
  sc=$("$KUBECTL" get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || true)
  if [ "$sc" = "longhorn" ]; then
    LONGHORN_PVCS="$LONGHORN_PVCS $pvc"
  fi
done

if [ -z "$(echo "$LONGHORN_PVCS" | tr -d ' ')" ]; then
  echo "[+] All SeaweedFS PVCs in '$NAMESPACE' are already using local-path (or non-Longhorn) storage."
  echo "[+] SeaweedFS is already migrated! Exiting (no-op)."
  exit 0
fi

echo "[*] Found SeaweedFS PVCs on Longhorn storage:$LONGHORN_PVCS"

# 3. Decouple ArgoCD ownership and adopt resources for Helm
echo "[+] Decoupling ArgoCD ownership and adopting resources for Helm..."
if "$KUBECTL" get app loa-core -n "$ARGO_NAMESPACE" >/dev/null 2>&1; then
  echo "    Disabling Auto-Sync on parent ArgoCD application 'loa-core'..."
  "$KUBECTL" patch app loa-core -n "$ARGO_NAMESPACE" -p '{"spec":{"syncPolicy":{"automated":null}}}' --type=merge || true
fi

if "$KUBECTL" get app seaweedfs-operator -n "$ARGO_NAMESPACE" >/dev/null 2>&1; then
  echo "    Removing finalizers from ArgoCD application 'seaweedfs-operator'..."
  "$KUBECTL" patch app seaweedfs-operator -n "$ARGO_NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge || true
  echo "    Deleting ArgoCD application 'seaweedfs-operator' (--cascade=orphan)..."
  "$KUBECTL" delete app seaweedfs-operator -n "$ARGO_NAMESPACE" --cascade=orphan || true
fi

# Adopt CRDs for seaweedfs-operator
for crd in $("$KUBECTL" get crd -o name 2>/dev/null | grep -i seaweed || true); do
  echo "    Adopting $crd for Helm release seaweedfs-operator..."
  "$KUBECTL" annotate "$crd" meta.helm.sh/release-name=seaweedfs-operator meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  "$KUBECTL" label "$crd" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

# Adopt ClusterRoles and ClusterRoleBindings for seaweedfs-operator
for cr in $("$KUBECTL" get clusterrole -o name 2>/dev/null | grep -i seaweed || true); do
  echo "    Adopting $cr for Helm release seaweedfs-operator..."
  "$KUBECTL" annotate "$cr" meta.helm.sh/release-name=seaweedfs-operator meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  "$KUBECTL" label "$cr" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

for crb in $("$KUBECTL" get clusterrolebinding -o name 2>/dev/null | grep -i seaweed || true); do
  echo "    Adopting $crb for Helm release seaweedfs-operator..."
  "$KUBECTL" annotate "$crb" meta.helm.sh/release-name=seaweedfs-operator meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  "$KUBECTL" label "$crb" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

# Adopt Webhooks for seaweedfs-operator
for wh in $("$KUBECTL" get validatingwebhookconfigurations,mutatingwebhookconfigurations -o name 2>/dev/null | grep -i seaweed || true); do
  echo "    Adopting $wh for Helm release seaweedfs-operator..."
  "$KUBECTL" annotate "$wh" meta.helm.sh/release-name=seaweedfs-operator meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  "$KUBECTL" label "$wh" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

# Adopt namespace seaweedfs-system
if "$KUBECTL" get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "    Adopting namespace '$NAMESPACE' for Helm release seaweedfs-system-namespace..."
  "$KUBECTL" annotate namespace "$NAMESPACE" meta.helm.sh/release-name=seaweedfs-system-namespace meta.helm.sh/release-namespace=default --overwrite 2>/dev/null || true
  "$KUBECTL" label namespace "$NAMESPACE" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
fi

# Adopt namespaced resources in seaweedfs-system
for item in $("$KUBECTL" get all,sa,secret,configmap,role,rolebinding -n "$NAMESPACE" -o name 2>/dev/null || true); do
  if echo "$item" | grep -q "s3-https"; then
    rel="seaweedfs-cluster"
  else
    rel="seaweedfs-operator"
  fi
  "$KUBECTL" annotate "$item" -n "$NAMESPACE" meta.helm.sh/release-name="$rel" meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  "$KUBECTL" label "$item" -n "$NAMESPACE" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
done

# Adopt Seaweed CR
if "$KUBECTL" get seaweed seaweed-cluster -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "    Adopting 'seaweed-cluster' CR for Helm release seaweedfs-cluster..."
  "$KUBECTL" annotate seaweed seaweed-cluster -n "$NAMESPACE" argocd.argoproj.io/tracking-id- 2>/dev/null || true
  "$KUBECTL" annotate seaweed seaweed-cluster -n "$NAMESPACE" meta.helm.sh/release-name=seaweedfs-cluster meta.helm.sh/release-namespace="$NAMESPACE" --overwrite 2>/dev/null || true
  "$KUBECTL" label seaweed seaweed-cluster -n "$NAMESPACE" app.kubernetes.io/managed-by=Helm --overwrite 2>/dev/null || true
fi

# 4. Quiesce Immich and other CSI clients to cleanly unmount FUSE filesystems
IMMICH_DEPLOYMENTS=""
if "$KUBECTL" get ns "$IMMICH_NAMESPACE" >/dev/null 2>&1; then
  echo "[+] Quiescing Immich workloads in namespace '$IMMICH_NAMESPACE'..."
  IMMICH_DEPLOYMENTS=$("$KUBECTL" get deployment -n "$IMMICH_NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
  for dep in $IMMICH_DEPLOYMENTS; do
    "$KUBECTL" scale deployment "$dep" -n "$IMMICH_NAMESPACE" --replicas=0 || true
  done
  echo "    Waiting for Immich pods to terminate..."
  "$KUBECTL" wait --for=delete pod -l "app.kubernetes.io/instance=immich-restricted" -n "$IMMICH_NAMESPACE" --timeout=60s 2>/dev/null || true
fi

# 5. Protect Longhorn PersistentVolumes (reclaimPolicy -> Retain)
echo "[+] Protecting Longhorn PersistentVolumes (reclaimPolicy -> Retain)..."
for pvc in $LONGHORN_PVCS; do
  pv=$("$KUBECTL" get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.spec.volumeName}' 2>/dev/null || true)
  if [ -n "$pv" ]; then
    echo "    Patching PV $pv to Retain..."
    "$KUBECTL" patch pv "$pv" -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
  fi
done

BACKUP_DIR="${BACKUP_DIR:-/var/tmp/seaweedfs-migration-$(date +%s)}"
mkdir -p "$BACKUP_DIR"

# 6. Backup Volume Server Data (*.dat, *.idx, *.vif)
VOLUME_PODS=$("$KUBECTL" get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=volume" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
for pod in $VOLUME_PODS; do
  echo "[+] Backing up volume chunks from pod '$pod' (/data/*)..."
  "$KUBECTL" exec -n "$NAMESPACE" "$pod" -c volume -- tar -cf - -C /data . > "$BACKUP_DIR/${pod}.tar"
  echo "    Volume data saved to $BACKUP_DIR/${pod}.tar"
done

# 7. Backup SeaweedFS filer metadata
FILER_POD=$("$KUBECTL" get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=filer" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$FILER_POD" ]; then
  echo "[+] Backing up SeaweedFS filer data and metadata from pod $FILER_POD..."
  "$KUBECTL" exec -n "$NAMESPACE" "$FILER_POD" -c filer -- tar -cf - -C /data . > "$BACKUP_DIR/filer_data.tar" 2>/dev/null || true
  "$KUBECTL" exec -n "$NAMESPACE" "$FILER_POD" -c filer -- sh -c 'echo "fs.meta.save" | weed shell && mv *.meta /tmp/filer_backup.meta' 2>/dev/null || true
  "$KUBECTL" cp "$NAMESPACE/$FILER_POD:/tmp/filer_backup.meta" "$BACKUP_DIR/filer.meta" -c filer 2>/dev/null || true
fi

# 8. Pause SeaweedFS Operator if running
if "$KUBECTL" get deployment seaweedfs-operator -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "[+] Scaling down seaweedfs-operator during migration..."
  "$KUBECTL" scale deployment seaweedfs-operator -n "$NAMESPACE" --replicas=0 --timeout=60s || true
fi

# 9. Delete old StatefulSets with --cascade=orphan
echo "[+] Deleting existing SeaweedFS volume, filer & master StatefulSets (--cascade=orphan)..."
"$KUBECTL" delete sts seaweed-cluster-volume seaweed-cluster-filer seaweed-cluster-master -n "$NAMESPACE" --cascade=orphan --ignore-not-found

# 10. Delete old Longhorn PVCs (the PVs themselves are safe because of Retain)
echo "[+] Deleting old Longhorn PVCs (PVs are retained)..."
for pvc in $LONGHORN_PVCS; do
  "$KUBECTL" delete pvc "$pvc" -n "$NAMESPACE" --wait=false --ignore-not-found
done

# 11. Resume / trigger SeaweedFS Operator
if "$KUBECTL" get deployment seaweedfs-operator -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "[+] Scaling seaweedfs-operator back up..."
  "$KUBECTL" scale deployment seaweedfs-operator -n "$NAMESPACE" --replicas=1 || true
elif command -v systemctl >/dev/null 2>&1; then
  echo "[+] Restarting helm-chart-installer.service to deploy seaweedfs-operator..."
  systemctl restart helm-chart-installer.service || true
fi

echo "[+] Waiting for SeaweedFS cluster to spin up with local-path storage..."
"$KUBECTL" rollout status sts/seaweed-cluster-volume -n "$NAMESPACE" --timeout=300s || true
"$KUBECTL" rollout status sts/seaweed-cluster-filer -n "$NAMESPACE" --timeout=300s || true

# 12. Restore Volume Server Data (*.dat, *.idx, *.vif) into new volume pods
for tarfile in "$BACKUP_DIR"/seaweed-cluster-volume-*.tar; do
  [ -f "$tarfile" ] || continue
  pod_base=$(basename "$tarfile" .tar)
  echo "[+] Restoring volume chunks into pod '$pod_base'..."
  "$KUBECTL" wait --for=condition=Ready "pod/$pod_base" -n "$NAMESPACE" --timeout=180s || true
  cat "$tarfile" | "$KUBECTL" exec -i -n "$NAMESPACE" "$pod_base" -c volume -- tar -xf - -C /data
  echo "[+] Restarting '$pod_base' to scan restored volumes and register with master..."
  "$KUBECTL" delete pod "$pod_base" -n "$NAMESPACE"
done

echo "[+] Waiting for volume pods to finish restart..."
"$KUBECTL" rollout status sts/seaweed-cluster-volume -n "$NAMESPACE" --timeout=300s || true

# 13. Restore filer data & metadata if backup exists
NEW_FILER_POD=$("$KUBECTL" get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=seaweedfs,app.kubernetes.io/component=filer" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$NEW_FILER_POD" ]; then
  "$KUBECTL" wait --for=condition=Ready "pod/$NEW_FILER_POD" -n "$NAMESPACE" --timeout=180s || true
  if [ -f "$BACKUP_DIR/filer_data.tar" ]; then
    echo "[+] Restoring filer LevelDB data to new filer pod $NEW_FILER_POD..."
    cat "$BACKUP_DIR/filer_data.tar" | "$KUBECTL" exec -i -n "$NAMESPACE" "$NEW_FILER_POD" -c filer -- tar -xf - -C /data
    "$KUBECTL" delete pod "$NEW_FILER_POD" -n "$NAMESPACE"
  elif [ -f "$BACKUP_DIR/filer.meta" ]; then
    echo "[+] Restoring filer metadata via weed shell to $NEW_FILER_POD..."
    "$KUBECTL" cp "$BACKUP_DIR/filer.meta" "$NAMESPACE/$NEW_FILER_POD:/tmp/filer_restore.meta" -c filer
    "$KUBECTL" exec -n "$NAMESPACE" "$NEW_FILER_POD" -c filer -- sh -c 'echo "fs.meta.load /tmp/filer_restore.meta" | weed shell' || true
  fi
fi

# 14. Restart Immich workloads
if [ -n "${IMMICH_DEPLOYMENTS:-}" ]; then
  echo "[+] Restoring Immich workloads in namespace '$IMMICH_NAMESPACE'..."
  for dep in $IMMICH_DEPLOYMENTS; do
    "$KUBECTL" scale deployment "$dep" -n "$IMMICH_NAMESPACE" --replicas=1 || true
  done
fi

echo "=============================================================="
echo "[+] SeaweedFS migration to local-path complete!"
echo "    Backup files preserved at: $BACKUP_DIR"
echo "=============================================================="
