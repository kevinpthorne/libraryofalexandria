{ pkgs, config, lib, inputs, ... }:
{
    imports = [];

    options = {
        libraryofalexandria.helmCharts = {
            enable = lib.mkEnableOption "Install helm charts on this cluster";
            charts = lib.mkOption {
                type = lib.types.listOf (lib.types.submodule ./helm-chart.nix);
            };
        };
    };

    config = 
    let
        helmChartValuesModules =  (builtins.map (chart: 
            let 
                chartModule = inputs.nixpkgs.lib.evalModules {
                    modules = [ ./helm-chart.nix {
                        name = chart.name;  # TODO why do we need to copy the attrset?
                        chart = chart.chart;
                        version = chart.version;
                        values = chart.values;
                        namespace = chart.namespace;
                        repo = chart.repo;
                    } ];
                    specialArgs = {
                        inherit pkgs;
                    };
                };

            in
                chartModule
        ) config.libraryofalexandria.helmCharts.charts);
    in
        lib.mkIf config.libraryofalexandria.helmCharts.enable {
            environment.systemPackages = builtins.map (chartModule: chartModule.config.package) helmChartValuesModules;

            systemd.services.helm-chart-installer = {
                wantedBy = [ "kubernetes.service" ];
                after = [ "kubernetes.service" ];
                script = let
                    forEachChartModule = func: builtins.map (chart: func chart) helmChartValuesModules;
                    concatCommands = commands: builtins.concatStringsSep "\n" commands;
                in ''
                    ${concatCommands (forEachChartModule (chart: (
                        "${lib.optionalString (chart.config.repo != null) "${pkgs.kubernetes-helm}/bin/helm repo add ${chart.config.name} ${chart.config.repo}"}"
                    )))}

                    ${concatCommands (forEachChartModule (chart: (
                        concatCommands [
                            "${pkgs.kubernetes-helm}/bin/helm upgrade --install ${chart.config.name} ${chart.config.chart} --version ${chart.config.version} -f ${chart.config.package}/hc-${chart.config.name}-values.yaml ${lib.optionalString (chart.config.namespace != null) "--namespace ${chart.config.namespace} --create-namespace"} --kubeconfig /etc/kubernetes/cluster-admin.kubeconfig"
                        ]
                    )))}
                '';
            };
        };
}