{ config, pkgs, lib, ... }:
{
    config = 
        let
            isMaster = config.libraryofalexandria.node.type == "master";
            isWorker = !isMaster;
            # Master IP to String
            masterIpsToHostnames = with config.libraryofalexandria.node; builtins.listToAttrs (
                builtins.map (ip: { 
                    name = ip; 
                    value = getHostname "master" (indexOf ip masterIps) clusterName;
                }) masterIps
            );
            extraHostEntries = map (entry: "${entry.name} ${entry.value}") (lib.attrsets.attrsToList masterIpsToHostnames);
            extraHostsStr = lib.concatStringsSep "\n" extraHostEntries;
            # This master IP and hostname. Only use behind an `mkIf isMaster` gate
            thisMasterIp = lib.lists.elemAt config.libraryofalexandria.node.masterIps config.libraryofalexandria.node.id;
            thisMasterHostname = masterIpsToHostnames.${thisMasterIp};
            # TODO make multiple masters
            masterIp = lib.lists.elemAt config.libraryofalexandria.node.masterIps 0;
            masterHostname = masterIpsToHostnames.${masterIp};
        in lib.mkIf (config.libraryofalexandria.cluster.k8sEngine == "kubernetes") {
            environment = {
                variables = lib.mkIf isMaster {
                    "KUBECONFIG" = "/etc/kubernetes/cluster-admin.kubeconfig";  # must match helm chart installer
                };
                systemPackages = with pkgs; [
                    kubernetes
                    cri-o
                ] ++ (if isMaster then [
                    kompose
                    kubectl
                    k9s
                    argocd
                    argocd-vault-plugin
                ] else []);
            };

            services.kubernetes = if isMaster then {
                roles = [ "master" "node" ];

                masterAddress = masterHostname;
                easyCerts = true;
                # use coredns
                addons.dns.enable = true;

                apiserverAddress = "https://${masterHostname}:${toString config.libraryofalexandria.node.masterPort}";
                apiserver = {
                    securePort = config.libraryofalexandria.node.masterPort;
                    advertiseAddress = thisMasterIp;
                    allowPrivileged = true; # ceph, longhorn require this
                };
            } else {
                roles = [ "node" ];
                masterAddress = masterHostname;
                easyCerts = true;

                # TODO make multiple masters
                kubelet = {
                    enable = true;
                    kubeconfig.server = "https://${masterHostname}:${toString config.libraryofalexandria.node.masterPort}";
                    extraOpts = "--root-dir=/var/lib/kubelet";
                };
                apiserverAddress = "https://${masterHostname}:${toString config.libraryofalexandria.node.masterPort}";

                addons.dns.enable = true;
            };

            # containerd requirement
            boot.kernelParams = [
                "cgroup_enable=cpuset"
                "cgroup_enable=memory"
            ];
    };
}