{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../helm-charts.nix ];

    options.libraryofalexandria.apps.shared-apps = {
        enable = lib.mkEnableOption "";

        toInclude = lib.mkOption {
            type = lib.types.listOf (lib.types.enum [ "core" "extras" ]);
            default = [ "core" ];
        };
    };

    config = lib.mkIf (config.libraryofalexandria.apps.argocd.enable && config.libraryofalexandria.apps.shared-apps.enable)
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
                    };
                };
            };
            apps = builtins.map (app-type: shared-app-types.${app-type}) config.libraryofalexandria.apps.shared-apps.toInclude;
        in lib.mkAfter apps;
    };
}