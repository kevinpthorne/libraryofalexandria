{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.rancher = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "2.12.1";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.rancher.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [{
            name = "rancher";
            chart = "rancher/rancher";
            version = config.libraryofalexandria.apps.rancher.version;
            # https://ranchermanager.docs.rancher.com/getting-started/installation-and-upgrade/installation-references/helm-chart-options
            values = lib2.deepMerge [{
                hostname = "rancher.${config.libraryofalexandria.cluster.name}.internal";  # TODO set in cluster config instead of here!
                bootstrapPassword = "rancherChangeMe!";
            } config.libraryofalexandria.apps.rancher.values];
            namespace = "cattle-system";
            repo = "https://releases.rancher.com/server-charts/stable";
        }];
    };
}