{ config, pkgs, lib, ... }:
let 
    indexOf = val: lib.lists.findFirstIndex (x: x == val) null;
    getHostname = nodeType: nodeId: clusterName: nodeType + toString nodeId + "-" + clusterName;
in
{
    imports = [
        ./submodules/deployment/colmena.nix
        ./submodules/k8s/engines/rke2.nix
        ./submodules/k8s/engines/kubernetes.nix
    ];

    options.libraryofalexandria.node = {
        enable = lib.mkEnableOption "Make this NixOS configuration a node ready for being in a LoA cluster";

        type = lib.mkOption {
            default = "worker";
            type = lib.types.enum [ "master" "worker" ];
            description = "Defines if this node is a master or worker";
        };

        id = lib.mkOption {
            type = lib.types.ints.unsigned;
        };

        clusterName = lib.mkOption {
            type = lib.types.str;
        };

        hostname = lib.mkOption {
            type = lib.types.str;
            default = with config.libraryofalexandria.node;
                getHostname type id clusterName;  # e.g. worker0-k
        };

        masterIps = lib.mkOption {
            type = lib.types.listOf lib.types.str;  # TODO should be a set
            description = "IP of masters (in order)";
        };

        masterPort = lib.mkOption {
            type = lib.types.port;
            default = 6443;
        };
    };

    options.libraryofalexandria.cluster = lib.mkOption {
        type = lib.types.attrs;
    };

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
        in lib.mkIf config.libraryofalexandria.node.enable {

            networking = {
                hostName = config.libraryofalexandria.node.hostname;
                extraHosts = extraHostsStr;
                firewall.enable = false;
                # firewall done by cilium
                # firewall = lib.mkIf isMaster {
                #     enable = true;
                #     allowedTCPPorts = [ 8888 config.libraryofalexandria.node.masterPort ];
                # };
                # TODO maybe set ip statically?
                enableIPv6  = false;  # rke2 etcd prefers ipv6 over v4 but v4 is easier for humans
            };

            environment = {
                systemPackages = with pkgs; [
                    vim
                    curl
                    htop
                ];
            };

            users.users.kevint = {
                isNormalUser = true;
                openssh.authorizedKeys.keys = [ 
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFz9z1zkXXO45SjKKbryrXZip/HEvZSAV2D/WpygFSFK kevint@Laptop4.local" 
                ];
            };

            # show IP on login screen
            environment.etc."issue.d/ip.issue".text = "\\4\n";
            networking.dhcpcd.runHook = "${pkgs.utillinux}/bin/agetty --reload";

            nix.settings = {
                experimental-features = [ "nix-command" "flakes" ];
                trusted-users = [ "root" ];
            };

            system.stateVersion = "24.11";
        };
}