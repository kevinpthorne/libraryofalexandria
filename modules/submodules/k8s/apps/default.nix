{
  pkgs,
  config,
  lib,
  lib2,
  inputs,
  ...
}:
{
  imports = [
    ../control-plane # expose argocd
    ../helm # expose helm
  ];

  options.libraryofalexandria.apps = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ./_submodule.nix);
  };

  config = lib.mkIf config.libraryofalexandria.control-plane.argocd.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = lib.mkAfter (
      lib.mapAttrsToList (name: app: {
        inherit name;
        chart = "${pkgs.argocd-app-helm}/argocd-app-helm-0.1.0.tgz";
        values = lib2.deepMerge [
          {
            source = {
              repoURL = app.repo;
              path = app.subPath;
            };
            cluster = config.libraryofalexandria.cluster;
          }
          app.valuesOverrides
        ];
        namespace = "argo-cd";
      }) config.libraryofalexandria.cluster.apps
    );
  };
}
