{ lib, lib2, config, pkgs, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.longhorn = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "1.10.0";
            type = lib.types.str;
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.longhorn.enable {
        libraryofalexandria.helmCharts.charts = [
            {
                name = "longhorn-namespace";
                chart = "${pkgs.namespace-helm}";
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
                version = config.libraryofalexandria.apps.longhorn.version;
                # https://longhorn.io/docs/1.10.0/advanced-resources/deploy/customizing-default-settings/#using-helm
                values = lib2.deepMerge [{
                    defaultSettings = {
                        enablePSP = "true";
                        defaultDataLocality = "best-effort";
                        defaultReplicaCount = 2;
                        replicaAutoBalance = "true";
                        defaultDataPath = "/var/lib/longhorn";  # ensure to line this up with disk mounts
                    };
                } config.libraryofalexandria.apps.longhorn.values];
                namespace = "longhorn-system";
                repo = "https://charts.longhorn.io";
            }
        ];

        boot.kernelModules = [ "iscsi_tcp" ];  # v1 longhorn data engine requirement

        environment.systemPackages = with pkgs; [
            openiscsi   # v1 longhorn data engine requirement
            cryptsetup  # volume encryption via LUKS
            nfs-utils   # for RWX volumes
            gnugrep     # docs say we need the rest of these
            gawkInteractive
            util-linux
            #findmnt
            #blkid
            #lsblk
        ];
        services.openiscsi = {  # v1 longhorn data engine requirement
            enable = true;
            name = config.networking.hostName;
        };
        systemd.services.iscsid.serviceConfig = {  # workaround https://github.com/longhorn/longhorn/issues/2166#issuecomment-2994323945
            PrivateMounts = "yes";
            BindPaths = "/run/current-system/sw/bin:/bin";
        };
    };
}