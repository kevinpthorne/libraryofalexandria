{ config, pkgs, lib, ... }:
let 
    indexOf = val: lib.lists.findFirstIndex (x: x == val) null;
    getHostname = nodeType: nodeId: clusterName: nodeType + toString nodeId + "-" + clusterName;
    colmenaUser = "colmena";
in
{
    options.libraryofalexandria.node = {
        enable = lib.mkEnableOption "Make this NixOS configuration a node ready for being in a LoA cluster";

        nodeType = lib.mkOption {
            default = "worker";
            type = lib.types.enum [ "master" "worker" ];
            description = "Defines if this node is a master or worker";
        };

        nodeId = lib.mkOption {
            type = lib.types.ints.unsigned;
        };

        clusterName = lib.mkOption {
            type = lib.types.str;
        };

        hostname = lib.mkOption {
            type = lib.types.str;
            default = with config.libraryofalexandria.node;
                getHostname nodeType nodeId clusterName;  # e.g. worker0-k
        };

        masterIps = lib.mkOption {
            type = lib.types.listOf lib.types.str;  # TODO should be a set
            description = "IP of masters (in order)";
        };

        masterPort = lib.mkOption {
            type = libs.types.port;
            default = 6443;
        }
    };

    config = 
        let
            isMaster = config.libraryofalexandria.nodeType == "master";
            # Master IP to String
            masterIpsToHostnames = with config.libraryofalexandria.node; builtins.listToAttrs (
                builtins.map (ip: { 
                    name = ip; 
                    value = getHostname "master" (indexOf ip masterIps) clusterName;
                }) masterIps
            );
            extraHostEntries = map (entry: "${entry.name} ${entry.value}") (lib.attrsets.attrsToList masterIpsToHostnames);
            extraHostsStr = lib.concatStringsSep "\n" extraHostEntries;
        in mkIf config.libraryofalexandria.node.enable {

            networking = {
                hostName = config.libraryofalexandria.node.hostname;
                extraHosts = extraHostsStr;
                firewall = mkif isMaster {
                    enable = true;
                    allowedTCPPorts = [ 8888 6443 ];
                };
            };

            environment = {
                variables = mkIf isMaster {
                    "KUBECONFIG" = "/etc/kubernetes/cluster-admin.kubeconfig";
                };
                systemPackages = with pkgs; [
                    kompose
                    kubectl
                    kubernetes
                    vim
                    curl
                    htop
                    k9s
                    argocd
                    argocd-vault-plugin
                ];
            };

            services.kubernetes = {
                roles = if isMaster then [ "master" "node" ] else [ "node" ];

                masterAddress = masterHostname;
                easyCerts = true;
                # use coredns
                addons.dns.enable = true;

                # if master
                apiserver = mkIf isMaster {
                    securePort = masterPort;
                    advertiseAddress = masterIp;
                };
                # if node
                # TODO make multiple masters
                kubelet.kubeconfig.server = mkIf !isMaster "https://${masterHostname}:${toString masterPort}";
                apiserverAddress = mkIf !isMaster "https://${masterHostname}:${toString masterPort}";
            };

            # containerd requirement
            boot.kernelParams = [
                "cgroup_enable=cpuset"
                "cgroup_enable=memory"
            ];
            boot.kernelModules = [ "ceph" ];
            kubelet.extraOpts = "--root-dir=/var/lib/kubelet";

            # colmena means of deployment
            users.users.${colmenaUser} = {
                isNormalUser = true;
                home = "/home/${colmenaUsername}";
                extraGroups = [ "wheel" "networkmanager" ];
                openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAa6gt+RvDM5hDn+GBmWnCaPo3KB6RNdG3so0q3Z8kw kevint@Laptop4.local deployment"
                ];
            };
            deployment = {
                targetHost = config.libraryofalexandria.node.hostname;
                targetPort = 22;
                targetUser = colmenaUser;
            };
            services.openssh.enable = true;
            security.sudo.extraRules = [
                {  
                    users = [ colmenaUser ];
                    commands = [
                        { 
                            command = "ALL";
                            options= [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
                        }
                    ];
                }
            ];

            users.users.kevint = {
                isNormalUser = true;
                openssh.authorizedKeys.keys = [ 
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFz9z1zkXXO45SjKKbryrXZip/HEvZSAV2D/WpygFSFK kevint@Laptop4.local" 
                ];
            };

            nix.settings = {
                experimental-features = [ "nix-command" "flakes" ];
                trusted-users = [ "root" colmenaUser ];
            };
        };
}