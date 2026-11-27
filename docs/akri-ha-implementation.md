# Akri, Home Assistant, and Thread

## Deployment

- `apps/k-apps` enables Home Assistant, its TLS certificate, and TLS passthrough at
  `https://homeassistant.k.loa.internal`.
- `apps/homeassistant` runs one StatefulSet replica with the existing Longhorn
  `homeassistant-pvc`. Matter Server remains a sidecar. Host networking supports
  LAN multicast; `ClusterFirstWithHostNet` retains Kubernetes service discovery.
- USB OTBR is disabled by default (`usbOtbr.enabled: false`). Home Assistant and
  Matter Server remain enabled for use with a Thread-capable Apple TV.
  Home Assistant has **no Akri resource request**: a missing radio cannot prevent
  it from starting.

## Apple TV border router (current configuration)

`clusters/k/submodules/matter-ipv6.nix` keeps IPv6 enabled and accepts LAN router
advertisements (`accept_ra=2`) and route-information prefixes through /64, including
when Kubernetes enables host forwarding. It uses each node's primary interface:
`end0` on the Pi nodes, `enp5s0` on worker2-k. These settings are still needed for
the Matter Server to reach Thread devices through an external border router.
The LAN must provide working IPv6 routing and multicast; IPv6 WAN access is not required.

The module disables temporary IPv6 addresses on the primary LAN interface so
Matter traffic uses a stable SLAAC source address matching per-node firewall aliases.
Include each eligible HA node's stable address in those aliases, since HA can move
between nodes. Check the selected source with `ip -6 route get <device-OMR-address>`.

For cross-VLAN routing, pfSense needs a route to the actual Thread OMR prefix via
the Apple TV's current LAN IPv6 address. Confirm the next hop still belongs to the
Apple TV after network/interface changes; a stale link-local gateway can break
HA access even while clients on the Apple TV VLAN reach Thread devices directly.

The USB-only `otbr.nix` module is not imported. The Helm chart omits
`homeassistant-thread-rcp`, so ArgoCD sync prunes any previously deployed USB
Configuration and its owned brokers. Akri itself remains available for other devices.
The `homeassistant-thread-state` PVC stays rendered even while USB OTBR is disabled,
preserving any existing dataset.

Connect Home Assistant's Matter integration to `ws://127.0.0.1:5580/ws` and use
the Apple Thread network for commissioning. Do not add the Apple TV as an OTBR
REST endpoint. See [Home Assistant's Matter documentation](https://www.home-assistant.io/integrations/matter/).

### Enabling USB OTBR later

1. Uncomment `./otbr.nix` in `clusters/k/submodules/default.nix` and apply the
   NixOS configuration to the nodes before enabling the broker.
2. Set `usbOtbr.enabled: true` in the `k-apps` Helm values and sync ArgoCD.
3. Follow the USB firmware, dataset, and integration instructions below. If keeping
   the Apple Thread network, import its credentials into Home Assistant first;
   do not accidentally form a separate network.

## Single-radio allocation

The previous StatefulSet requested `akri.sh/homeassistant-connection-zb1`, a
configuration-level resource. With one radio this produced rapid
`UnknownAdmissionError` failures and pod recreation.

`apps/k-apps/templates/akri/thread-rcp.yml` instead defines
`homeassistant-thread-rcp` with a broker PodSpec. Akri replaces `{{PLACEHOLDER}}`
with the discovered **instance-level** resource and requests one slot
(`capacity: 1`). Do not increase capacity to work around allocation failures:
two processes must not drive the same serial radio.

Discovery matches Nabu Casa CP210x tty devices, rather than all CP210x adapters.
The broker uses Akri's `UDEV_DEVNODE_*` environment variable, so a radio at
`/dev/ttyUSB1` works without editing manifests. Missing or ambiguous device
variables fail startup. This configuration assumes one matching Thread radio.

This bypasses the reported configuration-level allocation path; eliminating
admission errors still needs verification on the real cluster.
See [Akri broker customization](https://docs.akri.sh/user-guide/customizing-an-akri-installation)
and [configuration-level allocation](https://docs.akri.sh/architecture/configuration-level-resource-in-depth).

## Host IPv6 and USB prerequisites

For USB OTBR, apply the opt-in `clusters/k/submodules/otbr.nix` module **before
syncing the broker**. It adds IPv4/IPv6 forwarding plus TUN and netfilter modules.
Matter's IPv6/RA settings remain in the always-imported `matter-ipv6.nix`; disabling
USB OTBR does not turn off forwarding configured elsewhere for Kubernetes.
These are host sysctls, not pod sysctls: host-network pods share the node's network namespace.

The privileged broker mounts `/dev/net/tun` as a character device and receives the
serial device from Akri. `BACKBONE_IF` is selected from the host's IPv4 default
route, avoiding an `end0` assumption on the x86 worker. The image is pinned to a
multi-architecture digest supporting arm64 and amd64.

The ZBT-1 must already run **OpenThread RCP firmware** compatible with 460800 baud
and hardware flow control. Zigbee firmware is not an OTBR radio; automatic flashing
is disabled. Do not let ZHA or another process claim this stick.
The LAN needs working IPv6 and multicast between the broker, Home Assistant,
and the commissioning phone; IPv6 WAN access is not required.
See the [image prerequisites](https://github.com/ownbee/hass-otbr-docker#prerequisite).

## State and cutover

The new Configuration name lets ArgoCD prune `homeassistant-connection-zb1` and
create fresh discovery state instead of retaining old configuration-level claims.
The old OTBR sidecar and resource requests are removed together.

OTBR stores `/data` on the `akri/homeassistant-thread-state` Longhorn PVC
(`ReadWriteOnce`, 1 GiB); the image keeps the dataset in `/data/thread`.
The claim is independent of the Akri Instance and broker Pod, so unplugging the
radio does not delete it. Only `/dev/net/tun` is a hostPath.

To move the stick, unplug it and plug it into another k node. Akri discovers it
and creates the replacement broker there using the same claim. Expect downtime
while the old broker terminates and Longhorn detaches/reattaches the volume.
A Pending/Multi-Attach period during that handoff is not an admission failure.
Do not force-detach a volume from a still-running broker. If the old node is
unreachable, fence it before recovering the attachment. Do not change the claim
to ReadWriteMany: concurrent OTBR processes must not write the same dataset.

### Migrating an existing hostPath deployment

If the hostPath version has already run, migrate its state before starting a
broker with the PVC; an empty PVC does not recover the existing Thread network.

1. Stop OTBR and temporarily suspend broker reconciliation during migration.
2. Back up the **entire contents** of `/var/lib/otbr-thread` on the old USB host.
   Preserve the `thread/` subdirectory, permissions, and ownership.
3. Sync the PVC and copy that backup into its root using a temporary pod mounting
   `homeassistant-thread-state` in namespace `akri`. The resulting dataset path
   must be `/data/thread`, not `/data/otbr-thread/thread`.
4. Remove the migration pod to release the volume. Recreate the Akri Configuration
   from the updated manifest, then resume reconciliation so newly created brokers
   use the PVC rather than retaining the old PodSpec.
5. Verify the existing Thread network before retiring the host backup. Preserve
   the Home Assistant PVC and Matter storage as well.

For a fresh deployment, no hostPath migration is needed.

After host configuration and ArgoCD sync:

```bash
kubectl -n homeassistant rollout status statefulset/homeassistant
kubectl -n akri get configurations,instances,pods,svc -o wide
kubectl -n akri logs <otbr-broker-pod> -c otbr
kubectl -n akri exec <otbr-broker-pod> -c otbr -- ot-ctl state
```

Verify one broker for the radio, no growing admission-error event stream, and a
reachable OTBR REST API on port 8081. A new dataset may initially be disabled:
do not use Thread attachment as a liveness probe that restarts an uncommissioned router.

In Home Assistant, add the **OpenThread Border Router** integration using
`http://<broker-node-LAN-IP>:8081` (or its Akri configuration Service DNS name).
Select the intended network under **Thread**, sync its credentials to the phone,
and connect **Matter** to `ws://127.0.0.1:5580/ws`. Creating or selecting a Thread
dataset and commissioning devices are explicit Home Assistant actions, not
automatic firmware or network resets.
