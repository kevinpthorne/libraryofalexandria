{ pkgs, lib, config, inputs, chartLocks, ... }: {
    options = {
        name = lib.mkOption {
            type = lib.types.str;
        };
        chart = lib.mkOption {
            type = lib.types.str;
        };
        version = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;  # in case of local path
        };
        values = lib.mkOption {
            type = lib.types.attrs;
            default = {};
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
            type = lib.types.package;
            readOnly = true;
        };
        valuesPackage = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
        };
    };

    config = let 
        isLocalChart = config.version == null;
        helmChartPackage = if isLocalChart then config.chart else let
            lock = chartLocks.${config.name};
         in pkgs.fetchurl {
            # We explicitly set the name to ensure it ends with .tgz,
            # which Zarf requires to recognize it as an archive.
            name = builtins.baseNameOf lock.url;
            url = lock.url;
            sha256 = lock.sha256;
        };
        helmChartValuesPackageName = "render-hc-${config.name}-values";
        helmChartValuesPackage = pkgs.runCommand helmChartValuesPackageName {
            buildInputs = with pkgs; [ yj ];
            json = builtins.toJSON config.values;
            passAsFile = [ "json" ]; # will be available as `$jsonPath`
        } ''
            mkdir -p $out
            yj -jy < "$jsonPath" > $out/hc-${config.name}-values.yaml
        '';
    in {
        inherit isLocalChart;
        chartPackage = helmChartPackage;
        valuesPackage = helmChartValuesPackage;
    };
}