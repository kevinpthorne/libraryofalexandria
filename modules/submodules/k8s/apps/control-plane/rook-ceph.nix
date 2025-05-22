{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.rook-ceph = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "1.16.6";
            type = lib.types.str;
        };

        devMode = lib.mkOption {
            default = false;
            type = lib.types.bool;
            description = "Disable replication";
        };

        values = lib.mkOption {
            default = {};
            type = lib.types.attrs;
        };
    };

    config = lib.mkIf config.libraryofalexandria.apps.rook-ceph.enable {
        libraryofalexandria.helmCharts.enable = true;
        libraryofalexandria.helmCharts.charts = [
            # rook-ceph https://rook.io/docs/rook/latest-release/Helm-Charts/operator-chart/
            {
                name = "rook-ceph";
                chart = "rook-ceph/rook-ceph";
                version = config.libraryofalexandria.apps.rook-ceph.version;
                values = {
                    csi = {
                        # nixos overrides
                        csiCephFSPluginVolume = [
                            {
                                name = "lib-modules";
                                hostPath.path = "/run/booted-system/kernel-modules/lib/modules/";
                            }
                            {
                                name = "host-nix";
                                hostPath.path = "/nix";
                            }
                        ];
                        csiCephFSPluginVolumeMount = [
                            {
                                name = "host-nix";
                                hostPath.path = "/nix";
                            }
                        ];
                        csiRBDPluginVolume = [
                            {
                                name = "lib-modules";
                                hostPath.path = "/run/booted-system/kernel-modules/lib/modules/";
                            }
                            {
                                name = "host-nix";
                                hostPath.path = "/nix";
                            }
                        ];
                        csiRBDPluginVolumeMount = [
                            {
                                name = "host-nix";
                                hostPath.path = "/nix";
                            }
                        ];
                    };
                    # TODO rook-ceph guide says crds.enabled = false needs to be set
                    pspEnable = true;
                };
                namespace = "rook-ceph";
                repo = "https://charts.rook.io/release";
            }
            {
                name = "rook-ceph-cluster";
                chart = "rook-ceph/rook-ceph-cluster"; # reuses repo from above
                version = config.libraryofalexandria.apps.rook-ceph.version;
                values = {
                    operatorNamespace = "rook-ceph";
                    cephClusterSpec = {
                        mgr.count = 
                            let
                                mgrCount = if config.libraryofalexandria.apps.rook-ceph.devMode then 1 else 3;
                            in
                            mgrCount;
                        mon = {
                            allowMultiplePerNode = config.libraryofalexandria.apps.rook-ceph.devMode;
                            count = 
                            let
                                morCount = if config.libraryofalexandria.apps.rook-ceph.devMode then 1 else 3;
                            in
                            monCount;
                        };
                        network.connections.encryption.enabled = true;
                        resources.osd.requests = {
                            cpu = "500m";  # 1000m default
                            memory = "1Gi"; # 4Gi default, 4Gi limit
                        };
                        storage = {
                            useAllNodes = true;
                            useAllDevices = true;
                        };
                    };
                    pspEnable = true;
                };
                namespace = "rook-ceph";
            }
        ];
    };
}