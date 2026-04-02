{
  pkgs,
  config,
  lib,
  inputs,
  lib2,
  ...
}:
let
  clusterName = config.libraryofalexandria.cluster.name;
  chartLocks = builtins.fromJSON (
    builtins.readFile ../../../../clusters/${clusterName}/charts-lock.json
  );
in
{
  imports = [ ];

  options = {
    libraryofalexandria.helmCharts = {
      enable = lib.mkEnableOption "Install helm charts on this cluster";
      charts = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submoduleWith {
            modules = [ ./helm-chart.nix ];
            specialArgs = {
              inherit pkgs lib2 inputs;
              locks = chartLocks;
            };
          }
        );
      };
      installerEnabled = lib.mkEnableOption "Enabled installer systemd service"; # doesn't use local nix store charts unless specified
    };
  };

  config =
    let
      helmChartPackages = builtins.map (
        chartModule: chartModule.chartPackage
      ) config.libraryofalexandria.helmCharts.charts;
      helmChartValuesPackages = builtins.map (
        chartModule: chartModule.valuesPackage
      ) config.libraryofalexandria.helmCharts.charts;
      k8sSystemdService =
        if config.libraryofalexandria.cluster.k8sEngine == "rke2" then "rke2-server" else "kubernetes";
      isMaster = config.libraryofalexandria.node.type == "master";
      isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;
    in
    lib.mkIf (config.libraryofalexandria.helmCharts.enable && isMaster0) {
      # for systemd shipping, values are rendered at runtime. air-gapped shipping will also include valuesPackages
      environment.systemPackages =
        helmChartValuesPackages
        ++ (with pkgs; [
          kubernetes-helm
        ]);

      system.build.chartIndex = pkgs.chart-index.override {
        clusterName = config.libraryofalexandria.cluster.name;
        charts = config.libraryofalexandria.helmCharts.charts;
      };

      systemd.services.helm-chart-installer =
        lib.mkIf config.libraryofalexandria.helmCharts.installerEnabled
          {
            enable = true;
            requires = [ "k8s-api-waiter.service" ];
            after = [ "k8s-api-waiter.service" ];
            script =
              let
                forEachChartModule =
                  func: builtins.map (chart: func chart) config.libraryofalexandria.helmCharts.charts;
                concatCommands = commands: builtins.concatStringsSep "\n" commands;
                kubeconfig = config.environment.variables."KUBECONFIG";
              in
              ''
                set -x
                echo "pwd = $(pwd)"
                ${pkgs.kubernetes-helm}/bin/helm env

                ${concatCommands (
                  forEachChartModule (
                    chart:
                    (
                      "${lib.optionalString (
                        chart.repo != null
                      ) "${pkgs.kubernetes-helm}/bin/helm repo add ${chart.name} ${chart.repo}"}"
                    )
                  )
                )}

                ${pkgs.kubernetes-helm}/bin/helm repo update

                ${concatCommands (
                  forEachChartModule (
                    chart:
                    (concatCommands (
                      [
                        "echo \"Installing ${chart.name}\""
                      ]
                      ++ lib.optional chart._ensureOnce "if ! ${pkgs.kubernetes-helm}/bin/helm status ${chart.name} ${
                        lib.optionalString (chart.namespace != null) "--namespace ${chart.namespace}"
                      } --kubeconfig ${kubeconfig} >/dev/null 2>&1; then"
                      ++ [
                        "${pkgs.kubernetes-helm}/bin/helm upgrade --install ${chart.name} ${chart.chart} ${
                          lib.optionalString (chart.version != null) "--version ${chart.version}"
                        } -f ${chart.valuesPackage}/hc-${chart.name}-values.yaml ${
                          lib.optionalString (chart.namespace != null) "--namespace ${chart.namespace} --create-namespace"
                        } --kubeconfig ${kubeconfig} --wait"
                      ]
                      ++ lib.optional chart._ensureOnce "else echo \"${chart.name} already installed, skipping upgrade\"; fi"
                    ))
                  )
                )}
              '';
          };

      systemd.services.helm-chart-remover =
        lib.mkIf config.libraryofalexandria.helmCharts.installerEnabled
          {
            requires = [ "k8s-api-waiter.service" ];
            after = [ "k8s-api-waiter.service" ];
            enable = true; # requires manual invocation
            script =
              let
                forEachChartModule =
                  func: builtins.map (chart: func chart) config.libraryofalexandria.helmCharts.charts;
                concatCommands = commands: builtins.concatStringsSep "\n" commands;
                kubeconfig = config.environment.variables."KUBECONFIG";
              in
              ''
                set -x
                echo "pwd = $(pwd)"
                ${pkgs.kubernetes-helm}/bin/helm env

                ${concatCommands (
                  forEachChartModule (
                    chart:
                    (concatCommands [
                      "echo \"Removing ${chart.name}\""
                      "${pkgs.kubernetes-helm}/bin/helm uninstall ${chart.name} ${
                        lib.optionalString (chart.namespace != null) "--namespace ${chart.namespace} --create-namespace"
                      } --kubeconfig ${kubeconfig} --wait"
                    ])
                  )
                )}
              '';
          };
    };
}
