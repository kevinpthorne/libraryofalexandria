{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.prometheus = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "27.11.0";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.prometheus.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [{
            name = "prometheus";
            chart = "prometheus/prometheus";
            version = config.libraryofalexandria.apps.prometheus.version;
            # https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus
            values = lib2.deepMerge [{} config.libraryofalexandria.apps.prometheus.values];
            namespace = "prometheus";
            repo = "https://prometheus-community.github.io/helm-charts";
        }];
    };
}