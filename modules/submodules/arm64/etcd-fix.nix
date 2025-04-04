{ pkgs, lib, config, ... }:
{
    config = lib.mkIf (config.nixpkgs.hostPlatform == "aarch64-linux") {
        systemd.services.etcd.environment = {
            ETCD_UNSUPPORTED_ARCH = "arm64";
        };
    };
}