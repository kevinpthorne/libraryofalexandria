{ config, lib, ... }:
{
  # Drop-in configuration to protect the control plane
  environment.etc."rancher/rke2/config.yaml.d/99-protect-node.yaml".text = lib.mkIf (config.libraryofalexandria.cluster.k8sEngine == "rke2") (
    if (config.libraryofalexandria.node.type == "master") then
      ''
        # 2. Hard-reserve system resources (Adjust values based on your total RAM)
        kubelet-arg:
          # Reserve RAM/CPU for Kubernetes binaries (etcd, apiserver, kubelet)
          - "kube-reserved=cpu=500m,memory=1500Mi"
          # Reserve RAM/CPU for the underlying OS (systemd, sshd, journald)
          - "system-reserved=cpu=500m,memory=500Mi"
          # Trigger aggressive pod eviction before the node actually locks up
          - "eviction-hard=memory.available<500Mi,nodefs.available<10%"
      ''
    else
      ''
        kubelet-arg:
            # Reserve RAM/CPU for Kubernetes binaries (etcd, apiserver, kubelet)
            - "kube-reserved=cpu=200m,memory=500Mi"
            # Reserve RAM/CPU for the underlying OS (systemd, sshd, journald)
            - "system-reserved=cpu=200m,memory=500Mi"
            # Trigger aggressive pod eviction before the node actually locks up
            - "eviction-hard=memory.available<500Mi,nodefs.available<10%"
            # max pids per pod
            - "pod-max-pids=1024"
      ''
  );
}
