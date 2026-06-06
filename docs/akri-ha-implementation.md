# Akri and Home Assistant Implementation Plan

## Overview
This document outlines the implementation of Home Assistant and Akri within the libraryofalexandria homelab environment.

## Applications

### 1. Home Assistant
- **Chart Location:** `apps/homeassistant` (Local Chart)
- **Manifests:** Includes a Deployment, Service, and PersistentVolumeClaim.
- **Storage:** Uses `longhorn` as the default StorageClass for the PVC.
- **Ingress:** Uses the local `pkgs/gateway-helm` package deployed as a separate ArgoCD application within `k-apps` to route traffic to Home Assistant.

### 2. Akri
- **Chart Location:** Deployed directly from upstream (`https://project-akri.github.io/akri/`) via an ArgoCD application in `k-apps`.
- **Discovery:** Configured to use the `udev` discovery handler to pass USB devices to the cluster.
- **Node Selection:** Since the cluster is thin on resourcing, the Akri agent is extremely lightweight (typically ~20MB RAM) and will run as a DaemonSet across the cluster to discover devices on any node.
- **Other Discovery Handlers:** For context, Akri supports other handlers like:
  - **OPC UA:** For discovering industrial IoT devices via OPC UA protocol.
  - **ONVIF:** For discovering IP cameras.
  - **iSCSI:** For discovering iSCSI targets.

## Host-Level Configuration (NixOS)

- **Module Location:** `clusters/k/submodules/akri.nix`
- **Configuration:** For `udev` discovery (USB devices), NixOS natively manages `udev`. A placeholder module is created for any custom `udev` rules or packages that might be needed in the future. The `openiscsi` configuration is omitted since only USB devices are requested.
- **Import:** Included in `clusters/k/default.nix`.
