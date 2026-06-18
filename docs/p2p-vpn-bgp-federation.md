# P2P VPN BGP Federation Architecture

This document describes the multi-cluster networking architecture used in this repository to connect independent Kubernetes clusters via a secure, decentralized Layer 3 overlay.

## 1. The Core Components

Our federation architecture relies on three primary components:
1.  **P2P VPN (`p2p-vpn`)**: A custom, decentralized peer-to-peer (P2P) VPN based on `libp2p`. It punches through residential NATs, performs PKI authentication (using CA signatures and a Peer ID whitelist), and provides the encrypted Layer 3 transport overlay.
2.  **FRR (Free Range Routing)**: A powerful BGP routing daemon running as a sidecar alongside `p2p-vpn`. It handles dynamic route discovery across the VPN.
3.  **Cilium BGP Control Plane**: The networking layer inside your local cluster, which natively speaks BGP to learn about remote clusters and update the local host routing tables.

## 2. The Multi-Cluster BGP Topology

Instead of manually maintaining complex routing tables or dealing with Netbird management servers, we utilize **eBGP over p2p-vpn** to establish an automated full-mesh network.

### The Underlying Overlay (`p2p-vpn`)
Each cluster deploys a single `p2p-vpn` gateway pod. These gateways join a private DHT (using a shared AES data key) and are assigned unique IP addresses on an internal VPN subnet (`10.255.255.0/24`). 
- Cluster A Gateway: `10.255.255.1`
- Cluster B Gateway: `10.255.255.2`
- Cluster C Gateway: `10.255.255.3`

Because `p2p-vpn` uses `libp2p`, it seamlessly handles NAT traversal, making it ideal for residential deployments. 

#### Cryptographic Security and PKI
Unlike basic setups, `p2p-vpn` is secured using a multi-layer cryptographic scheme:
1. **Shared Data Key**: An AES-256 data key used to encrypt the VPN traffic.
2. **Central CA (`ca.pub`)**: A central ML-DSA-87 key pair is used to sign each cluster's public cryptographic identity.
3. **Identity Key (`identity.key`)**: Each node generates/loads its unique private identity key.
4. **Node Signature (`node.sig`)**: The node presents a signature of its Peer ID signed by the central CA.
5. **Whitelist (`whitelist.txt`)**: A list of approved Peer IDs. Only nodes in this list are allowed to connect.

These public cryptographic materials are distributed to the cluster via the `p2p-vpn-config` ConfigMap (deployed via the `p2p-vpn-config-helm` chart). The private identity key is uploaded securely to master nodes via Colmena/Nix `deployment.keys`.

### The BGP Mesh (FRR)
Inside the `p2p-vpn` gateway pod runs an FRR sidecar. FRR is configured to run eBGP (External Border Gateway Protocol) across the tunnel interface.

Each cluster uses a unique Autonomous System Number (ASN) derived from its Cluster ID. For example:
- Cluster A uses `localAS: 65001`
- Cluster B uses `localAS: 65002`

Because we use eBGP, the FRR configuration utilizes `neighbor P2P_VPN remote-as external`. This allows the gateway to automatically accept connections from any remote cluster without needing to manually configure their specific ASN—you only need to provide their VPN IP in the `vpnPeers` array!

### Route Injection
Each cluster's local Pod and Service CIDRs are defined in the `localCIDRs` array of the `p2p-vpn-bgp` Helm chart. FRR uses standard `network` statements to inject these routes into the BGP mesh. Because FRR *originates* these routes, the AS-Path received by other clusters only contains the FRR sidecars' ASNs, completely avoiding any AS-Path loop issues.

## 3. Integration with Cilium

To get the remote routes from the `p2p-vpn` gateway down to the actual Kubernetes nodes, the FRR sidecar establishes an internal peering session with the local Cilium BGP Control Plane.

Cilium is configured to use a static ASN across all clusters (e.g., `65000`). This is configured via a `CiliumBGPClusterConfig` (the BGPv2 API for modern Cilium 1.16+).
- FRR is configured with `ciliumPeerAS: 65000`. 
- Cilium connects to the `p2p-vpn` gateway (via its Service ClusterIP or Node IP).
- FRR advertises all the remote routes it learned from the VPN (`10.2.x.x -> 10.255.255.2`) down to Cilium.
- Cilium instantly programs the eBPF datapath on every local node to route `10.2.x.x` traffic to the `p2p-vpn` pod.

## 4. Achieving Global Anycast Services

With this Layer 3 connectivity established, you can achieve global, multi-cluster high availability using Cilium's native **Cluster Mesh Global Services**.

By adding the annotation `io.cilium/global-service: "true"` to a Kubernetes Service in multiple clusters, Cilium will automatically load-balance traffic across all available pods in all connected clusters.

### Handling Stateful/Active-Standby Workloads
If you are running a stateful application (like a management dashboard or a single-writer database) where you want a hot-standby in Cluster B, you can use `io.cilium/shared-service: "false"` on the secondary cluster. 
Traffic will stay strictly in Cluster A. If Cluster A goes down, Cilium will instantly failover all traffic across the `p2p-vpn` mesh to the standby instance in Cluster B, completely eliminating split-brain scenarios.

## 5. Exposing Services to the Public Internet

Because residential ISPs do not allow you to advertise BGP routes to the public internet, you cannot achieve true public BGP Anycast directly from your residential nodes.

If you need to expose a service (like a Minecraft server or VoIP PBX) to the general public across this mesh:
1. Rent an external VPS and install `p2p-vpn` so it joins your BGP mesh.
2. The VPS will learn all your cluster routes dynamically.
3. Expose the required TCP/UDP ports on the VPS's public IP.
4. Use a reverse proxy (like HAProxy or Nginx) on the VPS to forward the traffic over the `p2p-vpn` overlay into your residential clusters.

For HTTP/HTTPS traffic, simply use Cloudflare Tunnels (`cloudflared`) in each cluster, letting Cloudflare's global anycast network route users to the closest healthy cluster.

## Summary

This architecture provides a scalable, secure, and zero-maintenance mesh. To add a new cluster:
1. Assign it a unique Cluster ID (e.g., `4` -> AS `65004`).
2. Assign it a unique VPN IP (e.g., `10.255.255.4`).
3. Add its IP to the `vpnPeers` array in the other clusters.
4. Generate/sign the new cluster's keys using `./gen-p2p-vpn-keys.sh`.
5. The entire network will dynamically learn its routes!
