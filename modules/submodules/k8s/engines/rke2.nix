{ config, pkgs, lib, ... }:
{
    imports = [
        ../../nixstore-linker.nix
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
                ] else []);
            };

            deployment.keys = {
                "token.key" = lib.mkIf isMaster {
                    keyFile = builtins.trace "/var/keys/clusters/${config.libraryofalexandria.cluster.name}/token.key" "/var/keys/clusters/${config.libraryofalexandria.cluster.name}/token.key";
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
    };
}