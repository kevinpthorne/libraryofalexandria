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
        helmChartValuesModules = (builtins.map (chart: 
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
        helmChartValuesPackages = builtins.map (chartModule: chartModule.config.package) helmChartValuesModules;
        k8sSystemdService = if config.libraryofalexandria.cluster.k8sEngine == "rke2" then "rke2-server" else "kubernetes";
        isMaster = config.libraryofalexandria.node.type == "master";
        isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;
    in
        lib.mkIf (config.libraryofalexandria.helmCharts.enable && isMaster0) {
            environment.systemPackages = helmChartValuesPackages ++ (with pkgs; [
                kubernetes-helm
            ]);

            systemd.services.helm-chart-installer = {
                wantedBy = [ "${k8sSystemdService}.service" ];
                after = [ "${k8sSystemdService}.service" ];
                script = let
                    forEachChartModule = func: builtins.map (chart: func chart) helmChartValuesModules;
                    concatCommands = commands: builtins.concatStringsSep "\n" commands;
                    kubeconfig = config.environment.variables."KUBECONFIG";
                in ''
                    echo "pwd = $(pwd)"
                    ${pkgs.kubernetes-helm}/bin/helm env

                    ${concatCommands (forEachChartModule (chart: (
                        "${lib.optionalString (chart.config.repo != null) "${pkgs.kubernetes-helm}/bin/helm repo add ${chart.config.name} ${chart.config.repo}"}"
                    )))}

                    ${pkgs.kubernetes-helm}/bin/helm repo update

                    ${concatCommands (forEachChartModule (chart: (
                        concatCommands [
                            "echo \"Installing chart.config.name\""
                            "${pkgs.kubernetes-helm}/bin/helm upgrade --install ${chart.config.name} ${chart.config.chart} ${lib.optionalString (chart.config.version != null) "--version ${chart.config.version}"} -f ${chart.config.package}/hc-${chart.config.name}-values.yaml ${lib.optionalString (chart.config.namespace != null) "--namespace ${chart.config.namespace} --create-namespace"} --kubeconfig ${kubeconfig} --wait"
                        ]
                    )))}
                '';
            };
        };
}