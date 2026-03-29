{
  pkgs,
  lib,
  config,
  lib2,
  inputs,
  locks,
  ...
}:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str;
    };
    chart = lib.mkOption {
      type = lib.types.str;
    };
    version = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null; # in case of local path
    };
    values = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
    namespace = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    repo = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    # generated
    isLocalChart = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
    };
    chartPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      readOnly = true;
    };
    valuesPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
    };
    images = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submoduleWith {
          modules = [ ./image.nix ];
          specialArgs = {
            inherit pkgs lib2;
          };
        }
      );
      readOnly = true;
    };
    chartLock = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
    };
  };

  config =
    let
      isLocalChart = config.version == null;
      lock = locks.${config.name} or null;
      helmChartPackage =
        if lock == null then
          builtins.trace "Chart ${config.name} not found in chart-locks.json" null
        else if isLocalChart then
          config.chart
        else
          pkgs.fetchurl {
            # We explicitly set the name to ensure it ends with .tgz,
            # which Zarf requires to recognize it as an archive.
            name = builtins.baseNameOf lock.url;
            url = lock.url;
            sha256 = lock.hash;
          };
      helmChartValuesPackageName = "render-hc-${config.name}-values";
      helmChartValuesPackage =
        pkgs.runCommand helmChartValuesPackageName
          {
            buildInputs = with pkgs; [ yj ];
            json = builtins.toJSON config.values;
            passAsFile = [ "json" ]; # will be available as `$jsonPath`
          }
          ''
            mkdir -p $out
            yj -jy < "$jsonPath" > $out/hc-${config.name}-values.yaml
          '';
    in
    {
      inherit isLocalChart;
      chartPackage = helmChartPackage;
      valuesPackage = helmChartValuesPackage;
      images = lib.mapAttrsToList (_imgString: imgLock: imgLock) (lock.images or { });
      chartLock = lib2.nullable lock { };
    };
}
