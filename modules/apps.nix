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

                crdsVersion = lib.mkOption {
                    type = lib.types.str;
                };

                values = lib.mkOption {
                    default = {};
                    type = lib.types.attrs;
                };
            };
        });
    };

    config.libraryofalexandria.apps = {
        "${config.libraryofalexandria.cluster.name}-apps".enable = true;
        loa-extras.enable = false;
        loa-observability.enable = true;
        loa-federation.enable = true;
        loa-authn.enable = true;
        loa-core.enable = true;
        argocd = {
            enable = true;
            version = "9.1.4";
        };
        vault = {
            enable = true;
            version = "0.30.1";
        };
        spire = {
            enable = true;
            version = "0.27.0";
            crdsVersion = "0.5.0";
        };
        cert-manager = {
            enable = true;
            version = "v1.17.0";
        };
        longhorn = {
            enable = true;
            version = "1.10.0";
        };
    };
}