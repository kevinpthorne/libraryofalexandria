{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../helm-charts.nix ];

    options.libraryofalexandria.apps.shared-apps = {
        enable = lib.mkEnableOption "";

        toInclude = lib.mkOption {
            type = lib.types.listOf (lib.types.enum [ "core" ]);
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
                            repoURL = "https://kevinpthorne.github.io/libraryofalexandria/apps";
                            chart = "loa-core";
                            targetRevision = "0.1.1";
                        };
                    };
                };
            };
            apps = builtins.map (app-type: shared-app-types.${app-type}) config.libraryofalexandria.apps.shared-apps.toInclude;
        in lib.mkAfter apps;
    };
}