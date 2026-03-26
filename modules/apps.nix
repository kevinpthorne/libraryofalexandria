# TODO(kevinpthorne): redo how this module works. It's messy
{ lib, config, ... }:
{
    imports = [
        ./submodules/k8s/apps/control-plane
        ./submodules/k8s/apps
    ];

    options.libraryofalexandria.apps = lib.mkOption {
        default = {};
        type = lib.types.attrsOf (lib.types.submodule {
            options = {
                enable = lib.mkEnableOption "";

                version = lib.mkOption {
                    type = lib.types.str;
                };

                values = lib.mkOption {
                    default = {};
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
        });
    };

    config.libraryofalexandria.apps = {
        "${config.libraryofalexandria.cluster.name}-apps".enable = true;
        loa-extras.enable = lib.mkDefault false;
        loa-voip.enable = lib.mkDefault false;
        loa-observability.enable = lib.mkDefault true;
        loa-federation.enable = lib.mkDefault true;
        loa-authn.enable = lib.mkDefault false;  # openldap is too crusty and old
        loa-core.enable = lib.mkDefault true;
        headlamp = {
            enable = lib.mkDefault true;
            version = lib.mkDefault "0.40.0";
        };
        argocd = {
            enable = lib.mkDefault true;
            version = lib.mkDefault "9.4.10";
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