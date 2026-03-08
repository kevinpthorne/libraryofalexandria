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
        loa-observability.enable = lib.mkDefault true;
        loa-federation.enable = lib.mkDefault true;
        loa-authn.enable = lib.mkDefault false;  # openldap is too crusty and old
        loa-core.enable = lib.mkDefault true;
        kube-admin-ui.enable = lib.mkDefault true;
        argocd = {
            enable = lib.mkDefault true;
            version = lib.mkDefault "9.1.4";
        };
        cert-manager = {
            enable = lib.mkDefault true;
            version = lib.mkDefault "v1.17.0";
            csiVersion = lib.mkDefault "v0.12.0";
        };
        longhorn = {
            enable = lib.mkDefault true;
            version = lib.mkDefault "1.10.0";
        };
    };
}