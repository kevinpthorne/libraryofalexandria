{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../helm-charts.nix ];

    config = lib.mkIf (config.libraryofalexandria.apps.argocd.enable)
     {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = let 
            shared-app-types = {
                core = {
                    name = "loa-core-app";
                    chart = "${pkgs.argocd-app-helm}";
                    namespace = "argo-cd";
                    values = {
                        source = {
                            repoURL = "https://github.com/kevinpthorne/libraryofalexandria.git";
                            path = "apps/loa-core";
                        };
                        cluster = config.libraryofalexandria.cluster;
                    };
                };
                extras = {
                    name = "loa-extras-app";
                    chart = "${pkgs.argocd-app-helm}";
                    namespace = "argo-cd";
                    values = {
                        source = {
                            repoURL = "https://github.com/kevinpthorne/libraryofalexandria.git";
                            path = "apps/loa-extras";
                        };
                        cluster = config.libraryofalexandria.cluster;
                    };
                };
            };
            apps = builtins.map (app-type: shared-app-types.${app-type}) config.libraryofalexandria.cluster.shared-apps;
        in lib.mkAfter apps;
    };
}