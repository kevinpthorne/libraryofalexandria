{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [
    # top installs last
    ./headlamp.nix
    ./argocd.nix
    ./eso.nix
    ./trust-manager.nix
    ./cert-manager.nix
    ./longhorn.nix
  ];

  options.libraryofalexandria.control-plane = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkEnableOption "";

          version = lib.mkOption {
            type = lib.types.str;
          };

          values = lib.mkOption {
            default = { };
            type = lib.types.attrs;
          };

          # used by some helm charts
          crdsVersion = lib.mkOption {
            type = lib.types.str;
          };

          csiVersion = lib.mkOption {
            type = lib.types.str;
          };
        };
      }
    );
  };

  config.libraryofalexandria.control-plane = {
    headlamp = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "0.40.0";
    };
    argocd = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "9.4.10";
    };
    external-secrets-operator = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "1.2.0";
    };
    trust-manager = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "v0.22.0";
    };
    cert-manager = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "v1.20.0";
      csiVersion = lib.mkDefault "v0.13.0";
    };
    longhorn = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "1.11.0";
    };
  };
}
