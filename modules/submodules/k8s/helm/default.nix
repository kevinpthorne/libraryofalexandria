{ pkgs, config, lib, inputs, lib2, ... }:
{
    imports = [];

    options = {
        libraryofalexandria.helmCharts = {
            enable = lib.mkEnableOption "Install helm charts on this cluster";
            charts = lib.mkOption {
                type = lib.types.listOf (lib.types.submodule ./helm-chart.nix);
            };
            installer = lib.mkEnableOption "Enabled installer systemd service";  # doesn't use local nix store charts unless specified
        };
    };

    config = 
    let
        clusterName = config.libraryofalexandria.cluster.name;
        chartLocks = builtins.fromJSON (builtins.readFile ../../../../clusters/${clusterName}/charts-lock.json);
        helmChartModules = (builtins.map (chart: 
            let 
                chartModule = inputs.nixpkgs.lib.evalModules {
                    modules = [
                        ./helm-chart.nix 
                        # chart
                        {
                            name = chart.name;  # TODO why do we need to copy the attrset?
                            chart = chart.chart;
                            version = chart.version;
                            values = chart.values;
                            namespace = chart.namespace;
                            repo = chart.repo;
                        }
                        {
                            inherit chartLocks;
                        }
                    ];
                    specialArgs = {
                        inherit inputs;
                        inherit pkgs;
                        inherit lib2;
                    };
                };

            in
                chartModule
        ) config.libraryofalexandria.helmCharts.charts);
        helmChartPackages = builtins.map (chartModule: chartModule.config.chartPackage) helmChartModules;
        helmChartValuesPackages = builtins.map (chartModule: chartModule.config.valuesPackage) helmChartModules;
        k8sSystemdService = if config.libraryofalexandria.cluster.k8sEngine == "rke2" then "rke2-server" else "kubernetes";
        isMaster = config.libraryofalexandria.node.type == "master";
        isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;
    in
        lib.mkIf (config.libraryofalexandria.helmCharts.enable && isMaster0) {
            system.build.helmChartModules = helmChartModules;  # exposes for zarf

            # for systemd shipping, values are rendered at runtime. air-gapped shipping will also include valuesPackages
            environment.systemPackages = helmChartValuesPackages ++ (with pkgs; [
                kubernetes-helm
            ]);

            system.build.chartIndex = pkgs.chart-index.override {
                clusterName = config.libraryofalexandria.cluster.name;
                charts = config.libraryofalexandria.helmCharts.charts;
            };

            systemd.services.helm-chart-installer = lib.mkIf config.libraryofalexandria.helmCharts.installer {
                requires = [ "${k8sSystemdService}.service" ];
                after = [ "${k8sSystemdService}.service" ];
                script = let
                    forEachChartModule = func: builtins.map (chart: func chart) helmChartModules;
                    concatCommands = commands: builtins.concatStringsSep "\n" commands;
                    kubeconfig = config.environment.variables."KUBECONFIG";
                in ''
                    set -x
                    echo "pwd = $(pwd)"
                    ${pkgs.kubernetes-helm}/bin/helm env

                    ${concatCommands (forEachChartModule (chart: (
                        "${lib.optionalString (chart.config.repo != null) "${pkgs.kubernetes-helm}/bin/helm repo add ${chart.config.name} ${chart.config.repo}"}"
                    )))}

                    ${pkgs.kubernetes-helm}/bin/helm repo update

                    ${concatCommands (forEachChartModule (chart: (
                        concatCommands [
                            "echo \"Installing ${chart.config.name}\""
                            "${pkgs.kubernetes-helm}/bin/helm upgrade --install ${chart.config.name} ${chart.config.chart} ${lib.optionalString (chart.config.version != null) "--version ${chart.config.version}"} -f ${chart.config.package}/hc-${chart.config.name}-values.yaml ${lib.optionalString (chart.config.namespace != null) "--namespace ${chart.config.namespace} --create-namespace"} --kubeconfig ${kubeconfig} --wait"
                        ]
                    )))}
                '';
            };

            systemd.services.helm-chart-remover = lib.mkIf config.libraryofalexandria.helmCharts.installer {
                requires = [ "${k8sSystemdService}.service" ];
                after = [ "${k8sSystemdService}.service" ];
                script = let
                    forEachChartModule = func: builtins.map (chart: func chart) helmChartModules;
                    concatCommands = commands: builtins.concatStringsSep "\n" commands;
                    kubeconfig = config.environment.variables."KUBECONFIG";
                in ''
                    set -x
                    echo "pwd = $(pwd)"
                    ${pkgs.kubernetes-helm}/bin/helm env

                    ${concatCommands (forEachChartModule (chart: (
                        concatCommands [
                            "echo \"Removing ${chart.config.name}\""
                            "${pkgs.kubernetes-helm}/bin/helm remove ${chart.config.name} ${lib.optionalString (chart.config.namespace != null) "--namespace ${chart.config.namespace} --create-namespace"} --kubeconfig ${kubeconfig} --wait"
                        ]
                    )))}
                '';
            };
        };
}