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
