# Akri, Home Assistant, and Thread

## Deployment

- `apps/k-apps` enables Home Assistant, its TLS certificate, and TLS passthrough at
  `https://homeassistant.k.loa.internal`.
- `apps/homeassistant` runs one StatefulSet replica with the existing Longhorn
  `homeassistant-pvc`. Matter Server remains a sidecar. Host networking supports
  LAN multicast; `ClusterFirstWithHostNet` retains Kubernetes service discovery.
- OTBR runs separately as an Akri broker in namespace `akri`, not as a Home Assistant
  sidecar. Home Assistant has **no Akri resource request**: a missing radio cannot
  prevent Home Assistant from starting.

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

Apply the NixOS changes in `clusters/k/default.nix` **before syncing the broker**:
all k nodes enable IPv6/IPv4 forwarding, load TUN and netfilter modules, and accept
IPv6 router advertisements even while forwarding (`accept_ra=2`). The LAN interface
also accepts route-information prefixes through /64. These are host sysctls,
not pod sysctls: Kubernetes host-network pods cannot own a separate network namespace.

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

OTBR retains `/var/lib/otbr-thread` on the USB host, mounted at `/data`
(the image stores the dataset in `/data/thread`). Back this directory up before
moving the stick: moving USB does **not** move the Thread dataset. Preserve the
Home Assistant PVC and Matter storage as well.

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
