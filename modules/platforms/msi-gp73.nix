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

    # Using GRUB with OS Prober to detect the existing Windows installation on the other NVMe
    boot.loader.grub.enable = true;
    boot.loader.grub.efiSupport = true;
    # Must be false when efiInstallAsRemovable is true
    boot.loader.efi.canTouchEfiVariables = false;
    # Install fallback EFI bootloader in case MSI BIOS wipes NVRAM
    boot.loader.grub.efiInstallAsRemovable = true;
    # Install MBR bootloader to the 1MB EF02 partition as a secondary fallback
    boot.loader.grub.device = "/dev/disk/by-id/nvme-WDS100T3X0C-00SJG0_204181800580";
    boot.loader.grub.useOSProber = false;  # I accidentally wiped windows and dont want to boot into the alter-nixos
    boot.loader.efi.efiSysMountPoint = "/boot";

    disko.devices.disk.main.device = "/dev/disk/by-id/nvme-WDS100T3X0C-00SJG0_204181800580";

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
    
    # Suppress harmless but noisy PCIe Advanced Error Reporting (AER) spam 
    # and disable ASPM to ensure maximum PCIe stability for a plugged-in node
    boot.kernelParams = [ "pci=noaer" "pcie_aspm=off" ];

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
