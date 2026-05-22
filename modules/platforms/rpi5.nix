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
    ../submodules/disko-layouts/simple-rpi-ext4.nix
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

    boot.loader.raspberry-pi.bootloader = "kernel";
    # Fix for NVMe dropouts, maybe due to sleep->wake power spikes
    boot.kernelParams = [
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "pcie_port_pm=off"
    ];
    disko.devices.disk.main = {
      imageSize = "2T";
      device = "/dev/nvme0n1";
    };

    hardware.raspberry-pi.config = {
      all = {
        # [all] conditional filter, https://www.raspberrypi.com/documentation/computers/config_txt.html#conditional-filters

        options = {
          # https://www.raspberrypi.com/documentation/computers/config_txt.html#enable_uart
          # in conjunction with `console=serial0,115200` in kernel command line (`cmdline.txt`)
          # creates a serial console, accessible using GPIOs 14 and 15 (pins
          #  8 and 10 on the 40-pin header)
          enable_uart = {
            enable = true;
            value = true;
          };
          # https://www.raspberrypi.com/documentation/computers/config_txt.html#uart_2ndstage
          # enable debug logging to the UART, also automatically enables
          # UART logging in `start.elf`
          uart_2ndstage = {
            enable = true;
            value = true;
          };
        };

        # Base DTB parameters
        # https://github.com/raspberrypi/linux/blob/a1d3defcca200077e1e382fe049ca613d16efd2b/arch/arm/boot/dts/overlays/README#L132
        base-dt-params = {

          # https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#enable-pcie
          pciex1 = {
            enable = true;
            value = "on";
          };
          # TODO Forcing gen 2 for temps
          # PCIe Gen 3.0
          # https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#pcie-gen-3-0
          pciex1_gen = {
            enable = true;
            value = "2";
          };

        };

      };
    };

    services.smartd = {
      enable = true;
      notifications.wall.enable = true; # Sends a terminal alert on failure

      # Scan all devices, but use specific settings for NVMe
      # -H: Check health status
      # -W: Track temperature (Warn at 70°C, Critical at 75°C)
      # https://documents.sandisk.com/content/dam/asset-library/en_us/assets/public/sandisk/product/internal-drives/wd-black-ssd/data-sheet-wd-black-sn770m-nvme-ssd.pdf
      defaults.monitored = "-a -H -W 0,70,75";  # outside of op is 85
    };
    environment.systemPackages = with pkgs; [
      nvme-cli
    ];

    services.chrony = {
      # theres no easy stupid RTC battery
      extraFlags = [ "-s" ];
    
      extraConfig = ''
        # Keep your makestep so it instantly jumps to the true time once NTP connects
        makestep 1.0 3
        
        # Forces Chrony to write measurement history to disk on a clean shutdown,
        # ensuring the file timestamp is as recent as possible.
        dumponexit
      '';
    };

  };
}
