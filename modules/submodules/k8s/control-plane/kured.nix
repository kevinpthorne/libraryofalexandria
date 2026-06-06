{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.kured.enable {
    systemd.services.check-reboot-required = {
      description = "Check if a reboot is required and signal Kured";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];

      script = ''
        # set up sentinel dir
        mkdir -p /run/kured

        # Safely read the nix store paths of the kernels and initrds
        BOOTED_KERNEL=$(readlink /run/booted-system/kernel || echo "none")
        CURRENT_KERNEL=$(readlink /run/current-system/kernel || echo "none")

        BOOTED_INITRD=$(readlink /run/booted-system/initrd || echo "none")
        CURRENT_INITRD=$(readlink /run/current-system/initrd || echo "none")

        # If the currently activated configuration has a different kernel or initrd
        # than what the machine actually booted with, flag it for Kured.
        if [ "$BOOTED_KERNEL" != "$CURRENT_KERNEL" ] || [ "$BOOTED_INITRD" != "$CURRENT_INITRD" ]; then
          echo "Kernel or initrd update detected. Tagging for Kured reboot."
          touch /run/kured/reboot-required
        else
          echo "No reboot required."
          rm -f /run/kured/reboot-required
        fi
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    libraryofalexandria.helmCharts.enable = true;
    libraryofalexandria.helmCharts.charts = [
      {
        name = "kured";
        chart = "kured/kured";
        version = config.libraryofalexandria.control-plane.kured.version;
        values = lib2.deepMerge [
          {
            configuration = {
              # The sentinel file your NixOS systemd script touches
              rebootSentinel = "/run/kured/reboot-required";

              forceReboot = true;
              drainGracePeriod = 60;

              # Ensure Kured only reboots 1 node at a time
              concurrency = 1;

              period = "1m";
              rebootCommand = "/run/current-system/sw/bin/systemctl reboot";
            };

            # Tolerations allowing the DaemonSet to run on RKE2 control plane nodes
            tolerations = [
              {
                effect = "NoSchedule";
                key = "node-role.kubernetes.io/master";
                operator = "Exists";
              }
              {
                effect = "NoSchedule";
                key = "node-role.kubernetes.io/control-plane";
                operator = "Exists";
              }
              {
                effect = "NoExecute";
                key = "node.kubernetes.io/not-ready";
                operator = "Exists";
              }
              {
                effect = "NoExecute";
                key = "node.kubernetes.io/unreachable";
                operator = "Exists";
              }
            ];
          }
          config.libraryofalexandria.control-plane.kured.values
        ];
        namespace = "kube-system";
        repo = "https://kubereboot.github.io/charts/";
      }
    ];
  };
}
