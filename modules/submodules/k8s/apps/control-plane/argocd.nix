{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.argocd = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "7.8.23";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.argocd.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [
            {
                name = "argo";
                chart = "argo/argo-cd";
                version = config.libraryofalexandria.apps.argocd.version;
                # https://artifacthub.io/packages/helm/k8s-dashboard/argo-cd?modal=values
                values = lib2.deepMerge [{} config.libraryofalexandria.apps.argocd.values];
                namespace = "argo-cd";
                repo = "https://argoproj.github.io/argo-helm";
            }
        ];
    };
}