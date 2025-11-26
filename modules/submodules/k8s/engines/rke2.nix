{ config, pkgs, lib, ... }:
{
    imports = [
        ../../nixstore-linker.nix
        ../helm-charts.nix
    ];

    config = 
        let
            isMaster = config.libraryofalexandria.node.type == "master";
            isWorker = !isMaster;
            isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;
            master0Ip = builtins.elemAt config.libraryofalexandria.node.masterIps 0;
            thisMasterIp = if isWorker then "" else builtins.elemAt config.libraryofalexandria.node.masterIps config.libraryofalexandria.node.id;
        in lib.mkIf (config.libraryofalexandria.cluster.k8sEngine == "rke2") {
            environment = {
                variables = lib.mkIf isMaster {
                    "KUBECONFIG" = "/etc/rancher/rke2/rke2.yaml";  # must match helm chart installer
                };
                systemPackages = with pkgs; [
                    rke2
                    cri-o
                    rke2-images
                    rke2-images-cilium
                ] ++ (if isMaster then [
                    kompose
                    kubectl
                    k9s
                    argocd
                    argocd-vault-plugin
                    jq
                ] else []) ++ (if isMaster0 then [
                    rke2-overrides-helm
                    cilium-keys-gen-helm
                ] else []);
            };

            deployment.keys = {
                "token.key" = lib.mkIf isMaster {
                    keyFile = "/var/keys/clusters/${config.libraryofalexandria.cluster.name}/token.key";
                    destDir = "/var/keys";
                    permissions = "0600";
                    uploadAt = "pre-activation";
                };
                "agent-token.key" = lib.mkIf isWorker {
                    keyFile = "/var/keys/clusters/${config.libraryofalexandria.cluster.name}/agent-token.key";
                    destDir = "/var/keys";
                    permissions = "0600";
                    uploadAt = "pre-activation";
                };
            };

            services.nixstore-linker = {
                # https://docs.rke2.io/install/airgap?airgap-load-images=Manually+Deploy+Images&airgap-upgrade=Manual+Upgrade&installation-methods=Script+install#1-load-images
                rke2-images = {
                    targetPackage = pkgs.rke2-images;
                    targetPackageSubpath = "asset/rke2-images";
                    linkPath = "/var/lib/rancher/rke2/agent/images/";
                    ensureDirectories = [ "/var/lib/rancher/rke2/agent/images/" ];
                };
                rke2-images-cilium = {
                    targetPackage = pkgs.rke2-images-cilium;
                    targetPackageSubpath = "asset/rke2-images-cilium";
                    linkPath = "/var/lib/rancher/rke2/agent/images/";
                    ensureDirectories = [ "/var/lib/rancher/rke2/agent/images/" ];
                };
            };

            # k8s protect kernel
            # vm.overcommit_memory=1
            # kernel.panic=10
            # kernel.panic_on_oops=1
            boot.kernelParams = [
                "panic_on_oops=1"
                "panic=10"
            ];
            boot.kernel.sysctl = {
                "vm.overcommit_memory" = 1;
                "kernel.panic_on_oops" = 1;
                "kernel.panic" = 10;
            };

            services.rke2 = let 
                tlsSanFlags = builtins.map (ip: "--tls-san=${ip}") config.libraryofalexandria.node.masterIps;
            in {
                enable = true;
                serverAddr = if isMaster0 then "" else "https://${master0Ip}:9345";  # default rke2 port
            } // (if isMaster then {
                role = "server";
                cni = "cilium";
                nodeIP = thisMasterIp;
                tokenFile = "/var/keys/token.key";
                extraFlags = [
                    "--profile=cis"
                ] ++ tlsSanFlags;
            } else {
                role = "agent";
                agentTokenFile = "/var/keys/agent-token.key";
                extraFlags = [
                    "--profile=cis"
                ] ++ tlsSanFlags;
            });

            systemd.services.rke2-server = {
                unitConfig = {
                    # The service will stay in 'inactive' state until this file exists
                    AssertPathExists = if isMaster then "/var/keys/token.key" else "/var/keys/agent-token.key";
                };
            };

            # etcd hardening
            users = if isMaster then {
                groups.etcd = { }; # create an 'etcd' group

                users.etcd = {
                    isSystemUser = true;
                    description = "etcd service user";
                    group = "etcd";
                    home = "/var/lib/etcd"; # optional, standard for etcd
                    createHome = true;      # ensures directory exists
                };
            } else {};

            # cilium hardening
            libraryofalexandria.helmCharts.enable = true;
            libraryofalexandria.helmCharts.charts = lib.mkBefore [
                {
                    name = "cilium-keys-gen-helm";
                    chart = "${pkgs.cilium-keys-gen-helm}";
                    namespace = "kube-system";
                }
                {
                    name = "cilium-overrides";
                    chart = "${pkgs.rke2-overrides-helm}";
                    values = {
                        valuesContent = ''encryption:
  enabled: true
  type: ipsec
  ipsec:
    secretName: cilium-ipsec-keys
'';
                    };
                    namespace = "kube-system";
                }
            ];
    };
}