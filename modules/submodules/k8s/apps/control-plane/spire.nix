#repo https://spiffe.io/docs/latest/spire-helm-charts-hardened-about/installation/
# chart spire
{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.spire = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "0.27.0";
            type = lib.types.str;
        };

        crdsVersion = lib.mkOption {
            default = "0.5.0";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.spire.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [
            {
                name = "spire-crds";
                chart = "spire-crds/spire-crds";
                version = config.libraryofalexandria.apps.spire.crdsVersion;
                values = {};
                namespace = "spire";
                repo = "https://spiffe.github.io/helm-charts-hardened/";
            }
            {
                name = "spire";
                chart = "spire-crds/spire";
                version = config.libraryofalexandria.apps.spire.version;
                values = lib2.deepMerge [{
                    global = {
                        openshift = false;
                        spire = {
                            recommendations.enabled = true;
                            namespaces.create = true;
                            ingressControllerType = "ingress-nginx";
                            clusterName = config.libraryofalexandria.cluster.name;
                            trustDomain = "${config.libraryofalexandria.cluster.name}.loa.local";
                            caSubject = {
                                country = "US";
                                organization = "Library-Of-Alexandria";
                                commonName = "${config.libraryofalexandria.cluster.name}.loa.local";
                            };
                        };
                        # TODO: federation
                    };
                    server = {
                        upstreamAuthority = {
                            certManager = {
                                enabled = true;
                                issuer_name = "pki-bootstrap";
                                issuer_kind = "ClusterIssuer";
                                issuer_group = "cert-manager.io";
                                namespace = "cert-manager";
                            };
                            disk.enabled = false;
                        };
                        serviceAccount = {
                            create = true;
                            name = "spire-server";
                        };
                    };
                } config.libraryofalexandria.apps.spire.values];
                namespace = "spire";
                repo = "https://spiffe.github.io/helm-charts-hardened/";
            }
        ];
    };
}