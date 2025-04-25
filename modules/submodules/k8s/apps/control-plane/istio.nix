{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.istio = {
        enable = lib.mkEnableOption "";

        # version = lib.mkOption {
        #     default = "1.25.1";
        #     type = lib.types.str;
        # };

        values = lib.mkOption {
            default = {
                app.ingress.enabled = true;
            };
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.istio.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [
            # istio https://istio.io/latest/docs/setup/install/helm/
            {
                name = "istio-base";
                chart = "istio-base/base";
                version = "1.25.1";
                values = {
                    defaultRevision = "default";
                };
                namespace = "istio-system";
                repo = "https://istio-release.storage.googleapis.com/charts";
            }
            # {
            #     name = "istio-cni";
            #     chart = "istio-base/cni";  # reuses repo from above
            #     version = "1.25.1";
            #     values = {};
            #     namespace = "istio-system";
            # }
            {
                name = "istiod";
                chart = "istio-base/istiod";  # reuses repo from above
                version = "1.25.1";
                values = {};
                namespace = "istio-system";
            }
            {
                name = "istio-ingressgateway";
                chart = "istio-base/gateway";  # reuses repo from above
                version = "1.25.1";
                values = {};
                namespace = "istio-ingress";
            }
        ];
    };
}