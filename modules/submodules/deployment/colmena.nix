{ pkgs, config, lib, ... }:
{
    options.libraryofalexandria.node.deployment.colmena = {
        enable = lib.mkEnableOption "Make this node deployable via colmena";

        userName = lib.mkOption {
            type = lib.types.str;
            description = "The username to use for deploying NixOS upgrades";
            default = "colmena";
        };

        authorizedKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAa6gt+RvDM5hDn+GBmWnCaPo3KB6RNdG3so0q3Z8kw kevint@Laptop4.local deployment"
            ];
        };
    };

    config = let 
        colmenaConfig = config.libraryofalexandria.node.deployment.colmena;
    in lib.mkIf colmenaConfig.enable {
        users.users.${colmenaConfig.userName} = {
            isNormalUser = true;
            home = "/home/${colmenaConfig.userName}";
            extraGroups = [ "wheel" "networkmanager" ];
            openssh.authorizedKeys.keys = colmenaConfig.authorizedKeys;
        };
        deployment = {
            tags = [
                "cluster=${config.libraryofalexandria.node.clusterName}"
                "type=${config.libraryofalexandria.node.type}"
                "host=${config.libraryofalexandria.node.hostname}"
            ];
            targetHost = config.libraryofalexandria.node.hostname;
            targetPort = 22;
            targetUser = colmenaConfig.userName;
        };
        services.openssh.enable = true;
        security.sudo.extraRules = [   # colmena currently requires non-interactive auth
            {  
                users = [ colmenaConfig.userName ];
                commands = [
                    { 
                        command = "ALL";
                        options= [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
                    }
                ];
            }
        ];
        nix.settings = {
            trusted-users = [ colmenaConfig.userName ];
        };
    };
}