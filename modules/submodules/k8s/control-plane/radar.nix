{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.radar.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "radar-tls";
        chart = "${pkgs.service-tls-helm}/service-tls-helm-0.1.0.tgz";
        values = {
          svcName = "radar";
          ca = {
            name = "app-pki-bootstrap-issuer";
          };
          cluster = {
            name = config.libraryofalexandria.cluster.name;
          };
        };
        namespace = "radar";
      }
      {
        name = "radar";
        chart = "skyhook/radar";
        version = config.libraryofalexandria.control-plane.radar.version;
        values = lib2.deepMerge [
          {
            extraVolumes = [
              {
                name = "radar-cert";
                secret = {
                  secretName = "radar-tls";
                  items = [
                    {
                      key = "tls.crt";
                      path = "tls.crt";
                    }
                    {
                      key = "tls.key";
                      path = "tls.key";
                    }
                  ];
                };
              }
            ];
            extraVolumeMounts = [
              {
                name = "radar-cert";
                mountPath = "/run/secrets/certs";
                readOnly = true;
              }
            ];
            extraArgs = [
              "--tls-cert-file=/run/secrets/certs/tls.crt"
              "--tls-key-file=/run/secrets/certs/tls.key"
            ];
            service = {
              port = 443;
              targetPort = 443;
            };
            podSecurityContext = {
              runAsNonRoot = true;
              runAsUser = 1000;
              runAsGroup = 1000;
              fsGroup = 1000;
            };
            securityContext = {
              allowPrivilegeEscalation = false;
              readOnlyRootFilesystem = true;
              runAsNonRoot = true;
              runAsUser = 1000;
              runAsGroup = 1000;
              capabilities = {
                drop = [ "ALL" ];
              };
            };
          }
          (lib.mkIf (config.libraryofalexandria.cluster.apps ? loa-federation) {
            auth = {
              mode = "oidc";
              oidc = {
                issuerURL = "https://ident.${config.libraryofalexandria.cluster.externalDomain}/realms/loa";
                clientID = "radar";
                existingSecret = "radar-oauth-secret";
                clientSecretKey = "client-secret";
              };
            };
          })
          config.libraryofalexandria.control-plane.radar.values
        ];
        namespace = "radar";
        repo = "https://skyhook-io.github.io/helm-charts";
      }
      {
        name = "radar-gateway";
        chart = "${pkgs.gateway-helm}/gateway-helm-0.1.0.gz";
        values = {
          endpoints = [
            {
              name = "radar";
              createGateway = false;
              gatewayName = "local-gateway";
              gatewayNamespace = "kube-system";
              hostnames = [
                "cluster.${config.libraryofalexandria.cluster.name}.loa.internal"
              ];
              ports = [
                {
                  port = 443;
                  protocol = "TLS";
                  tls = {
                    mode = "Passthrough";
                  };
                }
              ];
            }
          ];
        };
        namespace = "radar";
      }
    ];
  };
}
