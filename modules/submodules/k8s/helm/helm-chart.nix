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
      type = with lib.types; either path str;
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
    _ensureOnce = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "If true, acts as a shorthand for _maxRevisions = 1.";
    };
    _maxRevisions = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = if config._ensureOnce then 1 else null;
      description = "If set, do not run helm upgrade if the current release revision is greater than or equal to this value.";
    };
    # generated
    isLocalChart = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
    };
    chartPackage = lib.mkOption {
      type = with lib.types; nullOr (either package path);
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
        if isLocalChart then
          config.chart
        else if lock == null then
          builtins.trace "Chart ${config.name} not found in chart-locks.json" null
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
