{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.argocd.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "argo-tls";
        chart = "${pkgs.service-tls-helm}/service-tls-helm-0.1.0.tgz";
        values = {
            svcName = "argo-argocd-server";
        };
        namespace = "argo-cd";
      }
      {
        name = "argo";
        chart = "argo/argo-cd";
        version = config.libraryofalexandria.control-plane.argocd.version;
        # https://artifacthub.io/packages/helm/k8s-dashboard/argo-cd?modal=values
        values = lib2.deepMerge [
          { }
          config.libraryofalexandria.control-plane.argocd.values
        ];
        namespace = "argo-cd";
        repo = "https://argoproj.github.io/argo-helm";
      }
      {
        name = "argocd-gateway";
        chart = "${pkgs.gateway-helm}/gateway-helm-0.1.0.tgz";
        values = {
          endpoints = [
            {
              name = "argocd";
              hostnames = [
                "argocd.${config.libraryofalexandria.cluster.name}.loa.internal"
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
