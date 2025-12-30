{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../../helm-charts.nix ];

    config = lib.mkIf config.libraryofalexandria.apps.cert-manager.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [
            {
                name = "cert-manager";
                chart = "cert-manager/cert-manager";
                version = config.libraryofalexandria.apps.cert-manager.version;
                values = lib2.deepMerge [{
                    crds.enabled = true;
                } config.libraryofalexandria.apps.cert-manager.values];
                namespace = "cert-manager";
                repo = "https://charts.jetstack.io";
            }
            # helm upgrade cert-manager-csi-driver oci://quay.io/jetstack/charts/cert-manager-csi-driver
            {
                name = "cert-manager-system-namespace";
                chart = "${pkgs.namespace-helm}";
                values = {
                    name = "cert-manager-system";
                    podSecurityLevel = {
                        enforce = "privileged";
                        audit = "privileged";
                        warn = "privileged";
                    };
                };
            }
            {
                name = "cert-manager-csi-driver";
                chart = "cert-manager/cert-manager-csi-driver";
                version = config.libraryofalexandria.apps.cert-manager.csiVersion;
                values = {};
                namespace = "cert-manager-system";
            }
            {
                name = "pki-bootstrap";
                chart = "${pkgs.pki-bootstrap-helm}";
            }
        ];
    };
}