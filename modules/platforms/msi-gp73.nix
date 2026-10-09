{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

{
  imports = [
    ../platform.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.disko.nixosModules.disko
    ../submodules/disko-layouts/simple-efi.nix
  ];

  config = {
    libraryofalexandria.node.platform = "msi-gp73";
    nixpkgs.hostPlatform = "x86_64-linux";

    # Bootloader setup
    # Using GRUB with OS Prober to preserve and detect the existing Windows installation
    boot.loader.grub.enable = true;
    boot.loader.grub.efiSupport = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.grub.device = "nodev";
    boot.loader.grub.useOSProber = true;

    disko.devices.disk.main.device = "/dev/nvme0n1";

    # Hardware configuration for MSI GP73 (i7 8th gen)
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "nvme"
    ];
    boot.initrd.kernelModules = [ ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.extraModulePackages = [ ];

    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # GPU configuration (NVIDIA 1060)
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      # GTX 1060 (Pascal) does not support the open driver
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
    nixpkgs.config.allowUnfree = true;

    # Power management: Do not sleep when lid is closed
    services.logind.lidSwitch = "ignore";
    services.logind.lidSwitchExternalPower = "ignore";
    services.logind.lidSwitchDocked = "ignore";

    # Shutdown gracefully if AC power is lost (with a 1-minute grace period to plug it back in)
    services.acpid = {
      enable = true;
      handlers = {
        acPower = {
          event = "ac_adapter.*";
          action = ''
            for supply in /sys/class/power_supply/*; do
              if [ -f "$supply/type" ] && [ "$(cat "$supply/type")" = "Mains" ]; then
                if [ "$(cat "$supply/online")" = "0" ]; then
                  /run/current-system/sw/bin/shutdown -P +1 "AC power lost, shutting down in 1 minute"
                  exit 0
                fi
              fi
            done
          '';
        };
      };
    };

    # Server-node optimizations
    powerManagement.cpuFreqGovernor = "performance"; # Default is often powersave on laptops
    hardware.bluetooth.enable = false;
    networking.wireless.enable = false;

    # Disable sound to save resources
    hardware.pulseaudio.enable = false;
  };
}
