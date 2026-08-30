
1) rke2 helm install jobs run in whatever order they want. You will probably need to delete the jobs entirely a few times (other than maybe longhorn and cert-manager)

2) Issue: GatewayClass cilium missing. Solution: Delete rke2-cilium helm install job (and let it recreate)

3) 