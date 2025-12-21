{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../../helm-charts.nix ];

    config = lib.mkIf config.libraryofalexandria.apps.vault.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [
            {
                name = "vault-namespace";
                chart = "${pkgs.namespace-helm}";
                values = {
                    name = "vault";
                    podSecurityLevel = {
                        enforce = "baseline";  # IPC_LOCK (e.g. mlock)
                    };
                };
            }
            {
                name = "vault";
                chart = "vault/vault";
                version = config.libraryofalexandria.apps.vault.version;
                values = lib2.deepMerge [{
                    global = {
                        tlsDisable = false;
                    };
                    ui.enabled = true;
                    server = {
                        dataStorage.enabled = true;
                        standalone.enabled = false;
                        volumes = [
                            {
                                name = "tls-volume";
                                csi = {
                                    driver = "csi.cert-manager.io";
                                    readOnly = true;
                                    volumeAttributes = {
                                        "csi.cert-manager.io/issuer-kind" = "ClusterIssuer";
                                        "csi.cert-manager.io/issuer-name" = "pki-bootstrap";
                                        "csi.cert-manager.io/fs-group" = "1000";
                                        "csi.cert-manager.io/dns-names" =  "\${POD_NAME}.\${POD_NAMESPACE}.svc.cluster.local";
                                    };
                                };
                            }
                        ];
                        volumeMounts = [
                            {
                                name = "tls-volume";
                                mountPath = "/run/secrets/certs";
                                readOnly = true;
                            }
                        ];
                        ha = {
                            enabled = true;
                            replicas = 3;
                            config = ''
ui = true

listener "tcp" {
    tls_disable = "false"
    address = "[::]:8200"
    cluster_address = "[::]:8201"
    tls_cert_file = "/run/secrets/certs/tls.crt"
    tls_key_file = "/run/secrets/certs/tls.key"
    tls_require_and_verify_client_cert = "false"
    tls_client_ca_file = "/run/secrets/certs/ca.crt"
    tls_min_version = "tls13"
}
storage "raft" {
    path = "vault/"
}
cluster_addr = "https://127.0.0.1:8201"

service_registration "kubernetes" {}
                            '';
                        };
                    };
                } config.libraryofalexandria.apps.vault.values];
                namespace = "vault";
                repo = "https://helm.releases.hashicorp.com";
            }
        ];
    };
}