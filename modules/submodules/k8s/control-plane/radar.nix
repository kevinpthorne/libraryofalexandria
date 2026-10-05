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
        };
        namespace = "radar";
      }
      {
        name = "radar";
        chart = "${pkgs.radar-helm}/radar-helm-1.12.2.tgz";
        values = lib2.deepMerge (
          [
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
                {
                  name = "stunnel-config";
                  configMap = {
                    name = "radar-stunnel";
                  };
                }
              ];
              stunnel = {
                enabled = true;
                port = 8443;
              };
              extraContainers = [
                {
                  name = "stunnel";
                  image = "dweomer/stunnel:latest";
                  volumeMounts = [
                    {
                      name = "radar-cert";
                      mountPath = "/run/secrets/certs";
                      readOnly = true;
                    }
                    {
                      name = "stunnel-config";
                      mountPath = "/etc/stunnel";
                      readOnly = true;
                    }
                  ];
                  securityContext = {
                    allowPrivilegeEscalation = false;
                    capabilities = {
                      drop = [ "ALL" ];
                    };
                  };
                }
              ];
              service = {
                port = 443;
                targetPort = 8443;
                internalPort = 9280;
              };
              podSecurityContext = {
                runAsNonRoot = true;
                runAsUser = 1000;
                runAsGroup = 1000;
                fsGroup = 1000;
                seccompProfile = {
                  type = "RuntimeDefault";
                };
              };
              securityContext = {
                allowPrivilegeEscalation = false;
                readOnlyRootFilesystem = true;
                runAsNonRoot = true;
                runAsUser = 1000;
                runAsGroup = 1000;
                seccompProfile = {
                  type = "RuntimeDefault";
                };
                capabilities = {
                  drop = [ "ALL" ];
                };
              };
            }
          ]
          ++ lib.optional (config.libraryofalexandria.cluster.apps ? loa-federation && false) {
            auth = {
              mode = "oidc";
              oidc = {
                issuerURL = "https://ident.${config.libraryofalexandria.cluster.name}.loa.internal/realms/loa";
                clientID = "radar";
                existingSecret = "radar-oauth-secret";
                clientSecretKey = "client-secret";
                redirectURL = "https://cluster.${config.libraryofalexandria.cluster.name}.loa.internal/auth/callback";
              };
            };
          }
          ++ [
            config.libraryofalexandria.control-plane.radar.values
          ]
        );
        namespace = "radar";
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
