raspberry-pi-nix:
{ pkgs, config, lib, ... }:
{
    imports = [
        raspberry-pi-nix.nixosModules.raspberry-pi
        raspberry-pi-nix.nixosModules.sd-image
        ../submodules/imageable.nix
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

        sdImage.imageBaseName = config.networking.hostName;
        system.builder = {
            package = config.system.build.sdImage;
            outputDir = "sd-image";
        };
    };
}