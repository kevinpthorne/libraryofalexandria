{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.vault = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "0.30.1";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {
                server = {
                    ha = {
                        enabled = true;
                        replicas = 3;
                    };
                };
            };
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.vault.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [{
            name = "vault";
            chart = "vault/vault";
            version = config.libraryofalexandria.apps.vault.version;
            values = lib2.deepMerge [{} config.libraryofalexandria.apps.vault.values];
            namespace = "vault";
            repo = "https://helm.releases.hashicorp.com";
        }];
    };
}