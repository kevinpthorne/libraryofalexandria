{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../helm-charts.nix ];

    config = lib.mkIf (config.libraryofalexandria.apps.argocd.enable && config.libraryofalexandria.apps.loa-observability.enable) {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = lib.mkAfter [
            {
                name = "loa-observability-app";
                chart = "${pkgs.argocd-app-helm}";
                values = lib2.deepMerge [{
                    source = {
                        repoURL = "https://github.com/kevinpthorne/libraryofalexandria.git";
                        path = "apps/loa-observability";
                    };
                    cluster = config.libraryofalexandria.cluster;
                } config.libraryofalexandria.apps.loa-observability.values];
                namespace = "argo-cd";
            }
        ];
    };
}