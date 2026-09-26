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
    ./radar.nix
    ./argocd.nix
    ./gateway.nix
    ./eso.nix
    ./longhorn.nix
    ./seaweedfs.nix
    ./trust-manager.nix
    ./cert-manager.nix
    ./kured.nix
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
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          csiVersion = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };

          extraOptions = lib.mkOption {
            default = { };
            type = lib.types.attrs;
            description = "Extra component-specific options not part of the primary helm chart values";
          };
        };
      }
    );
  };

  config.libraryofalexandria.control-plane = {
    radar = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "1.12.2";
    };
    local-gateway = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "0.1.0";
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
    seaweedfs = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "0.1.42";
    };
    longhorn = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "1.11.2";
    };
    kured = {
      enable = lib.mkDefault true;
      version = lib.mkDefault "5.12.0";
    };
  };
}
