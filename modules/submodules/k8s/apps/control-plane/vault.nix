{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.vault = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "0.30.1";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

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
                name = "vault-spiffe-id";
                chart = "${pkgs.spiffe-id-helm}";
                values = {
                    deploymentName = "vault";
                    targetNamespace = "vault";
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
                                name = "spire-secrets";
                                csi = {
                                    driver = "csi.spiffe.io";
                                    readOnly = true;
                                };
                            }
                        ];
                        volumeMounts = [
                            {
                                name = "spire-secrets";
                                mountPath = "/run/secrets/spire";
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
    tls_cert_file = "/run/secrets/spire/svid.pem"
    tls_key_file = "/run/secrets/spire/key.pem"
    tls_require_and_verify_client_cert = "false"
    tls_client_ca_file = "/run/secrets/spire/bundle.pem"
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