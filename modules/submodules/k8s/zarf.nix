{ pkgs, config, lib, inputs, ... }:
{
    imports = [
      ./helm
    ];

    options = {
        libraryofalexandria.zarf = {
            enable = lib.mkEnableOption "Enable zarf deployment";
        };
    };

    config = let
      isMaster = config.libraryofalexandria.node.type == "master";
      isMaster0 = isMaster && config.libraryofalexandria.node.id == 0;
      helmCharts = config.system.build.helmChartModules;
      helmChartPackages = builtins.map (chartModule: chartModule.config.chartPackage) helmCharts;
      zarfBundlePackage = pkgs.zarf-bundle.override {
        clusterName = config.libraryofalexandria.cluster.name;
        inherit helmCharts;
      };
      k8sSystemdService = if config.libraryofalexandria.cluster.k8sEngine == "rke2" then "rke2-server" else "kubernetes";
    in lib.mkIf (config.libraryofalexandria.zarf.enable && isMaster0) {
      environment.systemPackages = (with pkgs; [
          zarf
          skopeo
          zarf-init
          zarfBundlePackage
      ]) ++ helmChartPackages;

      systemd.services.zarf-init = {
        description = "Initialize Zarf Air-Gap Registry and Agent";
        wantedBy = [ "multi-user.target" ];
        after = [ "k8s-api-waiter.service" ];
        requires = [ "k8s-api-waiter.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "15s";
        };

        path = [ pkgs.zarf pkgs.kubectl ];
        environment = {
          KUBECONFIG = config.environment.variables.KUBECONFIG;
        };

        script = ''
          set -euo pipefail

          # IDEMPOTENCY CHECK: Does the Zarf namespace exist?
          if ${pkgs.kubectl}/bin/kubectl get namespace zarf &> /dev/null; then
            echo "[+] Zarf is already initialized on this cluster. Skipping init."
            exit 0
          fi

          echo "[+] Fresh cluster detected. Running Zarf Init..."
          
          # We must point Zarf to the local init package from the Nix store
          # otherwise it will try to download it from GitHub.
          INIT_PKG=$(ls ${zarfInitPackage}/zarf-init-*.tar.zst | head -n 1)

          ${pkgs.zarf}/bin/zarf init \
            --components=git-server,registry,agent \
            --package="$INIT_PKG" \
            --confirm
          
          echo "[+] Zarf initialization complete!"
        '';
      };

      systemd.services.zarf-deploy = {
        description = "Deploy Air-Gapped Zarf Charts and Images";
        wantedBy = [ "multi-user.target" ];
        after = [ "zarf-init.service" ];
        requires = [ "zarf-init.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "15s";
          TimeoutStartSec = "30min"; # Deploying images can take a while
        };

        path = [ pkgs.zarf ];
        environment = {
          KUBECONFIG = config.environment.variables.KUBECONFIG;
        };

        script = ''
          set -euo pipefail

          BUNDLE_PATH=$(ls ${zarfBundlePackage}/zarf-package-*.tar.zst | head -n 1)
          echo "[+] Executing Zarf deployment from $BUNDLE_PATH..."
          
          # Zarf deploy is natively idempotent. If the package is already applied 
          # and matches the exact hash, it does nothing.
          ${pkgs.zarf}/bin/zarf package deploy "$BUNDLE_PATH" --confirm

          echo "[+] Zarf deployment successful!"
        '';
      };

    };
}