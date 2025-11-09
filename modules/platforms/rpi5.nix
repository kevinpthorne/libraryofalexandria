{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ../platform.nix
        inputs.raspberry-pi-nix.nixosModules.raspberry-pi
        inputs.raspberry-pi-nix.nixosModules.sd-image
        ../submodules/imageable.nix
        # ../submodules/arm64/coredns-fix.nix  # TODO enable if kubernetes engine is picked. this isn't needed for rke2
        # ../submodules/arm64/etcd-fix.nix
        ../submodules/rpi/cgroup.nix
        inputs.disko.nixosModules.disko
        ../submodules/disko-layouts/one-data-partition.nix
    ];

    config = {
        libraryofalexandria.node.platform = "rpi5";
        nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

        networking = {
            useDHCP = false;
            interfaces = {
                wlan0.useDHCP = false;
                eth0.useDHCP = true;  # master IPs need to be reserved in DHCP server
            };
        };
        raspberry-pi-nix.board = "bcm2712"; # pi 5
        security.rtkit.enable = true;

        sdImage.imageBaseName = config.networking.hostName;
        system.builder = {
            package = config.system.build.sdImage;
            outputDir = "sd-image";
        };

        # TODO throw in separate optional module; pi5+nvme ssd
        boot.kernelModules = [ "sdhci_pci" ];
        fileSystems."/var" = {
            device = "/dev/nvme0n1";
            fsType = "ext4";
            # autoFormat = true;  # letting disko do this instead
            label = "data";
            options = [ "defaults" "noatime" ];
            # Ensure this directory is created on system activation
            neededForBoot = true;
        };
        services.fstrim.enable = true;
        environment.systemPackages = with pkgs; [
            e2fsprogs   # Provides filesystem utilities like tune2fs, fsck for ext4
        ];
        disko.devices.disk.data = { # disk is called 'data'
            imageSize = "2T";
            device = "/dev/nvme0n1";
        };
            
    };
}