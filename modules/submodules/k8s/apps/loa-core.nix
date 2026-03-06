{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../helm ];

    config = lib.mkIf (config.libraryofalexandria.apps.argocd.enable && config.libraryofalexandria.apps.loa-core.enable) {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = lib.mkAfter [
            {
                name = "loa-core-app";
                chart = "${pkgs.argocd-app-helm}";
                values = lib2.deepMerge [{
                    source = {
                        repoURL = "https://github.com/kevinpthorne/libraryofalexandria.git";
                        path = "apps/loa-core";
                    };
                    cluster = config.libraryofalexandria.cluster;
                } config.libraryofalexandria.apps.loa-core.values];
                namespace = "argo-cd";
            }
        ];
    };
}