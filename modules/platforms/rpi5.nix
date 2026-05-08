{
  pkgs,
  config,
  lib,
  inputs,
  nixos-raspberrypi,
  ...
}:
{
  imports = with nixos-raspberrypi.nixosModules; [
    ../platform.nix
    # nvmd
    # Required: Add necessary overlays with kernel, firmware, vendor packages
    nixos-raspberrypi.lib.inject-overlays

    # Binary cache with prebuilt packages for the currently locked `nixpkgs`,
    # see `devshells/nix-build-to-cachix.nix` for a list
    trusted-nix-caches

    # Optional: All RPi and RPi-optimised packages to be available in `pkgs.rpi`
    nixpkgs-rpi

    # Optonal: add overlays with optimised packages into the global scope
    # provides: ffmpeg_{4,6,7}, kodi, libcamera, vlc, etc.
    # This overlay may cause lots of rebuilds (however many
    #  packages should be available from the binary cache)
    nixos-raspberrypi.lib.inject-overlays-global
    # nvmd rpi 5
    raspberry-pi-5.base
    raspberry-pi-5.page-size-16k
    raspberry-pi-5.display-vc4
    raspberry-pi-5.bluetooth
    # our stuff
    ../submodules/imageable.nix
    ../submodules/arm64/coredns-fix.nix
    ../submodules/arm64/etcd-fix.nix
    ../submodules/rpi/cgroup.nix
    inputs.disko.nixosModules.disko
    ../submodules/disko-layouts/simple-gpt.nix
    # ../submodules/disko-layouts/one-data-partition.nix
  ];

  config = {
    libraryofalexandria.node.platform = "rpi5";
    nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

    networking = {
      useDHCP = false;
      interfaces = {
        wlan0.useDHCP = lib.mkDefault false;
      };
    };
    security.rtkit.enable = true;

    system.builder = {
      package = nixos-raspberrypi.installerImages.rpi5;
      outputDir = "sd-image";
    };

    boot.kernelModules = [ "sdhci_pci" ];
    disko.devices.disk.main = {
      imageSize = "2T";
      device = "/dev/nvme0n1";
    };

  };
}
