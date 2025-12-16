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
            {
                name = "pki-bootstrap";
                chart = "${pkgs.pki-bootstrap-helm}";
            }
        ];
    };
}