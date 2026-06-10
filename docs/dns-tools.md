# Architecture and Getting Started Guide: DNS Tools in LOA Core

Library of Alexandria Core (LOA Core) employs a dual-DNS strategy to manage both internal routing within the local network and external exposure to the public internet. This strategy is implemented using two dedicated applications deployed via Helm: `hostdns` and `cloudflare-externaldns`. 

Both applications rely on the `external-dns` Helm chart dependency to automatically synchronize Kubernetes resources (like Services and Gateways) to their respective DNS providers. However, they serve distinct scopes and leverage different backend technologies.

## Core Components: `hostdns` vs. `cloudflare-externaldns`

### 1. `hostdns` (Internal/Local DNS)
* **Function**: Manages internal cluster DNS resolution for private domains (e.g., `*.internal`, `*.loa.internal`). It enables resources within the cluster and locally connected network devices to discover and connect to services securely without routing traffic over the public internet.
* **Architecture**: It deploys a self-hosted PowerDNS (`pdns-auth`) server backed by a SQLite database.
* **Mechanism**: The embedded `external-dns` controller monitors internal Kubernetes resources and updates the local PowerDNS server via its API. It uses TXT records for state tracking (`policy: sync`), automatically cleaning up DNS records when the corresponding Kubernetes resources are deleted.

### 2. `cloudflare-externaldns` (External/Public DNS)
* **Function**: Manages public DNS records and Dynamic DNS (DDNS). It exposes designated services to the internet by creating corresponding DNS records in your Cloudflare account.
* **Architecture**: Integrates directly with the Cloudflare API, acting as a bridge between your Kubernetes cluster and your Cloudflare-managed domains.
* **Mechanism**: 
  * It runs a DDNS container (`timothyjmiller/cloudflare-ddns`) to continuously ensure your dynamic public IP address is synchronized with Cloudflare.
  * It leverages the `external-dns` controller configured with the Cloudflare provider to automatically generate and manage public DNS records for your internet-facing gateways and routes.

## Configuration & Getting Started

### Setting the Cloudflare API Key (Crucial Step)
For `cloudflare-externaldns` to function, it must have authenticated access to your Cloudflare account to manage your DNS zones. **Setting up the Cloudflare API key is a critical prerequisite.** Without it, external DNS resolution, record creation, and dynamic IP updates will silently fail.

**How it works:**
1. You must create an API Token in the Cloudflare dashboard with permissions to edit DNS for your target zones.
2. The system expects this token to be stored in a Kubernetes Secret strictly named `cf-key`, containing the token under the key `api-key`.
3. You must manually install this secret into the `externaldns` namespace before the application can function properly.

**Installation Instructions:**
Run the following `kubectl` command to deploy your API token securely into the cluster:

```bash
kubectl create namespace externaldns --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic cf-key \
  --namespace externaldns \
  --from-literal=api-key="YOUR_CLOUDFLARE_API_TOKEN_HERE"
```

Once this secret is created, both the Cloudflare DDNS updater and the `external-dns` controller will automatically mount it to securely authenticate their API requests to Cloudflare.

### Configuring the `hostdns` (Local DNS) IP
The PowerDNS server deployed by `hostdns` requires a stable, predictable IP address so that clients, routers, and other services know exactly where to send their local DNS queries.

**Where it gets set:**
The static IP address for `hostdns` is not hardcoded directly in the Helm chart. Instead, it is definitively set within your central Nix cluster module definition. For example, in `clusters/k/default.nix`, the IP is allocated under `virtualIps.reservations.dns`:

```nix
# clusters/k/default.nix
virtualIps = {
  reservations = {
    dns = "192.168.121.249";
  };
};
```

**How it works:**
This Nix cluster definition represents the single source of truth for the entire cluster payload. The ArgoCD `loa-core` wrapper application reads this injected payload (`.Values.cluster.virtualIps.reservations.dns`) and intelligently injects it as the `staticIP` parameter for the `hostdns` Helm chart. 

When the `staticIP` variable is populated, the `hostdns` Helm chart automatically adds the `lbipam.cilium.io/ips: {{ .Values.staticIP }}` annotation into the `powerdns` LoadBalancer Service. Cilium's LoadBalancer IPAM then intercepts this annotation and assigns the specified IP address to the PowerDNS service, ensuring a highly available and consistent local DNS endpoint while keeping the Helm chart clean and generic!
