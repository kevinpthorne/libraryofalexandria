{ pkgs, lib, config, ... }: {
    options = {
        name = lib.mkOption {
            type = lib.types.str;
        };
        chart = lib.mkOption {
            type = lib.types.str;
        };
        version = lib.mkOption {
            type = lib.types.str;
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
        package = lib.mkOption {
            type = lib.types.package;
            readOnly = true;
        };
        packageName = lib.mkOption {
            type = lib.types.string;
            readOnly = true;
        };
    };

    config = let 
        helmChartValuesPackageName = "render-hc-${config.name}-values";
        helmChartValuesPackage = pkgs.runCommand helmChartValuesPackageName {
            buildInputs = with pkgs; [ yj ];
            json = builtins.toJSON config.values;
            passAsFile = [ "json" ]; # will be available as `$jsonPath`
        } ''
            mkdir -p $out
            yj -jy < "$jsonPath" > $out/hc-${config.name}-values.yaml
        '';
        # helmChartInstallerPackage = pkgs.callPackage({stdenv, kubernetes-helm}:
        #     stdenv.mkDerivation {
        #         name = "install-hc-${config.name}";
        #         src = ./.;

        #         buildInputs = [ helmChartValuesPackage kubernetes-helm ];

        #         buildPhase = ''
        #             mkdir -p $out/log
        #             ${pkgs.kubernetes-helm}/bin/helm upgrade --install ${config.name} ${config.chart} --version ${config.version} -f ${pkgs.${helmChartValuesPackageName}}/hc-${config.name}-values.yaml
        #         '';
        #     }
        # );
    in {
        package = helmChartValuesPackage;
        packageName = helmChartValuesPackageName;
    };
}