{ lib, lib2, config, ... }:
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
        libraryofalexandria.helmCharts.charts = [{
            name = "vault";
            chart = "vault/vault";
            version = config.libraryofalexandria.apps.vault.version;
            values = lib2.deepMerge [{
                global = {
                    tlsDisable = false;
                    psp.enable = true;
                };
                ui.enabled = true;
                server = {
                    dataStorage.enabled = true;
                    standalone.enabled = false;
                    ha = {
                        enabled = true;
                        replicas = 3;
                        config = ''
ui = true

listener "tcp" {
    tls_disable = "false"
    address = "[::]:8200"
    cluster_address = "[::]:8201"
    tls_cert_file = ""
    tls_key_file = ""
    tls_require_and_verify_client_cert = ""
    tls_client_ca_file = ""
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
        }];
    };
}