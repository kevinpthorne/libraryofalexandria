#repo https://charts.crossplane.io/stable
# chart crossplane
{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.crossplane = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "2.1.1";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.crossplane.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [{
            name = "crossplane";
            chart = "crossplane/crossplane";
            version = config.libraryofalexandria.apps.crossplane.version;
            values = lib2.deepMerge [{} config.libraryofalexandria.apps.crossplane.values];
            namespace = "crossplane";
            repo = "https://charts.crossplane.io/stable";
        }];
    };
}