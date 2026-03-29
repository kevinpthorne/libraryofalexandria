{
  lib,
  lib2,
  config,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.argocd.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
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
    ];
  };
}
