{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../helm-charts.nix ];

    options.libraryofalexandria.apps.loa-extras = {
        enable = lib.mkEnableOption "";

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf (config.libraryofalexandria.apps.argocd.enable && config.libraryofalexandria.apps.loa-extras.enable) {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = lib.mkAfter [
            {
                name = "loa-extras-app";
                chart = "${pkgs.argocd-app-helm}";
                values = lib2.deepMerge [{
                    source = {
                        repoURL = "https://github.com/kevinpthorne/libraryofalexandria.git";
                        path = "apps/loa-extras";
                    };
                    cluster = config.libraryofalexandria.cluster;
                } config.libraryofalexandria.apps.loa-extras.values];
                namespace = "argo-cd";
            }
        ];
    };
}