{ lib, config, ... }:
let 
  isMaster = config.libraryofalexandria.node.type == "master";
  k8sSystemdService = if config.libraryofalexandria.cluster.k8sEngine == "rke2" then "rke2-server" else "kubernetes";
in
{
  imports = [
    ./engines
    ./manifests.nix
    ./helm
    ./zarf.nix
  ];

  config = lib.mkIf (isMaster) {
    systemd.services.k8s-api-waiter = {
      description = "Wait for Kubernetes API";
      wantedBy = [ "multi-user.target" ];
      after = [ "${k8sSystemdService}.service" ];
      requires = [ "${k8sSystemdService}.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "10min";
      };

      path = [ pkgs.kubectl ];
      environment = {
        KUBECONFIG = config.environment.variables.KUBECONFIG;
      };

      script = ''
        set -euo pipefail
        echo "[+] Waiting for Kubernetes API to be fully ready..."
        until kubectl get --raw "/healthz" &> /dev/null; do
          echo "    API not ready yet, sleeping 5s..."
          sleep 5
        done
        
        echo "[+] Kubernetes API is responsive. Checking Nodes..."
        until kubectl get nodes | grep -q " Ready"; do
          echo "    Nodes not ready yet, sleeping 5s..."
          sleep 5
        done
        echo "[+] Cluster is up and ready!"
      '';
    };
  };
}