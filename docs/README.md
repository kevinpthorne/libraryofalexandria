# Library of Alexandria Documentation

Welcome to the documentation for **Library of Alexandria**, a declarative multi-node Kubernetes cluster and NixOS infrastructure repository.

Below is a directory of all available documentation pages covering system architecture, networking, application onboarding, and operational procedures.

---

## 🏛️ Architecture & Networking

* **[P2P VPN & BGP Federation Architecture](p2p-vpn-bgp-federation.md)**  
  Detailed architecture of the multi-cluster Layer 3 overlay network. Explains how `p2p-vpn` (libp2p with PKI/CA identity verification), FRR (eBGP routing sidecar), Cilium BGP Control Plane (eBPF datapath routing), multi-master state replication (pgEdge, KeyDB, and SeaweedFS object/filer sync), and Cloudflare Tunnels unite to enable cross-cluster communication, global Anycast services, and distributed storage.

* **[DNS Tools Architecture & Getting Started Guide](dns-tools.md)**  
  Overview of LOA Core's dual-DNS strategy using `hostdns` (internal PowerDNS with Cilium IPAM) and `cloudflare-externaldns` (public DNS and Dynamic DNS via Cloudflare API).

---

## 🚀 Applications & Services

* **[Sipcord & Asterisk ConfBridge Setup Guide](sipcord-setup.md)**  
  Step-by-step guide for deploying and configuring the Sipcord voice bridge (`loa-voip`) to link Asterisk PBX `ConfBridge` channels with Discord voice channels.

* **[Akri & Home Assistant Implementation Plan](akri-ha-implementation.md)**  
  Implementation details for Home Assistant and Akri, using `udev` discovery daemonsets for USB device passthrough to Kubernetes pods.

* **[pgEdge Federated App Onboarding Guide](pgedge-onboarding.md)**  
  Multi-phase onboarding workflow for active-active and active-standby PostgreSQL multi-cluster replication using KRO and Spock.

---

## 🛠️ Operations, Troubleshooting & Guides

* **[SSH Development Environment Setup](ssh-dev-readme.md)**  
  Reference guide for SSH port forwarding, reverse tunnels, and connecting dev hosts, builder VMs, and NixOS cluster nodes.

* **[Finding Minecraft PVC Volume Replicas](find-minecraft-pvc.md)**  
  Shell script snippet for locating active Minecraft server state within raw Longhorn block volume replica directories.

* **[Unborking Raspberry Pi Installs](unbork-rpi-installs.md)**  
  Emergency network interface reconfiguration and etcd cluster reset commands for recovering Raspberry Pi nodes.

* **[YubiKey PAM Onboarding](yubikey-onboarding.md)**  
  Command and steps for registering YubiKey U2F tokens with PAM host configurations (`pamu2fcfg`).

* **[ESO Helm Templating Notes](eso-helm-woes.md)**  
  Quick tip on escaping Go templates within External Secrets Operator (ESO) Helm manifests.

* **[Known Installation Bugs](known-install-bugs.md)**  
  Notes on handling RKE2 Helm install job ordering.

* **[XRD Lessons Learned (Deprecated)](xrd-lessons-learned.md)**  
  Historical notes on Crossplane Custom Resource Definitions (replaced by KRO).
