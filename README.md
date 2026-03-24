# Library of Alexandria

The Library of Alexandria is a declarative deployment repository for a multi-node Kubernetes cluster and underlying NixOS infrastructure. It utilizes Nix Flakes to provide a fully reproducible configuration of OS images, distributed nodes, and containerized applications.

The deployment relies on several key technologies:
- **[Nix / NixOS](https://nixos.org/)**: Foundation for the deterministic OS configuration and reproducible packages.
- **[Colmena](https://github.com/zhaofengli/colmena)**: Deployment tool for provisioning NixOS configurations across remote hosts.
- **[Disko](https://github.com/nix-community/disko)**: Declarative disk partitioning and formatting for the cluster nodes.
- **[Crossplane](https://crossplane.io/)**: Universal control plane for managing infrastructure and backing services directly from Kubernetes manifests.
- **[ArgoCD](https://argoproj.github.io/cd/)**: Declarative GitOps continuous delivery tool for Kubernetes, acting as the primary application controller for the cluster.
- **[Cert-Manager](https://cert-manager.io/) & [Trust-Manager](https://cert-manager.io/docs/trust/trust-manager/)**: Automated certificate issuing, management, and cluster-wide trust bundle distribution.
- **[Longhorn](https://longhorn.io/)**: Distributed block storage system providing persistent volumes for stateful applications.

## Repository Structure

- `apps/`: Contains definitions for Kubernetes applications deployed to the clusters. They are grouped logically:
  - `loa-authn/`: Authentication and identity related apps.
  - `loa-core/`: Core infrastructure and initial resources for the Library of Alexandria.
  - `loa-extras/`: Additional apps padding the core deployment.
  - `loa-federation/`: Cross-cluster or external services federation (e.g., pgEdge).
  - `loa-observability/`: Logging, monitoring, and tracing stacks.
  - `loa-voip/`: Voice over IP systems and comms applications.
- `clusters/`: Cluster-specific configurations and node definitions.
- `docs/`: Documentation on various specific aspects of the project.
- `lib/`: Shared custom Nix libraries containing helper functions used across the module systems.
- `modules/`: Assorted NixOS and application modules applied to hosts and clusters.
- `pkgs/`: Custom Nix derivations and local package overlays for project-specific binaries.
- `tests/`: Automated configuration and infrastructure tests.

## Utility Scripts

Several root-level helper scripts simplify operational tasks:

- `./update-charts.sh <cluster_name>`: Evaluates and locks Helm charts for a given cluster. It fetches remote Helm repositories, resolves container images, and stores integrity hashes using `nix-prefetch-docker` into a `charts-lock.json` file for reproducible air-gapped evaluation.
- `./validate-compositions.sh`: Validates Crossplane Custom Resource Definitions (XRD) and Compositions, ensuring the templates correctly map to internal resources before deployment.
- `./gen-keys.sh` / `./link-keys.sh`: Utilities for managing and linking secrets related to the cluster deployments.

## Usage

### Managing the Cluster Infrastructure

Colmena is used to configure the base hosts. 

```bash
# Example to deploy to the test cluster using colmena
colmena apply --on @test
```

### Locking Helm Charts

If you change version requirements for applications that download Helm charts, you must regenerate the lockfile by running the update helper:

```bash
# Example for the test cluster
./update-charts.sh test
```
