#repo https://charts.external-secrets.io/
# chart external-secrets-operator
{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../../helm-charts.nix ];

    config = lib.mkIf config.libraryofalexandria.apps.external-secrets-operator.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [
            {
                name = "external-secrets";
                chart = "external-secrets/external-secrets";
                version = config.libraryofalexandria.apps.external-secrets-operator.version;
                values = lib2.deepMerge [{
                    installCRDs = true;

                    global.securityContext = {
                        runAsUser = 1000;
                        runAsGroup = 1000;
                        fsGroup = 1000;
                    };

                    commonSecurityContext = {
                        allowPrivilegeEscalation = false;
                        capabilities.drop = [ "ALL" ];
                        readOnlyRootFilesystem = true;
                        runAsNonRoot = true;
                        seccompProfile.type = "RuntimeDefault";
                    };
                } config.libraryofalexandria.apps.external-secrets-operator.values];
                namespace = "external-secrets";
                repo = "https://charts.external-secrets.io";
            }
            {
                name = "secret-replicator";
                chart = "${pkgs.secret-replicator-helm}";
                values = {
                    cluster = config.libraryofalexandria.cluster;
                };
                namespace = "external-secrets";
            }
        ];
    };
}