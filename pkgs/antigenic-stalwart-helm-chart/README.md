# antigenic-stalwart-helm-chart

<p align="center">
  <a href="https://github.com/Antigenic-OSS/stalwart-helm-chart/tags"><img alt="Tag" src="https://img.shields.io/github/v/tag/Antigenic-OSS/stalwart-helm-chart?sort=semver&style=flat-square"></a>
  <a href="https://github.com/stalwartlabs/mail-server/releases/tag/v0.15.5"><img alt="Stalwart App Version" src="https://img.shields.io/badge/stalwart-v0.15.5-informational?style=flat-square"></a>
  <a href="https://github.com/Antigenic-OSS/stalwart-helm-chart/actions/workflows/chart-ci.yaml"><img alt="Chart CI" src="https://img.shields.io/github/actions/workflow/status/Antigenic-OSS/stalwart-helm-chart/chart-ci.yaml?branch=main&label=chart%20ci&style=flat-square"></a>
  <a href="https://github.com/Antigenic-OSS/stalwart-helm-chart/actions/workflows/auto-tag-chart.yaml"><img alt="Auto Tag" src="https://img.shields.io/github/actions/workflow/status/Antigenic-OSS/stalwart-helm-chart/auto-tag-chart.yaml?branch=main&label=auto%20tag&style=flat-square"></a>
  <a href="https://github.com/Antigenic-OSS/stalwart-helm-chart/actions/workflows/release-chart.yaml"><img alt="Publish OCI" src="https://img.shields.io/github/actions/workflow/status/Antigenic-OSS/stalwart-helm-chart/release-chart.yaml?label=publish%20oci&style=flat-square"></a>
</p>

<p align="center">
  <a href="https://github.com/orgs/Antigenic-OSS/packages?repo_name=stalwart-helm-chart"><img alt="GHCR" src="https://img.shields.io/badge/oci-ghcr.io%2Fantigenic--oss%2Fcharts-blue?style=flat-square"></a>
  <a href="https://artifacthub.io/packages/search?repo=antigenic-stalwart-helm-chart"><img alt="Artifact Hub" src="https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/antigenic-stalwart-helm-chart&style=flat-square"></a>
  <a href="https://kubernetes.io/"><img alt="Kubernetes" src="https://img.shields.io/badge/kubernetes-supported-326ce5?style=flat-square&logo=kubernetes&logoColor=white"></a>
  <a href="https://helm.sh/"><img alt="Helm" src="https://img.shields.io/badge/helm-v3-0f1689?style=flat-square&logo=helm&logoColor=white"></a>
  <a href="https://github.com/Antigenic-OSS/stalwart-helm-chart/blob/main/LICENSE"><img alt="License" src="https://img.shields.io/github/license/Antigenic-OSS/stalwart-helm-chart?style=flat-square"></a>
</p>

Community-maintained, highly opinionated Helm chart for deploying the Stalwart Mail Server on Kubernetes.

Supports SMTP, IMAP, JMAP, PostgreSQL, Redis, S3-compatible object storage, Meilisearch, cert-manager TLS, and either Ingress, Gateway API, or a single LoadBalancer service.

This repository is maintained by [Antigenic](https://antigenic.org).

This is an unofficial, community-maintained Helm chart and is not affiliated with, endorsed by, sponsored by, or supported by Stalwart Labs. "Stalwart" and related marks are property of their respective owners.

## Table of Contents

- [Features](#features)
- [Install](#install)
  - [OCI Install (Recommended)](#oci-install-recommended)
  - [Local Checkout (Development/Testing)](#local-checkout-developmenttesting)
  - [Release Automation](#release-automation)
- [Before You Deploy](#before-you-deploy)
  - [Assumptions and Expectations](#assumptions-and-expectations)
  - [Directory Modes](#directory-modes)
  - [PostgreSQL Permissions](#postgresql-permissions)
  - [Optional: SQL Directory Mode](#optional-sql-directory-mode)
  - [External Secrets](#external-secrets)
- [GitOps Examples](#gitops-examples)
  - [Argo CD Example](#argo-cd-example)
  - [Flux Example (OCI)](#flux-example-oci)
- [Configuration](#configuration)
  - [Configuration Design Decisions](#configuration-design-decisions)
  - [Minimal Production Overrides](#minimal-production-overrides)
- [Routing and TLS](#routing-and-tls)
  - [Hostname and Routing Model](#hostname-and-routing-model)
  - [Routing (Ingress vs HTTPRoute)](#routing-ingress-vs-httproute)
  - [TLS Model (Typical Production)](#tls-model-typical-production)
- [Security and Access Control](#security-and-access-control)
  - [Proxy Protocol and Trusted Networks](#proxy-protocol-and-trusted-networks)
  - [Allowed IPs vs Blocked IPs Ownership](#allowed-ips-vs-blocked-ips-ownership)
  - [NetworkPolicy](#networkpolicy)
  - [Cilium Egress Gateway Policy](#cilium-egress-gateway-policy)
- [Observability](#observability)
  - [Prometheus Metrics](#prometheus-metrics)
- [Operational Notes](#operational-notes)
- [Community and Security](#community-and-security)
- [License and Disclaimer](#license-and-disclaimer)

## Features

- StatefulSet with per-replica `cluster.node-id` auto-injection from pod ordinal.
- Single secret source (`stalwart-secrets` by default) via `envFrom`.
- Non-secret configuration generated from a ConfigMap (`config.toml`).
- Optional Prometheus metrics auth configuration via chart values.
- Optional north-south HTTP entry via either:
  - Kubernetes `Ingress`, or
  - Gateway API `HTTPRoute` (Cilium Gateway compatible).
- Unified service for HTTP and mail protocols.

## Install

### OCI Install (Recommended)

This chart is published as an OCI artifact in GHCR.

Install:

```bash
helm install stalwart \
  oci://ghcr.io/antigenic-oss/charts/antigenic-stalwart-helm-chart \
  --version <chart-version> \
  --namespace stalwart \
  --create-namespace
```

Or upgrade/install:

```bash
helm upgrade --install stalwart \
  oci://ghcr.io/antigenic-oss/charts/antigenic-stalwart-helm-chart \
  --version <chart-version> \
  --namespace stalwart \
  --create-namespace
```

Note: OCI charts do not use `helm repo add`.

### Local Checkout (Development/Testing)

```bash
git clone https://github.com/Antigenic-OSS/stalwart-helm-chart.git
cd stalwart-helm-chart
helm upgrade --install stalwart . --namespace stalwart --create-namespace
```

### Release Automation

- Tag pushes matching `v*` publish this chart to GHCR as OCI (`ghcr.io/antigenic-oss/charts/antigenic-stalwart-helm-chart`).
- The publish workflow fails unless tag version and `Chart.yaml` version match exactly.

## Before You Deploy

### Assumptions and Expectations

This chart is intentionally opinionated and assumes you already run or will provide the following dependencies:

- PostgreSQL is deployed and reachable from the Stalwart namespace.
- Redis is deployed and reachable, and `REDIS_URL` in `stalwart-secrets` is valid.
- Meilisearch is deployed and reachable, with `MEILISEARCH_API_KEY` set if auth is enabled.
- S3-compatible object storage is deployed/reachable (AWS S3, MinIO, etc.) with working credentials.
- DNS for your mail and HTTP hostnames is already managed externally.
- Mail listener TLS is certificate-file based, and when `certManager.enabled=true` this chart creates and mounts the certificate Secret automatically.
- HTTP/JMAP/Admin/Web TLS may be terminated at the ingress/gateway layer or passed through to Stalwart, depending on your edge configuration.
- If `httpRoute.enabled=true`, Gateway API CRDs and a compatible Gateway (for example Cilium Gateway) already exist.
- If `ingress.enabled=true`, an Ingress controller already exists.
- A default `StorageClass` exists or `persistence.storageClass` is set explicitly.

Chart behavior assumptions:

- Secrets are expected in one Secret (`stalwart-secrets` by default).
- Non-secret runtime config is generated from the ConfigMap into `config.toml`.
- `cluster.node-id` is auto-assigned from StatefulSet pod ordinal via init container.
- Replica count defaults to `3`; ensure your external backing services and storage can support HA.

### Directory Modes

This chart supports two directory modes:

- `internal` (default): `storage.directory=internal` with `directory."internal"` backed by PostgreSQL. Stalwart manages its own internal tables automatically.
- `sql` (optional): `storage.directory=sql` with explicit SQL directory queries. You own schema/migrations/query behavior.

### PostgreSQL Permissions

This chart assumes PostgreSQL is externally managed.

For `internal` mode (default), no chart-managed schema bootstrap is required for directory data. Ensure the configured PostgreSQL user has sufficient permissions for Stalwart-managed DDL and DML in the target database/schema (for example `CREATE`, `ALTER`, `INDEX`, `INSERT`, `UPDATE`, `DELETE`, `SELECT`).

### Optional: SQL Directory Mode

Use this only if you intentionally want SQL directory mode.

Set:

```yaml
config:
  storage:
    directory: sql
```

In SQL mode, you must manage directory schema/migrations yourself and provide appropriate SQL queries.

The SQL query mappings under `config.postgresql.query` in this chart are examples based on Stalwart documentation and are not universally required for all deployments. Adjust them to your schema and Stalwart version requirements.

Example starter schema (for SQL directory mode only):

```sql
CREATE TABLE IF NOT EXISTS accounts (
  name TEXT PRIMARY KEY,
  secret TEXT,
  description TEXT,
  type TEXT NOT NULL,
  quota INTEGER DEFAULT 0,
  active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS group_members (
  name TEXT NOT NULL,
  member_of TEXT NOT NULL,
  PRIMARY KEY (name, member_of)
);

CREATE TABLE IF NOT EXISTS emails (
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  type TEXT,
  PRIMARY KEY (name, address)
);
```

### External Secrets

If you want to manage secrets outside Helm, set `secret.create=false` and create `stalwart-secrets` up front:

```bash
kubectl create namespace stalwart --dry-run=client -o yaml | kubectl apply -f -

kubectl -n stalwart apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: stalwart-secrets
type: Opaque
stringData:
  ADMIN_SECRET: "<strong-password>"
  POSTGRES_PASSWORD: "<postgres-password>"
  S3_ACCESS_KEY: "<s3-access-key>"
  S3_SECRET_KEY: "<s3-secret-key>"
  MEILISEARCH_API_KEY: "<meili-api-key>"
  REDIS_URL: "redis://user:pass@redis:6379"
  # Optional: required only if config.metrics.prometheus.enable=true
  # PROMETHEUS_SECRET: "<strong-metrics-password>"
EOF
```

## GitOps Examples

### Argo CD Example

Copy and edit:

- `examples/argocd/application.yaml`

Then apply:

```bash
kubectl apply -f examples/argocd/application.yaml
```

Notes:

- This example uses GHCR OCI (`ghcr.io/antigenic-oss/charts`) rather than a Git path.
- Ensure your Argo CD Helm repository configuration has OCI enabled for GHCR.

### Flux Example (OCI)

Copy and edit:

- `examples/flux/namespace.yaml`
- `examples/flux/helmrepository.yaml`
- `examples/flux/helmrelease.yaml`
- `examples/flux/kustomization.yaml`

Then apply:

```bash
kubectl apply -k examples/flux
```

Notes:

- This example pulls the chart from GHCR OCI (`oci://ghcr.io/antigenic-oss/charts`).
- It expects `stalwart-secrets` to already exist (`secret.create=false`).

## Configuration

### Configuration Design Decisions

Default backend choices in this chart:

- Redis as cluster coordinator (`cluster.coordinator = redis`).
- PostgreSQL as primary data store (`storage.data = postgresql`).
- S3-compatible storage for blobs (`storage.blob = s3`).
- Redis for lookup paths (`storage.lookup = redis`).
- Meilisearch for full-text indexing/search (`storage.fts = meilisearch`).
- Default INTERNAL directory backed by PostgreSQL (`storage.directory = internal`); optional SQL directory mode is available when explicitly set.

What this gives you:

- HA-friendly, stateful replicas with stable identity.
- Durable structured data in PostgreSQL and scalable object storage for blobs.
- Fast coordination/lookup via Redis.
- External search engine performance for message search workloads.
- Clear config split: one Secret for sensitive values, ConfigMap for everything else.
- Flexibility to switch to SQL directory mode when you explicitly need custom directory schema/query behavior.

### Minimal Production Overrides

```yaml
replicaCount: 3

secret:
  data:
    ADMIN_SECRET: "<strong-password>"
    POSTGRES_PASSWORD: "<postgres-password>"
    S3_ACCESS_KEY: "<s3-access-key>"
    S3_SECRET_KEY: "<s3-secret-key>"
    MEILISEARCH_API_KEY: "<meili-api-key>"
    REDIS_URL: "redis://user:pass@redis:6379"

config:
  server:
    hostname: mail.example.com
  http:
    url: "protocol + '://' + config_get('server.hostname') + ':' + local_port"
  postgresql:
    host: postgres-rw.database.svc.cluster.local
    database: stalwart
    user: stalwart
  s3:
    endpoint: https://minio.storage.svc.cluster.local:9000
    bucket: stalwart
  meilisearch:
    url: https://meilisearch.search.svc.cluster.local:7700
```

`config.http.url` must use Stalwart expression syntax, for example:

```yaml
config:
  http:
    url: "protocol + '://' + config_get('server.hostname') + ':' + local_port"
```

Default tracer configuration is enabled for both file and console outputs, and can be overridden in values:

```yaml
config:
  tracer:
    log:
      type: log
      path: /opt/stalwart/logs
      prefix: stalwart.log
      rotate: daily
      level: info
      ansi: true
      enable: true
    console:
      type: console
      level: info
      ansi: true
      enable: true
```

Use an absolute path for `config.tracer.log.path` (for example `/opt/stalwart/logs`).

Optional OpenTelemetry tracer (disabled by default):

```yaml
config:
  tracer:
    otel:
      type: open-telemetry
      transport: grpc
      endpoint: https://otel-collector.observability.svc.cluster.local:4317
      headers:
        - "x-tenant-id: mail-prod"
      level: info
      enableLogExporter: false
      enableSpanExporter: true
      throttle: 1s
      lossy: false
      enable: true
```

## Routing and TLS

### Hostname and Routing Model

This chart uses a single Service (`*-mail`) for both mail and HTTP ports.

Hostname routing is still separate by protocol:

- Mail hostname: `config.server.hostname` for SMTP/IMAP/Submission/Sieve traffic.
- HTTP hostname: `ingress.hosts` or `httpRoute.hostnames` for JMAP/Admin/Web traffic.
- `config.http.url` is set as a Stalwart expression string (not a plain `https://...` URL).

Both routing planes must be configured:

- Mail routing must reach the `*-mail` Service (`25`, `587`, `465`, `143`, `993`, `4190`).
- HTTP routing can use either:
  - plain HTTP on `service.http.port` (`8080` by default, when `service.http.enabled=true`), or
  - HTTPS on `443` only (when `service.http.enabled=false`).

If only one is routed, deployment is only partially reachable.

MTA-STS note:

- Depending on your domain/routing configuration, you may need to open Stalwart WebAdmin and go to `MTA-STS Policy`.
- Override the MX patterns there so MTA-STS validation checks pass for your deployment.

WebAdmin vs Helm note:

- Many runtime settings can be managed directly in Stalwart WebAdmin, as long as they are not constrained by `config.localKeys`.
- Prefer testing configuration changes in WebAdmin first for operational tuning, then promote stable changes into Helm values when needed.

### Routing (Ingress vs HTTPRoute)

Enable exactly one:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: mail.example.com
      paths:
        - path: /
          pathType: Prefix
```

or

```yaml
httpRoute:
  enabled: true
  hostnames:
    - mail.example.com
  parentRefs:
    - name: cilium-gateway
      namespace: kube-system
      sectionName: https
```

Or disable both and expose the built-in unified `LoadBalancer` Service (`*-mail`) directly for both HTTP and mail traffic.

To disable plain HTTP (`8080`) completely and serve only HTTPS:

```yaml
service:
  http:
    enabled: false
```

When `service.http.enabled=false`, this chart removes port `8080` from listeners/services/policies and health checks are performed over HTTPS (`443`).
`ingress.enabled=true` and `httpRoute.enabled=true` require `service.http.enabled=true` because they route to the plain HTTP backend service port.

### TLS Model (Typical Production)

When using Gateway API (for example Cilium Gateway), a common production pattern is to use both TLS models at the same time:

- Gateway/`HTTPRoute` TLS termination for web endpoints (JMAP/Admin/Web over HTTP/HTTPS).
- Stalwart listener TLS for mail protocols (`25`, `587`, `465`, `143`, `993`, `4190`).

Important: Gateway TLS does not secure the mail listeners. Mail listeners still require certificates managed by Stalwart.

Typical approaches:

- Keep `httpRoute.enabled=true` (or `ingress.enabled=true`) for north-south HTTP routing.
- Or keep both `ingress.enabled=false` and `httpRoute.enabled=false` and use a single `LoadBalancer` Service for both mail and HTTP.
- Enable `certManager.enabled=true` to have this chart create the `Certificate`, mount the TLS Secret, and render the certificate file references in `config.toml`.

Example cert-manager values:

```yaml
certManager:
  enabled: true
  issuerName: letsencrypt-dns
  secretName: stalwart-mail-tls
  mountPath: /opt/stalwart/certs
  # Optional: defaults to [config.server.hostname] when empty
  dnsNames: []
  certificate:
    name: default
    certFile: tls.crt
    keyFile: tls.key
    default: true
```

Rendered `config.toml` snippet:

```toml
[server]
tls.certificate = "default"

[certificate."default"]
cert = "%{file:/opt/stalwart/certs/tls.crt}%"
private-key = "%{file:/opt/stalwart/certs/tls.key}%"
default = true
```

cert-manager `Certificate` example:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: stalwart-mail-cert
  namespace: stalwart
spec:
  secretName: stalwart-mail-tls
  issuerRef:
    name: letsencrypt-dns
    kind: ClusterIssuer
    group: cert-manager.io
  dnsNames:
    - mail.example.com
```

This chart intentionally keeps a unified Service model to reduce operational complexity around external LBs and routing.

Certificate mount note:

- This chart mounts generated config at `/opt/stalwart/etc` as read-write.
- When `certManager.enabled=true`, cert-manager secret files are mounted read-only at `certManager.mountPath` automatically.
- Ensure cert-manager is installed and the configured issuer exists before deploying with `certManager.enabled=true`.
- You typically do not need to customize mount paths, certificate file names, or TLS config wiring unless you have non-default requirements.
- This cert-manager model works with any replica count because all pods read the same TLS Secret.

## Security and Access Control

### Proxy Protocol and Trusted Networks

When running behind a load balancer (for example Hetzner LB), configure proxy trust and access policy explicitly.

Global proxy settings (applies to all listeners by default):

```yaml
config:
  proxy:
    trustedNetworks:
      - 10.0.64.131/32
```

Service-group override (`mail` vs `http`):

```yaml
config:
  proxy:
    byService:
      mail:
        - 10.0.64.131/32
      http: []
```

Mail+HTTP LB listener limits (for providers such as Hetzner):

```yaml
service:
  mail:
    enabled:
      smtp: true
      submission: true
      smtps: true
      imap: false
      imaps: true
      sieve: true
```

By default this chart exposes HTTP (`service.http.port`) and HTTPS (`443`) on the same Service.
Set `service.http.enabled=false` to remove HTTP (`8080`) entirely.
Hetzner-specific sizing guidance:

- `lb11` can be enough for reduced listener sets (for example when both `imap` and `sieve` are disabled).
- If you keep broader listener coverage (especially with IMAP/Sieve enabled), use `lb21`.
- This guidance is specific to Hetzner LB listener limits; other providers have different limits.

Use `lb21` on Hetzner when needed:

```yaml
service:
  mail:
    annotations:
      load-balancer.hetzner.cloud/type: "lb21"
```

Hetzner health check note (HTTPS-only mode):

- This applies when plain HTTP is disabled (`service.http.enabled=false`).
- In that mode, Hetzner health checks may remain unhealthy unless the LB check protocol is set to HTTPS.
- Set:

```yaml
service:
  mail:
    annotations:
      load-balancer.hetzner.cloud/health-check-protocol: "https"
```

Per-listener trusted networks (optional override):

```yaml
config:
  listeners:
    smtp:
      trustedNetworks:
        - 10.0.64.131/32
```

Server allowlist:

```yaml
config:
  server:
    allowedIPs:
      - 10.0.64.131
```

Important gotcha:

- `trustedNetworks` and `allowedIPs` are different controls:
  - `trustedNetworks` tells Stalwart which proxy/LB sources are trusted to forward client IP metadata.
  - `allowedIPs` is an access policy allowlist.
- Behind a proxy/LB, set both:
  - trusted proxy source CIDRs (`config.proxy.trustedNetworks`, `config.proxy.byService.<mail|http>`, and/or per-listener `trustedNetworks`), and
  - LB source addresses in `config.server.allowedIPs`.
- `externalTrafficPolicy: Local` is not required for proxy protocol. Default `Cluster` is usually more robust for node health/rollouts.
- Blocked IP management is intentionally not chart-managed. Configure blocked addresses in Stalwart WebAdmin so they are persisted in the database.

### Allowed IPs vs Blocked IPs Ownership

- `config.server.allowedIPs` is chart-managed and rendered into `config.toml` as `[server.allowed-ip]`.
- `server.blocked-ip` is intentionally not managed by this chart.
- Set blocked IPs in Stalwart WebAdmin so they are stored in the database and preserved as application state.
- Do not set blocked IPs via Helm values.

### NetworkPolicy

If `networkPolicy.enabled=true`, this chart keeps services internet-reachable by default (`allowInternet=true` with `0.0.0.0/0` and `::/0`), while still allowing in-namespace traffic.

This is a compatibility-first default, not a strict zero-trust posture.

Harden this by replacing `networkPolicy.ingress.internetCidrs` and/or using `networkPolicy.ingress.additionalFrom` for your specific ingress/LB source ranges, and by restricting egress rules to required dependencies.

### Cilium Egress Gateway Policy

If you run Cilium with the `CiliumEgressGatewayPolicy` CRD installed, this chart can optionally render a dedicated egress gateway policy for the Stalwart pods.

Enable it with values like:

```yaml
ciliumEgressGatewayPolicy:
  enabled: true
  name: stalwart-egress-ipv4
  destinationCIDRs:
    - 0.0.0.0/0
  egressGateway:
    nodeSelector:
      matchLabels:
        egress-node: "true"
    egressIP: 203.0.113.10
```

By default, the chart targets the Stalwart pods using this chart's own selector labels. If you need a different Cilium selector shape, set `ciliumEgressGatewayPolicy.selectors` directly.

## Observability

### Prometheus Metrics

Enable Prometheus metrics auth in Stalwart config:

```yaml
secret:
  data:
    PROMETHEUS_SECRET: "<strong-metrics-password>"

config:
  metrics:
    prometheus:
      enable: true
      auth:
        username: prometheus
```

Rendered `config.toml` entries:

```toml
[metrics.prometheus]
enable = true

[metrics.prometheus.auth]
username = "prometheus"
secret = "%{env:PROMETHEUS_SECRET}%"
```

Optional OpenTelemetry metrics exporter (disabled by default):

```yaml
config:
  metrics:
    openTelemetry:
      enable: true
      transport: grpc
      endpoint: https://otel-collector.observability.svc.cluster.local:4317
      interval: 1m
      headers:
        - "x-tenant-id: mail-prod"
```

Rendered `config.toml` entries:

```toml
[metrics.open-telemetry]
transport = "grpc"
endpoint = "https://otel-collector.observability.svc.cluster.local:4317"
interval = "1m"
headers = ["x-tenant-id: mail-prod"]
```

## Operational Notes

- If `secret.create=false`, the chart expects `secret.name` to already exist.
- Persistent storage defaults to a PVC per pod via `volumeClaimTemplates`.

## Community and Security

- Contribution guide: `CONTRIBUTING.md`
- Security reporting: `SECURITY.md`
- Support expectations and contacts: `SUPPORT.md`
- Community standards: `CODE_OF_CONDUCT.md`

## License and Disclaimer

- Licensed under the MIT License. See `LICENSE`.
- Provided as-is, with no warranty or guarantee of fitness for production.
- You are responsible for security hardening, backups, disaster recovery, and operational validation in your environment.
