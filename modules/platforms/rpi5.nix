{ pkgs, lib, ... }:
{
    imports = [
        ../submodules/rpi/coredns-fix.nix
        ../submodules/rpi/etcd-fix.nix
        ../submodules/rpi/cgroup.nix
    ];

    config = {
        networking = {
            useDHCP = false;
            interfaces = {
                wlan0.useDHCP = false;
                eth0.useDHCP = true;
            };
        };
        raspberry-pi-nix.board = "bcm2712"; # pi 5
        security.rtkit.enable = true;
    };
}