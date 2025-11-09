{ config, pkgs, lib, ... }:
{
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
                ] ++ (if isMaster then [
                    kompose
                    kubectl
                    k9s
                    argocd
                    argocd-vault-plugin
                    jq
                ] else []);
            };

            services.rke2 = if isMaster then {
                enable = true;
                role = "server";
                cni = "cilium";
                nodeIP = thisMasterIp;
                serverAddr = if isMaster0 then "" else "https://${master0Ip}:9345";  # default rke2 port
                token = "test";
                extraFlags = [
                    #"--profile=cis"
                    "--tls-san=${thisMasterIp}"
                ];
            } else {
                enable = true;
                role = "agent";
                # cisHardening = true;
            };

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