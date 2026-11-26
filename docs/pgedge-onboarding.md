
# pgEdge federated app onboarding

Phase 1: The "Uniform" Foundation (KRO)

Apply these resources to ALL nodes (A-rw, B-rw, A-r).

    KRO: Create PrivateSchema (which creates the schema and enables the spock extension).

    Job: Run spock.node_create on all nodes.

Phase 2: Cluster A Launch (The "Prime" Mover)

    Job: Enable Subscription Node A-r --> Node A-rw (Replica follows A).

    App A: Deploy & Run Migrations.

        Result: Tables created on A-rw.

        Result: Spock immediately copies tables to A-r.

Phase 3: Cluster B Launch (The "Joiner")

    Job: Enable Subscription Node B-rw --> Node A-rw.

        Result: This is the critical sync. B-rw pulls the table definitions from A-rw.

    Job: Enable Subscription Node A-rw --> Node B-rw.

        Result: Bi-directional link established.

    Job: Enable Subscription Node A-r --> Node B-rw (Optional).

        Result: Replica now pulls from both active nodes (High Availability for the replica).

    App B: Deploy.

        Result: Connects to B-rw. Sees tables exist. Skips migrations. Ready for traffic.

## Image and extension compatibility

`pgedge.imageName` in `apps/loa-federation/values.yaml` pins a multi-architecture
image digest (PostgreSQL 17.11, Spock 5.0.13, pgvector 0.8.7). The pgEdge
Application passes it to each CNPG Cluster explicitly; do not inherit the
upstream mutable `17-spock5-standard` tag. `IfNotPresent` is safe with a digest,
but a mutable tag can select different cached binaries on different nodes.

After the November 2026 reboot, cluster k's primary and one replica had
pgvector 0.8.1 / Spock 5.0.8 binaries while the database catalogs recorded
0.8.7 / 5.0.13. The remaining replica supplied the compatible pinned image.
Do not edit `pg_extension.extversion`, drop extensions, or recreate Immich's
database to bypass this mismatch.

Publish the repository change and sync `loa-federation`, then
`pgedge-restricted`. This rolls the shared database cluster and may briefly
disconnect clients; the default pin also applies to other federated clusters.
Check every instance, not only the current primary:

```bash
kubectl -n pgedge get cluster main-k-data
for pod in $(kubectl -n pgedge get pods -l cnpg.io/cluster=main-k-data -o name); do
  echo "$pod"
  kubectl -n pgedge exec "$pod" -c postgres -- psql -X -d immich -c \
    "SELECT name, default_version, installed_version
     FROM pg_available_extensions WHERE name IN ('vector', 'spock');"
done
kubectl -n immich rollout status deployment/immich-restricted-server --timeout=180s
```

The available and installed versions must match on all instances. Immich's
crash-looping server retries automatically once compatible binaries are serving
the read-write Service.

## Interpreting database DNS NXDOMAINs

Immich connects to `main-k-data-rw.pgedge.svc` with the pod's DNS search path
and `ndots:5`. NXDOMAIN responses for candidates such as
`main-k-data-rw.pgedge.svc.immich.svc.cluster.local.` or the absolute
`main-k-data-rw.pgedge.svc.` are expected. The canonical name
`main-k-data-rw.pgedge.svc.cluster.local.` must resolve to the read-write
Service's ClusterIP, even during a primary change; this is not a headless Service.

For an intermittent failure, capture the exact query name, response code,
timestamp, client node, and answering DNS server. From a DNS-equipped client
pod, query the canonical name directly against each CoreDNS pod IP, the
`kube-dns-upstream` Service, and the node-local cache to distinguish authoritative
failures from cached negatives:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
kubectl -n kube-system get svc kube-dns-upstream
kubectl -n pgedge get svc main-k-data-rw
# Run inside the client pod, substituting each DNS server IP:
dig @DNS_SERVER_IP main-k-data-rw.pgedge.svc.cluster.local. A
```

The recovery investigation found successful canonical-name answers across both
CoreDNS replicas and three client nodes, but did not localize the reported
intermittent fault. No CoreDNS configuration change was made.
Do not change `DB_URL` to the canonical name without also adding that name to
the pgEdge server certificate: Immich uses `sslmode=verify-full`, and the
current certificate lists the shorter `.svc` identity.

## CNPG pod security overrides

Set `podSecurityContext` and `securityContext` directly under each node's
`clusterSpec`, not under `image`. The installed CNPG 1.28 CRD supports these
fields; it prunes the unsupported `spec.image` block, causing persistent ArgoCD
drift. The explicit contexts match the operator's enforced settings: UID/GID 26,
non-root execution, RuntimeDefault seccomp, no privilege escalation, a read-only
container root filesystem, and all capabilities dropped.