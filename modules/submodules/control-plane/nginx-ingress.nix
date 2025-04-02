{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ../k8s/helm-chart.nix
    ];

    config = {
        libraryofalexandria.helmCharts = {
            enable = true;
            charts = [
                {
                    name = "main-nginx-ingress";
                    chart = "oci://ghcr.io/nginx/charts/nginx-ingress";
                    version = "2.0.1";
                }
            ];
        };
    };

}