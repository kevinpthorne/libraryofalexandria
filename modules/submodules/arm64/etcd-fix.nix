# on nixos kubernetes svc, arm64 binaries is needed instead of x86 default
{ pkgs, lib, config, ... }:
{
    config = lib.mkIf (config.libraryofalexandria.cluster.k8sEngine == "kubernetes" && config.a) {
        systemd.services.etcd.environment = {
            ETCD_UNSUPPORTED_ARCH = "arm64";
        };
    };
}