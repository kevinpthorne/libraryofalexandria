{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.headlamp.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "headlamp-tls";
        chart = "${pkgs.service-tls-helm}/service-tls-helm-0.1.0.tgz";
        values = {
          svcName = "headlamp";
        };
        namespace = "kube-system";
      }
      {
        name = "headlamp";
        chart = "headlamp/headlamp";
        version = config.libraryofalexandria.control-plane.headlamp.version;
        # https://headlamp.dev/docs/latest/installation/in-cluster/#using-helm
        values = lib2.deepMerge [
          {
            service.port = 443;
            config.tlsCertPath = "/run/secrets/certs/tls.crt";
            config.tlsKeyPath = "/run/secrets/certs/tls.key";
            volumes = [
              {
                name = "headlamp-cert";
                secret = {
                  secretName = "headlamp-tls";
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
            volumeMounts = [
              {
                name = "headlamp-cert";
                mountPath = "/run/secrets/certs";
                readOnly = true;
              }
            ];
          }
          config.libraryofalexandria.control-plane.headlamp.values
        ];
        namespace = "kube-system";
        repo = "https://kubernetes-sigs.github.io/headlamp/";
      }
      {
        name = "headlamp-gateway";
        chart = "${pkgs.gateway-helm}/gateway-helm-0.1.0.gz";
        values = {
          endpoints = [
            {
              name = "headlamp";
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
        namespace = "kube-system";
      }
    ];
  };
}
