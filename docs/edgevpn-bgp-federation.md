# EdgeVPN BGP Federation Architecture

This document describes the multi-cluster networking architecture used in this repository to connect independent Kubernetes clusters via a secure, decentralized Layer 3 overlay.

## 1. The Core Components

Our federation architecture relies on three primary components:
1.  **EdgeVPN**: A decentralized, peer-to-peer (P2P) VPN based on `libp2p`. It punches through residential NATs and provides the encrypted Layer 3 transport overlay.
2.  **FRR (Free Range Routing)**: A powerful BGP routing daemon running as a sidecar alongside EdgeVPN. It handles dynamic route discovery across the VPN.
3.  **Cilium BGP Control Plane**: The networking layer inside your local cluster, which natively speaks BGP to learn about remote clusters and update the local host routing tables.

## 2. The Multi-Cluster BGP Topology

Instead of manually maintaining complex routing tables or dealing with Netbird management servers, we utilize **eBGP over EdgeVPN** to establish an automated full-mesh network.

### The Underlying Overlay (EdgeVPN)
Each cluster deploys a single EdgeVPN gateway pod. These gateways join a private DHT (using a shared `EDGEVPNTOKEN`) and are assigned unique IP addresses on an internal VPN subnet (`10.255.255.0/24`). 
- Cluster A Gateway: `10.255.255.1`
- Cluster B Gateway: `10.255.255.2`
- Cluster C Gateway: `10.255.255.3`

Because EdgeVPN uses `libp2p`, it seamlessly handles NAT traversal, making it ideal for residential deployments. 

### The BGP Mesh (FRR)
Inside the EdgeVPN gateway pod runs an FRR sidecar. FRR is configured to run eBGP (External Border Gateway Protocol) across the `edgevpn0` interface.

Each cluster uses a unique Autonomous System Number (ASN) derived from its Cluster ID. For example:
- Cluster A uses `localAS: 65001`
- Cluster B uses `localAS: 65002`

Because we use eBGP, the FRR configuration utilizes `neighbor EDGEVPN remote-as external`. This allows the gateway to automatically accept connections from any remote cluster without needing to manually configure their specific ASN—you only need to provide their VPN IP in the `vpnPeers` array!

### Route Injection
Each cluster's local Pod and Service CIDRs are defined in the `localCIDRs` array of the EdgeVPN Helm chart. FRR uses standard `network` statements to inject these routes into the BGP mesh. Because FRR *originates* these routes, the AS-Path received by other clusters only contains the FRR sidecars' ASNs, completely avoiding any AS-Path loop issues.

## 3. Integration with Cilium

To get the remote routes from the EdgeVPN gateway down to the actual Kubernetes nodes, the FRR sidecar establishes an internal peering session with the local Cilium BGP Control Plane.

Cilium is configured to use a static ASN across all clusters (e.g., `65000`). This is configured via a `CiliumBGPPeeringPolicy`.
- FRR is configured with `ciliumPeerAS: 65000`. 
- Cilium connects to the EdgeVPN gateway (via its Service ClusterIP or Node IP).
- FRR advertises all the remote routes it learned from the VPN (`10.2.x.x -> 10.255.255.2`) down to Cilium.
- Cilium instantly programs the eBPF datapath on every local node to route `10.2.x.x` traffic to the EdgeVPN pod.

## 4. Achieving Global Anycast Services

With this Layer 3 connectivity established, you can achieve global, multi-cluster high availability using Cilium's native **Cluster Mesh Global Services**.

By adding the annotation `io.cilium/global-service: "true"` to a Kubernetes Service in multiple clusters, Cilium will automatically load-balance traffic across all available pods in all connected clusters.

### Handling Stateful/Active-Standby Workloads
If you are running a stateful application (like a management dashboard or a single-writer database) where you want a hot-standby in Cluster B, you can use `io.cilium/shared-service: "false"` on the secondary cluster. 
Traffic will stay strictly in Cluster A. If Cluster A goes down, Cilium will instantly failover all traffic across the EdgeVPN mesh to the standby instance in Cluster B, completely eliminating split-brain scenarios.

## 5. Exposing Services to the Public Internet

Because residential ISPs do not allow you to advertise BGP routes to the public internet, you cannot achieve true public BGP Anycast directly from your residential nodes.

If you need to expose a service (like a Minecraft server or VoIP PBX) to the general public across this mesh:
1. Rent an external VPS and install EdgeVPN so it joins your BGP mesh.
2. The VPS will learn all your cluster routes dynamically.
3. Expose the required TCP/UDP ports on the VPS's public IP.
4. Use a reverse proxy (like HAProxy or Nginx) on the VPS to forward the traffic over the EdgeVPN overlay into your residential clusters.

For HTTP/HTTPS traffic, simply use Cloudflare Tunnels (`cloudflared`) in each cluster, letting Cloudflare's global anycast network route users to the closest healthy cluster.

## Summary

This architecture provides a scalable, zero-maintenance mesh. To add a new cluster:
1. Assign it a unique Cluster ID (e.g., `4` -> AS `65004`).
2. Assign it a unique VPN IP (e.g., `10.255.255.4`).
3. Add its IP to the `vpnPeers` array in the other clusters.
4. The entire network will dynamically learn its routes!
