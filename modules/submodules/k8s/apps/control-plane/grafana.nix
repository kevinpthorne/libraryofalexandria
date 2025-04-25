{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.grafana = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "8.13.1";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.grafana.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [{
            name = "grafana";
            chart = "grafana/grafana";
            version = config.libraryofalexandria.apps.grafana.version;
            # https://artifacthub.io/packages/helm/grafana/grafana
            values = lib2.deepMerge [{} config.libraryofalexandria.apps.grafana.values];
            namespace = "grafana";
            repo = "https://grafana.github.io/helm-charts";
        }];
    };
}