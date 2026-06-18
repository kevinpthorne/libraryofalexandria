{
  pkgs,
  config,
  lib,
  ...
}:
let
  thisCluster = config.libraryofalexandria.cluster;
  isMaster = config.libraryofalexandria.node.type == "master";

  # Paths to the generated keys/configs on the deployer's machine
  caPath = "/var/keys/clusters/${thisCluster.name}/p2p-vpn-ca.pub";
  sigPath = "/var/keys/clusters/${thisCluster.name}/p2p-vpn-node.sig";
  whitelistPath = "/var/keys/clusters/${thisCluster.name}/p2p-vpn-whitelist.txt";
  identityPath = "/var/keys/clusters/${thisCluster.name}/p2p-vpn-identity.key";
  dataKeyPath = "/var/keys/clusters/${thisCluster.name}/p2p-vpn-data.key";

  # Read files at evaluation/compile time if they exist
  caContent = if builtins.pathExists caPath then builtins.readFile caPath else "";
  sigContent = if builtins.pathExists sigPath then builtins.readFile sigPath else "";
  whitelistContent = if builtins.pathExists whitelistPath then builtins.readFile whitelistPath else "";

  p2p-vpn-secret-install = pkgs.writeShellScriptBin "p2p-vpn-secret-install" ''
    set -euo pipefail

    # Wait for kube-api to be ready
    echo "Waiting for kubernetes api..."
    until ${pkgs.kubectl}/bin/kubectl get --raw "/healthz" &> /dev/null; do
      sleep 2
    done

    if [ -f /var/keys/p2p-vpn-identity.key ]; then
      echo "Creating/updating kube-system secret p2p-vpn-identity..."
      ${pkgs.kubectl}/bin/kubectl create secret generic p2p-vpn-identity \
        --namespace=kube-system \
        --from-file=identity.key=/var/keys/p2p-vpn-identity.key \
        --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -
    else
      echo "Warning: /var/keys/p2p-vpn-identity.key not found, skipping identity secret installation."
    fi

    if [ -f /var/keys/p2p-vpn-data.key ]; then
      echo "Creating/updating kube-system secret p2p-vpn (data key)..."
      ${pkgs.kubectl}/bin/kubectl create secret generic p2p-vpn \
        --namespace=kube-system \
        --from-file=token=/var/keys/p2p-vpn-data.key \
        --dry-run=client -o yaml | ${pkgs.kubectl}/bin/kubectl apply -f -
    else
      echo "Warning: /var/keys/p2p-vpn-data.key not found, skipping data key secret installation."
    fi
  '';
in
{
  config = lib.mkIf (isMaster && config.libraryofalexandria.apps ? "loa-federation") {
    # 1. Setup deployment keys for the master node (Colmena upload)
    deployment.keys = lib.mkIf isMaster (
      (lib.optionalAttrs (builtins.pathExists identityPath) {
        "p2p-vpn-identity.key" = {
          keyFile = identityPath;
          destDir = "/var/keys";
          permissions = "0600";
          uploadAt = "pre-activation";
        };
      }) // (lib.optionalAttrs (builtins.pathExists dataKeyPath) {
        "p2p-vpn-data.key" = {
          keyFile = dataKeyPath;
          destDir = "/var/keys";
          permissions = "0600";
          uploadAt = "pre-activation";
        };
      })
    );

    # 2. Install p2p-vpn-secret-install shell script package
    environment.systemPackages = [ p2p-vpn-secret-install ];

    # 3. Enable helmCharts and register p2p-vpn-config
    libraryofalexandria.helmCharts = {
      enable = true;
      charts = lib.mkBefore [
        {
          name = "p2p-vpn-config";
          chart = "${pkgs.p2p-vpn-config-helm}/p2p-vpn-config-helm-0.1.0.tgz";
          values = {
            ca = caContent;
            sig = sigContent;
            whitelist = whitelistContent;
          };
          namespace = "kube-system";
        }
      ];
    };
  };
}
