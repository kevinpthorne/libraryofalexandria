{ pkgs, lib, config, lib2, ... }:
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
        # super options
        chartLocks = lib.mkOption {
            type = lib.types.attrs;
            readOnly = true;
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
        imagePackages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            readOnly = true;
        };
    };

    config = let 
        isLocalChart = config.version == null;
        lock = config.chartLocks.${config.name};
        helmChartPackage = if isLocalChart then config.chart else pkgs.fetchurl {
            # We explicitly set the name to ensure it ends with .tgz,
            # which Zarf requires to recognize it as an archive.
            name = builtins.baseNameOf lock.url;
            url = lock.url;
            sha256 = lock.hash;
        };
        imagePackages = lib.mapAttrsToList (imgString: imgLock: 
            pkgs.dockerTools.pullImage {
                imageName = imgLock.imageName;
                imageDigest = imgLock.imageDigest;
                sha256 = imgLock.hash;
                arch = lib2.getGoArch { inherit pkgs; };
            }
        ) lock.images;
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
        inherit imagePackages;
    };
}