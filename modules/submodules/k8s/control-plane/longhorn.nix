{
  lib,
  lib2,
  config,
  pkgs,
  ...
}:
{
  imports = [ ../helm ];

  config = lib.mkIf config.libraryofalexandria.control-plane.longhorn.enable {
    libraryofalexandria.helmCharts.charts = [
      {
        name = "longhorn-namespace";
        chart = "${pkgs.namespace-helm}/namespace-helm-0.1.0.tgz";
        values = {
          name = "longhorn-system";
          podSecurityLevel = {
            enforce = "privileged";
            audit = "privileged";
            warn = "privileged";
          };
        };
      }
      {
        name = "longhorn";
        chart = "longhorn/longhorn";
        version = config.libraryofalexandria.control-plane.longhorn.version;
        # https://longhorn.io/docs/1.10.0/advanced-resources/deploy/customizing-default-settings/#using-helm
        values = lib2.deepMerge [
          {
            image.longhorn = {
              # this 'promotes' longhorn to kube-system status
              engineManager.priorityClass = "system-node-critical";
              replicaManager.priorityClass = "system-node-critical";
            };
            defaultSettings = {
              enablePSP = "true";
              defaultDataLocality = "best-effort";

              defaultReplicaCount = "2";
              replicaAutoBalance = "true";
              # cap replica thrash/spikes
              replicaReplicaCountCheckInterval = "30";

              defaultDataPath = "/var/lib/longhorn"; # ensure to line this up with disk mounts
              storageOverProvisioningPercentage = "150";
            };
          }
          config.libraryofalexandria.control-plane.longhorn.values
        ];
        namespace = "longhorn-system";
        repo = "https://charts.longhorn.io";
      }
    ];

    boot.kernelModules = [
      "iscsi_tcp" # v1 longhorn data engine requirement
    ];

    environment.systemPackages = with pkgs; [
      openiscsi # v1 longhorn data engine requirement
      cryptsetup # volume encryption via LUKS
      nfs-utils # for RWX volumes
      gnugrep # docs say we need the rest of these
      gawkInteractive
      util-linux
      #findmnt
      #blkid
      #lsblk
    ];
    services.openiscsi = {
      # v1 longhorn data engine requirement
      enable = true;
      name = config.networking.hostName;
      extraConfig = ''
        node.conn[0].timeo.noop_out_interval = 10
        node.conn[0].timeo.noop_out_timeout = 30
        node.session.timeo.replacement_timeout = 120
      '';
    };
    systemd.services.iscsid.serviceConfig = {
      # workaround https://github.com/longhorn/longhorn/issues/2166#issuecomment-2994323945
      PrivateMounts = "yes";
      BindPaths = "/run/current-system/sw/bin:/bin";
      OOMScoreAdjust = -1000;
      CPUSchedulingPolicy = "rr";
      CPUSchedulingPriority = 50;
      IOSchedulingClass = "realtime";
      IOSchedulingPriority = 0;
    };
  };
}
