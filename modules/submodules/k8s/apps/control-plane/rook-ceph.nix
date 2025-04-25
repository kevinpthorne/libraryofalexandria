{ lib, lib2, config, ... }:
{
    imports = [ ../../helm-charts.nix ];

    options.libraryofalexandria.apps.rook-ceph = {
        enable = lib.mkEnableOption "";

        version = lib.mkOption {
            default = "1.16.6";
            type = lib.types.str;
        };

        # values = lib.mkOption {
        #     default = {};
        #     type = lib.types.attrs;
        # };
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
                    # TODO allow overrides - idk how disks are being decided currently and rpis shouldnt use sd cards
                };
                namespace = "rook-ceph";
            }
        ];
    };
}