{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.kube-admin-ui = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "7.11.1";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {
                app.ingress.enabled = true;
            };
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.kube-admin-ui.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [{
            name = "kube-admin-ui";
            chart = "kube-admin-ui/kubernetes-dashboard";
            version = config.libraryofalexandria.apps.kube-admin-ui.version;
            # https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard?modal=values
            values = lib2.deepMerge [{} config.libraryofalexandria.apps.kube-admin-ui.values];
            namespace = "kubernetes-dashboard";
            repo = "https://kubernetes.github.io/dashboard/";
        }];
    };
}