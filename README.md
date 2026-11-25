# Library of Alexandria

The Library of Alexandria is a declarative deployment repository for a multi-node Kubernetes cluster and underlying NixOS infrastructure. It utilizes Nix Flakes to provide a fully reproducible configuration of OS images, distributed nodes, and containerized applications.

The deployment relies on several key technologies:
- **[Nix / NixOS](https://nixos.org/)**: Foundation for the deterministic OS configuration and reproducible packages.
- **[Colmena](https://github.com/zhaofengli/colmena)**: Deployment tool for provisioning NixOS configurations across remote hosts.
- **[Disko](https://github.com/nix-community/disko)**: Declarative disk partitioning and formatting for the cluster nodes.
- **[KRO (Kube Resource Orchestrator)](https://kro.run/)**: Lightweight, declarative engine for managing complex resource graphs and custom APIs directly from Kubernetes.
- **[ArgoCD](https://argoproj.github.io/cd/)**: Declarative GitOps continuous delivery tool for Kubernetes, acting as the primary application controller for the cluster.
- **[Cert-Manager](https://cert-manager.io/) & [Trust-Manager](https://cert-manager.io/docs/trust/trust-manager/)**: Automated certificate issuing, management, and cluster-wide trust bundle distribution.
- **[Longhorn](https://longhorn.io/)**: Distributed block storage system providing persistent volumes for stateful applications.
- **[Cilium](https://cilium.io/) & [FRR](https://frrouting.org/)**: eBPF-based container networking, BGP control plane, and dynamic routing for multi-cluster federation.
- **[pgEdge](https://www.pgedge.com/)**: Multi-master active-active PostgreSQL database replication (via Spock) for cross-cluster relational data synchronization.
- **[KeyDB](https://docs.keydb.dev/)**: Multi-master active-active in-memory caching and session store synchronized across federated clusters.
- **[SeaweedFS](https://github.com/seaweedfs/seaweedfs)**: Distributed file and object storage system with automated cross-cluster folder and S3 bucket replication (`SyncFolder` and `PeerBucket` KRO abstractions).
- **[Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)**: Edge ingress tunnels providing public Anycast routing, global failover, and DDoS protection for residential clusters.

## Multi-Cluster Federation

The Library of Alexandria optionally connects independent, geographically distributed Kubernetes clusters into a unified mesh without relying on centralized VPN controllers or static routing tables.

### How Federation Works

1. **Decentralized Layer 3 Overlay (`p2p-vpn`)**: Each cluster runs a gateway pod containing `p2p-vpn`, a custom `libp2p`-based peer-to-peer VPN. The gateway joins a private DHT over a dedicated VPN subnet (`10.255.255.0/24`), seamlessly performing NAT traversal across residential networks. Cryptographic security is maintained via ML-DSA-87 signatures issued by a central CA (`ca.pub`), node identity keys (`identity.key`), and a strict Peer ID whitelist.
2. **Dynamic BGP Mesh (FRR Sidecar)**: Running alongside `p2p-vpn` in the gateway pod is an **FRR (Free Range Routing)** sidecar executing eBGP across the P2P overlay. Each cluster operates with its own Autonomous System Number (ASN derived from its Cluster ID) and advertises its local Pod and Service CIDRs into the mesh automatically without requiring manual route management for remote peers.
3. **eBPF Datapath Integration (Cilium BGP Control Plane)**: The FRR sidecar establishes an internal BGP peering session with Cilium's BGP Control Plane on each node. Cilium receives the remote cluster routes from FRR and programs the host eBPF datapath on every node to route cross-cluster traffic directly to the local `p2p-vpn` gateway.
4. **Global Anycast & Active-Standby Services**: With Layer 3 connectivity established, Cilium Cluster Mesh annotations (`io.cilium/global-service: "true"`) enable global Anycast load balancing across clusters, as well as automatic active-standby failover for stateful workloads without split-brain scenarios.
5. **Multi-Master Relational & Cache Replication (pgEdge & KeyDB)**:
   - **pgEdge (Spock)**: Enables multi-master active-active PostgreSQL database replication over the `p2p-vpn` overlay. By utilizing logical replication (`wal_level: logical`, `track_commit_timestamp: on`), applications read and write locally with minimal latency while maintaining synchronized relational data across clusters.
   - **KeyDB**: Serves as an active-active multi-master distributed key-value cache and session store across clusters. Communicating over TLS-encrypted mesh links, KeyDB synchronizes user sessions, rate limits, and ephemeral data in real time across nodes.
6. **Distributed Object & File Storage Replication (SeaweedFS)**:
   - **SeaweedFS Filer Sync**: Manages distributed file storage and S3 bucket replication across clusters using custom KRO Resource Graph Definitions (`SyncFolder` and `PeerBucket`).
   - Dedicated `weed filer.sync` containers run over TLS to continuously replicate shared directories and S3 buckets (e.g. Immich media, Gitea storage, Paperless documents, Stalwart mail, and Loki logs) between cluster filers.
7. **Edge Ingress & Public Routing (Cloudflare Tunnels)**: To expose HTTP/HTTPS workloads publicly without revealing residential IP addresses or requiring public BGP Anycast allocations, clusters deploy **Cloudflare Tunnels (`cloudflared`)**. Outbound-only tunnels connect each cluster to Cloudflare's edge, allowing Cloudflare's global network to automatically route users to the nearest healthy cluster.

For full architectural diagrams, key generation steps, and configuration details, see the **[P2P VPN & BGP Federation Documentation](docs/p2p-vpn-bgp-federation.md)**.

## Documentation

All project documentation is accessible via the **[Documentation Index](docs/index.md)** (or [`docs/README.md`](docs/README.md) for GitHub directory browsing):

### Architecture & Networking
* **[P2P VPN & BGP Federation Architecture](docs/p2p-vpn-bgp-federation.md)** — Multi-cluster L3 overlay, eBGP dynamic routing with FRR, and Cilium eBPF integration.
* **[DNS Tools Architecture & Guide](docs/dns-tools.md)** — Dual-DNS strategy using internal PowerDNS (`hostdns`) and public Cloudflare Dynamic DNS (`cloudflare-externaldns`).

### Applications & Services
* **[Sipcord & Asterisk Setup Guide](docs/sipcord-setup.md)** — Integrating Asterisk `ConfBridge` channels with the Sipcord Discord voice bridge.
* **[Akri & Home Assistant Implementation](docs/akri-ha-implementation.md)** — USB device discovery using Akri udev handler for Home Assistant.
* **[pgEdge Federated App Onboarding Guide](docs/pgedge-onboarding.md)** — Multi-cluster PostgreSQL replication and schema synchronization using KRO and Spock.

### Operations & Troubleshooting
* **[SSH Development Setup](docs/ssh-dev-readme.md)** — Port forwarding, reverse SSH tunnels, and dev environment connections.
* **[Finding Minecraft PVC Volume Replicas](docs/find-minecraft-pvc.md)** — Script for locating active Minecraft volume replicas in Longhorn storage.
* **[Unborking Raspberry Pi Installs](docs/unbork-rpi-installs.md)** — Emergency network recovery and etcd cluster reset commands.
* **[YubiKey PAM Onboarding](docs/yubikey-onboarding.md)** — Registering YubiKey U2F tokens with host PAM configurations.
* **[ESO Helm Templating Notes](docs/eso-helm-woes.md)** — Escaping Go templates in External Secrets Operator Helm manifests.
* **[Known Installation Bugs](docs/known-install-bugs.md)** — Notes on handling RKE2 Helm install job ordering.

## Repository Structure

- `apps/`: Contains definitions for Kubernetes applications deployed to the clusters. They are grouped logically:
  - `loa-authn/`: Authentication and identity related apps.
  - `loa-core/`: Core infrastructure and initial resources for the Library of Alexandria.
  - `loa-extras/`: Additional apps padding the core deployment.
  - `loa-federation/`: Cross-cluster or external services federation (e.g., pgEdge).
  - `loa-observability/`: Logging, monitoring, and tracing stacks.
  - `loa-voip/`: Voice over IP systems and comms applications.
- `clusters/`: Cluster-specific configurations and node definitions.
- `docs/`: Comprehensive project documentation and architecture guides (see [docs/index.md](docs/index.md)).
- `lib/`: Shared custom Nix libraries containing helper functions used across the module systems.
- `modules/`: Assorted NixOS and application modules applied to hosts and clusters.
- `pkgs/`: Custom Nix derivations and local package overlays for project-specific binaries.
- `tests/`: Automated configuration and infrastructure tests.

## Utility Scripts

Several root-level helper scripts simplify operational tasks:

- `./update-charts.sh <cluster_name>`: Evaluates and locks Helm charts for a given cluster. It fetches remote Helm repositories, resolves container images, and stores integrity hashes using `nix-prefetch-docker` into a `charts-lock.json` file for reproducible air-gapped evaluation.
- `./gen-keys.sh` / `./link-keys.sh`: Utilities for managing and linking secrets related to the cluster deployments.

## Usage

### OvenMediaEngine access and encrypted streaming

The dashboard is **HTTPS-only** at `https://catcher.k.loa.internal:8080/` on the LAN/VPN.
Trust the cluster CA (`app-pki-bootstrap-k`) on your client; it issues the dashboard's internal-domain certificate.
The public media certificate remains separate. Do not enter dashboard credentials over HTTP or bypass certificate warnings.

The dashboard user defaults to `admin`. Retrieve its generated password with an authorized cluster context:

```bash
kubectl -n ovenmediaengine get secret ovenmediaengine-access \
  -o jsonpath='{.data.dashboard-password}' | base64 --decode
```

The `ovenmediaengine-access` Secret contains four independent generated credentials: `dashboard-password`,
`stream-key` (the URL-signing master key), `api-token` (OME management API), and `srt-passphrase` (AES transport encryption).
They are required: missing credentials prevent startup rather than falling back to known defaults.
Keep this Secret out of Git. With `auth.autoGenerate: false`, provision all four keys yourself before deployment.

Sign in, select a stream name, leave validity at **Never expires**, then select **Generate signed URLs**.
Copy the complete RTMPS, encrypted SRT, or WHIP URL into your sender.
For OBS RTMPS, use the generated **OBS Server** and **OBS Stream Key** separately; leave OBS's username/password authentication disabled.
The stream key includes `policy` and `signature` query parameters: the bare name `live` is not a credential.
For SRT, use the complete URL, including the encoded `streamid`, `passphrase`, and `pbkeylen=32`; leave OBS's stream-key field blank.

Signed URLs are bearer credentials bound to one URL and stream. Do not modify their hostname, port, scheme, path, or signed query parameters.
New publishing keys do not expire by default. OME requires a timestamp, so permanent keys use its maximum unsigned 64-bit expiry.
They are stable across regeneration and rollouts while the signing secret, hostname, port, and stream name remain unchanged.
Treat them like passwords: rotating `stream-key` revokes every signed publishing URL.
Optional timed URLs (1 hour, 24 hours, or 7 days) still expire for new connections; established streams continue.
Existing timed URLs do not become permanent: generate replacements with **Never expires**.
The master signing key never reaches the browser. Rollouts still disconnect sessions, but senders can reconnect with permanent keys.
RTMPS and WHIP use TLS; SRT publishing and playback require AES-256 encryption.
WebRTC media uses DTLS-SRTP. Unsigned, tampered, and expired publishing URLs are rejected.

Playback authorization is separate: HTTPS HLS/LL-HLS and WSS/WebRTC viewers need no publishing key or dashboard login.
Use the public media hostname `catcher.k.kpt.link:3334` so its certificate matches; internal DNS must resolve that name to a reachable media address.
Encrypted SRT playback URLs are provided alongside the signed ingest URLs and contain the SRT transport passphrase.
The preview loads `/llhls/app/<stream>/master.m3u8` through the authenticated, same-origin dashboard proxy.
Its relative media URLs preserve `/llhls/`; the built-in `llhls.m3u8` playlist does not.

Plain RTMP, HTTP playback/signalling, and OVT are not exposed by Services.
A required ingress NetworkPolicy blocks direct network access to the pod's plaintext RTMP/HTTP backends,
the management API, and the signing service. The backends remain available to sidecars in the same pod.
This requires a NetworkPolicy-enforcing CNI (the cluster uses Cilium).

RTMPS and HTTPS/WHIP anycast use `STRICT_SINGLETON` on TCP 1936 and 3334. The origin manifest authorizes `*.k.kpt.link`;
the discovered SNI routes use the concrete `catcher.k.kpt.link`, because edges match SNI hostnames exactly.
The origin image is pinned to multi-architecture `1.2.1`, with no origin architecture selector.
The OME Service advertises public port 1936 and targets its own RTMPS port directly.
The catcher-specific TLSRoute advertises public port 3334 and explicitly targets
`cilium-gateway-anycast-gateway.public-gateway.svc.cluster.local:443`; its backend remains OME Service port 3334.
TLS is not terminated at the gateway; WHIP publishing signatures and keyless HTTPS playback keep the same public URL.
With the gateway enabled, the Service must not also advertise port 3334. With it disabled, HTTPS anycast targets the Service directly.
The policy schema uses `allowed_sni_patterns`; `allowed_sni_hostnames` is not consumed by the manifest signer.
The signed public manifest is `clusters/k/keys/anycast-origin-manifest.pb64`.
Serial 5 adds service `llm-proxy-anycast-tls-443` on TCP 443 with `STRICT_SINGLETON`, restricted to SNI `llm.k.kpt.link`, and retains WHIP port 3334.
Committing the signed file does not install it into the live `p2p-anycast-secrets` Secret.
After changing the policy, re-sign with the matching trusted CA. To install the new manifest without replacing the origin's identity or master key:

```bash
kubectl -n kube-system patch secret p2p-anycast-secrets --type merge \
  --patch "$(jq -n --rawfile manifest clusters/k/keys/anycast-origin-manifest.pb64 \
    '{stringData: {"origin_manifest.pb": $manifest}}')"
kubectl -n kube-system rollout restart deployment \
  -l app.kubernetes.io/instance=federation-p2p-anycast
```

**Placement and rollouts:** cluster k requires `kubernetes.io/arch: amd64` for OME.
If its compatible node is unavailable, the pod stays Pending rather than starting on a Raspberry Pi.
Rolling updates retain the old pod until the replacement's OME API listener is ready for at least 10 seconds.
This uses a one-pod surge, so the x86 host needs capacity for two OME pods during updates.
The single compatible host is still a single point of failure; a successful cutover still disconnects active publishing sessions.

**Migration:** syncing this change restarts OME and interrupts existing streams.
Old unsigned sender URLs no longer work; sign in and generate replacements before reconnecting.
ArgoCD creates the credential generators, ExternalSecret, internal dashboard certificate, and NetworkPolicy with the deployment.
Do not treat the old `ovenmediaengine-auth` Secret as an active publishing credential.

**Rotation/revocation:** update the relevant key in `ovenmediaengine-access`, then run
`kubectl -n ovenmediaengine rollout restart deployment/ovenmediaengine`.
Rotating `stream-key` invalidates all previously signed URLs; the restart also disconnects active sessions.
Rotating `dashboard-password` revokes the old dashboard login; rotating `api-token` requires the same restart to update both OME and its proxy.
Rotating `srt-passphrase` requires new encrypted SRT URLs.
ExternalSecret generation uses `refreshInterval: "0"` and does not periodically rotate credentials.

### Building initial boot images

```bash
# Build a specific host
nix build '.#nixosConfigurations.$hostname.config.system.builder.package'

# Build the entire cluster
nix build '.#packages.aarch64-linux.build-all-$cluster_name'

# For rpi5, you'll need to use the installer to get off the sd card
# Root password displays on hdmi screen after boot
nix run '.#nixosConfigurations.$hostname.config.system.builder.package'
# you will need to set the pci gen speed to 2.0 if you don't have shielded cable
nixos-anywhere --flake '.#$hostname' root@$INSTALLER_IP
```

### Managing the Cluster Infrastructure

Colmena is used to configure the base hosts. 

```bash
# Example to deploy to the test cluster using colmena, -p to set parallelism
nix run .#apps.aarch64-linux.colmena -- apply boot --on @cluster=test -v --show-trace -p 1
# Run commands on all
nix run .#apps.aarch64-linux.colmena -- exec --on @cluster=test -v --show-trace date
```

Note: `colmena apply boot` will not cause restart in-place. If you want to force immediate, online,
in-place update and potentially cause downtime, use `colmena apply`

### Locking Helm Charts

If you change version requirements for applications that download Helm charts, you must regenerate the lockfile by running the update helper:

```bash
# Example for the test cluster
./update-charts.sh test
```
