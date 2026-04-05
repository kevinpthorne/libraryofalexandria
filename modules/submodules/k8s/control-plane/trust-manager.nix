{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.trust-manager.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "trust-manager";
        chart = "trust-manager/trust-manager";
        version = config.libraryofalexandria.control-plane.trust-manager.version;
        values = lib2.deepMerge [
          { }
          config.libraryofalexandria.control-plane.trust-manager.values
        ];
        namespace = "cert-manager";
        repo = "https://charts.jetstack.io";
      }
      {
        name = "pki-bootstrap";
        chart = "${pkgs.pki-bootstrap-helm}/pki-bootstrap-helm-0.1.0.tgz";
      }
    ];
  };
}
