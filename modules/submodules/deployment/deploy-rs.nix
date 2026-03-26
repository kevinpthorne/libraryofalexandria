{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.libraryofalexandria.node.deployment.deploy-rs = {
    enable = lib.mkEnableOption "Make this node deployable via deploy-rs";

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

    hostName = lib.mkOption {
      type = lib.types.str;
      default = config.libraryofalexandria.node.hostname;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
    };

    tags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "cluster=${config.libraryofalexandria.node.clusterName}"
        "type=${config.libraryofalexandria.node.type}"
      ];
    };
  };

  config =
    let
      deployConfig = config.libraryofalexandria.node.deployment.deploy-rs;
    in
    lib.mkIf deployConfig.enable {
      users.users.${deployConfig.userName} = {
        isNormalUser = true;
        home = "/home/${deployConfig.userName}";
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        openssh.authorizedKeys.keys = deployConfig.authorizedKeys;
      };
      services.openssh.enable = true;
      security.sudo.extraRules = [
        {
          users = [ deployConfig.userName ];
          commands = [
            {
              command = "ALL";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
      nix.settings = {
        trusted-users = [ deployConfig.userName ];
      };
    };
}
