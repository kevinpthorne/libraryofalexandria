{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.libraryofalexandria.control-plane.local-gateway.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "local-gateway";
        chart = "${pkgs.gateway-helm}/gateway-helm-0.1.0.tgz";
        values = {
          endpoints = [
            {
              name = "local-gateway";
              namespace = "kube-system";
              hostnames = [
                "*.${config.libraryofalexandria.cluster.name}.loa.internal"
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
