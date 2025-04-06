{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ./submodules/k8s/helm-charts.nix
    ];

    config = {
        libraryofalexandria.helmCharts = {
            enable = true;
            charts = [
                {
                    name = "main-nginx-ingress";
                    chart = "oci://ghcr.io/nginx/charts/nginx-ingress";
                    version = "2.0.1";
                    values = {
                        commonLabels = {
                            loa-app = "main-nginx-ingress";
                        };
                    };
                    namespace = "loa-infra";
                }
                {
                    name = "kube-admin-ui";
                    chart = "kube-admin-ui/kubernetes-dashboard";
                    version = "7.11.1";
                    values = {};
                    namespace = "loa-infra";
                    repo = "https://kubernetes.github.io/dashboard/";
                }
            ];
        };
    };
}