nodeConfig:
{ pkgs, lib, ... }:
{
    config = {
        systemd.services.etcd = {
            environment = {
                ETCD_UNSUPPORTED_ARCH = "arm64";
            };
        };
    };
}