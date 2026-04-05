{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.cert-manager.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "cert-manager";
        chart = "cert-manager/cert-manager";
        version = config.libraryofalexandria.control-plane.cert-manager.version;
        values = lib2.deepMerge [
          {
            crds.enabled = true;
          }
          config.libraryofalexandria.control-plane.cert-manager.values
        ];
        namespace = "cert-manager";
        repo = "https://charts.jetstack.io";
      }
      # helm upgrade cert-manager-csi-driver oci://quay.io/jetstack/charts/cert-manager-csi-driver
      {
        name = "cert-manager-system-namespace";
        chart = "${pkgs.namespace-helm}/namespace-helm-0.1.0.tgz";
        values = {
          name = "cert-manager-system";
          podSecurityLevel = {
            enforce = "privileged";
            audit = "privileged";
            warn = "privileged";
          };
        };
      }
      {
        name = "cert-manager-csi-driver";
        chart = "cert-manager/cert-manager-csi-driver";
        version = config.libraryofalexandria.control-plane.cert-manager.csiVersion;
        values = { };
        namespace = "cert-manager-system";
        repo = "https://charts.jetstack.io";
      }
    ];
  };
}
