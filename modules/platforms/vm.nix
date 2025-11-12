{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ../platform.nix
        # TODO use https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/profiles/qemu-guest.nix
        inputs.disko.nixosModules.disko
        ../submodules/imageable.nix
        ../submodules/disko-layouts/simple-efi.nix
        ../submodules/arm64/coredns-fix.nix
        ../submodules/arm64/etcd-fix.nix
    ];

    options = {
        vmHostPlatform = lib.mkOption {
            default = "x86_64-linux";
            type = lib.types.enum [ "x86_64-linux" "aarch64-linux" ];  # TODO hook to eachArch from flake input
        };
        vmImage = {
            name = lib.mkOption {
                default = "${config.vmImage.baseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.${config.vmImage.format}";
                description = "Name of the generated image file.";
                type = lib.types.str;
            };

            baseName = lib.mkOption {
                default = "nixos-vm-image";
                description = "Prefix of the name of the generated image file.";
                type = lib.types.str;
            };

            compress = lib.mkOption {
                default = true;
                description = "Whether to compress the VM image";
                type = lib.types.bool;
            };

            format = lib.mkOption {
                default = "vmdk";
                type = lib.types.enum [ "vmdk" "qcow2" ];
            };
        };
    };

    config = let 
        compressArgs = if config.vmImage.compress then "-c" else "";
    in {
        libraryofalexandria.node.platform = "vm";
        nixpkgs.hostPlatform = lib.mkDefault config.vmHostPlatform;

        # disko.imageBuilder.enableBinfmt = true;  # TODO this needs to be enabled for cross compilation
        disko.devices.disk.main = { # disk is called 'main'
            imageSize = "30G";
            device = "/dev/vda";
        };
 
        boot.loader.grub = {
            enable = true;
            efiSupport = true;
            efiInstallAsRemovable = true;
        };
        boot.loader.efi.canTouchEfiVariables = false;

        boot.initrd.availableKernelModules = [
            "virtio_net"
            "virtio_pci"
            "virtio_mmio"
            "virtio_blk"
            "virtio_scsi"
            "9p"
            "9pnet_virtio"
        ];
        boot.initrd.kernelModules = [
            "virtio_balloon"
            "virtio_console"
            "virtio_rng"
            "virtio_gpu"
        ];

        boot.initrd.systemd.enable = true;
        boot.initrd.systemd.emergencyAccess = "$y$j9T$OdulIrdyeBIGiV8LaqL5l.$gY8IdefCxljU00.jJY9lfUIfz509nywS2AQKomQcac2";

        vmImage.baseName = config.networking.hostName;
        system.builder = {
            package = pkgs.callPackage ({ stdenv, qemu }:
                stdenv.mkDerivation {
                    name = config.vmImage.name;
                    src = ./.;

                    buildInputs = [ qemu ];

                    buildPhase = ''
                        mkdir -p $out/${config.system.builder.outputDir}
                        cd $out/${config.system.builder.outputDir}
                        ${config.system.build.diskoImagesScript} --build-memory 8192 --pre-format-files clusters/${config.libraryofalexandria.cluster.name}/keys/ /var/keys/
                        ${pkgs.qemu}/bin/qemu-img convert -p -f raw -O ${config.vmImage.format} ${compressArgs} main.raw main.${config.vmImage.format}
                        rm main.raw
                    '';
                    # https://github.com/nix-community/disko/blob/v1.11.0/docs/disko-images.md
                    # nix build .#nixosConfigurations.myhost.config.system.build.diskoImagesScript
                    # sudo ./result --build-memory 2048
                }
            ) {};
            outputDir = "${config.vmImage.format}-images";
        };
    };
}