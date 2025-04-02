let 
    helmChart = 
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
                package = lib.mkOption {
                    type = lib.types.package;
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
                helmChartInstallerPackage = pkgs.callPackage({stdenv, kubernetes-helm}:
                    stdenv.mkDerivation {
                        name = "install-hc-${config.name}";
                        src = ./.;

                        buildInputs = [ helmChartValuesPackage kubernetes-helm ];

                        buildPhase = ''
                            mkdir -p $out/log
                            ${pkgs.kubernetes-helm}/bin/helm upgrade --install ${config.name} ${config.chart} --version ${config.version} -f ${pkgs.${helmChartValuesPackageName}}/hc-${config.name}-values.yaml
                        '';
                    }
                );
            in {
                package = helmChartInstallerPackage;
            };
        };
in
{ pkgs, config, lib, inputs, ... }:
{
    imports = [];

    options = {
        libraryofalexandria.helmCharts = {
            enable = lib.mkEnableOption "Install helm charts on this cluster";
            charts = lib.mkOption {
                type = lib.types.listOf (lib.types.submodule helmChart);
            };
        };
    };

    config = lib.mkIf config.libraryofalexandria.helmCharts.enable {
        environment.systemPackages = builtins.map (chart: chart.package) config.libraryofalexandria.helmCharts.charts;
        # systemd.services.helmChartInstaller = {
        #     wantedBy = [ "kubernetes.service" ];
        #     after = [ "kubernetes.service" ];
        #     script = let
        #         forEachChart = func: builtins.map (chart: func chart) config.libraryofalexandria.helmCharts.charts;
        #         concatCommands = commands: builtins.concatStringsSep "\n" commands;
        #     in ''
        #         ${concatCommands forEachChart (chart: (
        #             concatCommands [
        #                 # ""
        #                 "helm upgrade --install ${chart.name} ${chart.chart} --version ${chart.version}"
        #             ]
        #         ))}
        #     '';
        # }
    };
}