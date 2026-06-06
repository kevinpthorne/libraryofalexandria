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
        # https://artifacthub.io/packages/helm/argo-cd-oci/argo-cd
        values = lib2.deepMerge [
          {
            global.domain = "argocd.${config.libraryofalexandria.cluster.name}.loa.internal";
            configs.params."reconcile\.timeout" = "300s";

            # save CPU/RAM on checking complex tree
            configs.cm."resource\.behaviors" = ''
                - apiGroups:
                  - "*.aws.upbound.io"
                  - "*.keycloak.crossplane.io"
                  - "*.netbird.crossplane.io"
                  - "*.sql.crossplane.io"
                  behavior: "IgnoreChildren"
            '';
            configs.cm."resource\.customizations" = ''
                *.crossplane.io/*:
                  health.statusAssessment: "Ignore"
                *.upbound.io/*:
                  health.statusAssessment: "Ignore"
            '';
          }
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
                  targetService = "argo-argocd-server";
                }
              ];
            }
          ];
        };
        namespace = "argo-cd";
      }
    ];
  };
}
