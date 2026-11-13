# Cluster Root CA Migration Runbook (Colmena-Driven)

This runbook documents the procedure for migrating or rotating a cluster's internal Root CA (`app-pki-bootstrap`) across control-plane nodes and Kubernetes workloads.

It is designed to be executed during a maintenance window with planned downtime. The entire procedure completes in under 10 minutes.

---

## 1. Architectural Background

In the Library of Alexandria architecture:
- **`pki-bootstrap`** is a foundational Helm chart deployed at the **NixOS system level via Colmena / RKE2 auto-deploy manifests** (`modules/submodules/k8s/control-plane/trust-manager.nix`), **not** via ArgoCD.
- The Root CA Common Name is dynamically qualified with the cluster name (`commonName: app-pki-bootstrap-<cluster>`), preventing Subject Distinguished Name collisions when federating cross-cluster trust (e.g. between cluster `k` and cluster `g`).
- **`trust-manager`** automatically syncs the Root CA into the cluster-wide ConfigMap `trusted-ca-bundle` (`ca-bundle.crt`) in every namespace.
- **`cert-manager`** uses `ClusterIssuer/app-pki-bootstrap-issuer` to issue all workload certificates (Ingress/Gateway TLS, KeyDB/pgEdge client CAs, observability, and application mTLS).

---

## 2. Prerequisites & Code Configuration

The required chart templates in `master` are already parameterized:
1. `pkgs/pki-bootstrap-helm/templates/app-cluster-issuer.yml`:
   ```yaml
   commonName: app-{{ .Release.Name }}-{{ .Values.cluster.name | default "root" }}
   ```
2. `modules/submodules/k8s/control-plane/trust-manager.nix`:
   ```nix
   {
     name = "pki-bootstrap";
     chart = "${pkgs.pki-bootstrap-helm}/pki-bootstrap-helm-0.1.0.tgz";
     values = {
       cluster.name = config.libraryofalexandria.cluster.name;
     };
     namespace = "cert-manager";
   }
   ```

---

## 3. Execution Procedure (Cluster `g`)

Replace `g` with the target cluster name if executing elsewhere.

### Step 1: Deploy Master Nodes via Colmena
Deploy the updated RKE2 auto-deploy manifests to the control-plane nodes sequentially:

```bash
# From repository root (or builder VM):
nix run .#apps.aarch64-linux.colmena -- apply --on master0-g -v --show-trace
nix run .#apps.aarch64-linux.colmena -- apply --on master1-g -v --show-trace
nix run .#apps.aarch64-linux.colmena -- apply --on master2-g -v --show-trace
```

### Step 2: Trigger Helm Chart Update
Delete the completed `helm-install-pki-bootstrap` Job in `kube-system` so RKE2's Helm controller runs the chart upgrade:

```bash
kubectl delete job -n kube-system helm-install-pki-bootstrap

# Wait for the upgrade job to complete
kubectl wait --for=condition=complete job/helm-install-pki-bootstrap -n kube-system --timeout=60s

# Verify Certificate spec updated to app-pki-bootstrap-g
kubectl get certificate -n cert-manager app-pki-bootstrap -o jsonpath='{.spec.commonName}'
# Expected output: app-pki-bootstrap-g
```

### Step 3: Rotate the Root CA Secret
Delete the existing root CA secret. `cert-manager` will immediately generate a fresh keypair and root certificate with the new Common Name:

```bash
kubectl delete secret -n cert-manager app-pki-bootstrap-secret

# Wait for cert-manager to issue the new root secret
kubectl wait --for=condition=Ready certificate/app-pki-bootstrap -n cert-manager --timeout=30s

# Verify Subject and Issuer
kubectl get secret app-pki-bootstrap-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -issuer
# Expected output:
# subject=CN=app-pki-bootstrap-g
# issuer=CN=app-pki-bootstrap-g
```

### Step 4: Force Re-sync of `trusted-ca-bundle`
Prompt `trust-manager` to distribute the new root certificate into `ca-bundle.crt` in every namespace:

```bash
kubectl annotate bundle trusted-ca-bundle reconcile="$(date +%s)" --overwrite

# Verify default namespace received the new CA in ca-bundle.crt
kubectl get configmap trusted-ca-bundle -n default -o jsonpath='{.data.ca-bundle\.crt}' | openssl x509 -noout -subject
```

### Step 5: Wipe Leaf Secrets Across Namespaces
Delete existing certificate secrets so `cert-manager` immediately re-issues them under the new root CA:

```bash
# Delete all leaf secrets across all namespaces (excluding root CA and wazuh root)
kubectl get certificate -A -o json | jq -r '.items[] | select(.spec.secretName != "app-pki-bootstrap-secret" and .spec.secretName != "wazuh-root-secret") | "kubectl delete secret -n " + .metadata.namespace + " " + .spec.secretName + " 2>/dev/null || true"' | sh

# Delete intermediate client CA keypairs in cert-manager
kubectl delete secret -n cert-manager keydb-client-ca-key-pair pgedge-*-client-ca-key-pair 2>/dev/null || true
```

Monitor re-issuance until all certificates are ready:
```bash
# Poll until all certificates show READY: True
kubectl get certificate -A
```

### Step 6: Restart Workloads to Load New Credentials
Restart application workloads across namespaces so their in-memory TLS listeners reload the renewed certificates:

```bash
for ns in observability radar cert-manager matrix gitea mastodon unifi keydb pgedge urls mail speedtest-tracker syncthing archivebox paperless; do
  echo "Restarting workloads in $ns..."
  kubectl rollout restart deployment,statefulset -n "$ns" 2>/dev/null || true
done
```

---

## 4. Post-Migration Verification

```bash
# 1. Verify Gateway TLS handshake & Issuer
curl -vk https://grafana.g.loa.internal/login 2>&1 | grep -E "issuer:|HTTP/"
# Expected: issuer: CN=app-pki-bootstrap-g, HTTP/1.1 200 OK

# 2. Verify Radar MCP
curl -vk https://cluster.g.loa.internal/mcp -H "Host: localhost" 2>&1 | grep -E "issuer:|HTTP/"
# Expected: issuer: CN=app-pki-bootstrap-g, HTTP/1.1 405 Method Not Allowed

# 3. Check for any failing certificate resources
kubectl get certificate -A | grep -v "True"
# Expected: only headers returned
```

---

## 5. Rollback Plan

If rollback is necessary:
1. Revert `commonName` in `pkgs/pki-bootstrap-helm/templates/app-cluster-issuer.yml` back to `app-{{ .Release.Name }}`.
2. Commit, push, and re-apply Steps 1–6. `cert-manager` will re-issue the previous naming scheme.
