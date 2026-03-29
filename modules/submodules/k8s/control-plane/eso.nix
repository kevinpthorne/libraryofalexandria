#repo https://charts.external-secrets.io/
# chart external-secrets-operator
{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.external-secrets-operator.enable {
    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "external-secrets";
        chart = "external-secrets/external-secrets";
        version = config.libraryofalexandria.control-plane.external-secrets-operator.version;
        values = lib2.deepMerge [
          {
            installCRDs = true;

            global.securityContext = {
              runAsUser = 1000;
              runAsGroup = 1000;
              fsGroup = 1000;
            };

            commonSecurityContext = {
              allowPrivilegeEscalation = false;
              capabilities.drop = [ "ALL" ];
              readOnlyRootFilesystem = true;
              runAsNonRoot = true;
              seccompProfile.type = "RuntimeDefault";
            };
          }
          config.libraryofalexandria.control-plane.external-secrets-operator.values
        ];
        namespace = "external-secrets";
        repo = "https://charts.external-secrets.io";
      }
    ];
  };
}
