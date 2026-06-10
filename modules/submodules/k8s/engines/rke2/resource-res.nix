{ config, lib, ... }:
let
  isRke2 = config.libraryofalexandria.cluster.k8sEngine == "rke2";
  isMaster = config.libraryofalexandria.node.type == "master";
in
{
  environment.etc."rancher/rke2/config.yaml.d/99-protect-node.yaml".text =
    lib.mkIf isRke2
      (
        if isMaster then
          ''
            # 2. Hard limits for static pods
            control-plane-resource-limits:
              - kube-apiserver-memory=2560Mi
              - etcd-memory=1500Mi
              - kube-controller-manager-memory=512Mi

            # 3. Aggressive Component Tuning
            etcd-arg:
              # Lower the DB quota (default is 2G). 1G is plenty for 5 nodes.
              - "quota-backend-bytes=1073741824"  # TODO scale per node count
            kube-apiserver-extra-env:
              - "GOMEMLIMIT=2048MiB"
            kube-apiserver-arg:
              # Throttle read requests (LIST/WATCH from ArgoCD/Longhorn)
              - "max-requests-inflight=150"     # Default is 400
              # Throttle write requests (POST/PUT)
              - "max-mutating-requests-inflight=50" # Default is 200
              # Reduce default watch cache size for all resources (primarily CRDs)
              - "default-watch-cache-size=50"

            # 4. OS and Kubelet Protection
            kubelet-arg:
              - "kube-reserved=cpu=250m,memory=500Mi"
              - "system-reserved=cpu=250m,memory=500Mi"
              - "eviction-hard=memory.available<500Mi,nodefs.available<10%"
          ''
        else
          ''
            kubelet-arg:
              - "kube-reserved=cpu=250m,memory=500Mi"
              - "system-reserved=cpu=250m,memory=500Mi"
              - "eviction-hard=memory.available<500Mi,nodefs.available<10%"
              - "pod-max-pids=1024"
          ''
      );

  systemd.services = lib.mkIf isRke2 (
    if isMaster then {
      rke2-server.restartTriggers = [
        config.environment.etc."rancher/rke2/config.yaml.d/99-protect-node.yaml".source
      ];
    } else {
      rke2-agent.restartTriggers = [
        config.environment.etc."rancher/rke2/config.yaml.d/99-protect-node.yaml".source
      ];
    }
  );
}
