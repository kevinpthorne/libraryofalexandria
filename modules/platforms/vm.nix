{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ../platform.nix
        inputs.disko.nixosModules.disko
        ../submodules/imageable.nix
        ../submodules/simple-efi.nix
    ];

    options = {
        vmHostPlatform = lib.mkOption {
            default = "x86_64-linux";
            type = lib.types.enum [ "x86_64-linux" "aarch64-linux" ];  # TODO hook to eachArch from flake input
        };
        vmImage = {
            name = lib.mkOption {
                default = "${config.vmImage.baseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.qcow2";
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
        };
    };

    config = let 
        compressArgs = if config.vmImage.compress then "-c" else "";
    in {
        libraryofalexandria.node.platform = "vm";
        nixpkgs.hostPlatform = lib.mkDefault config.vmHostPlatform;

        # disko.imageBuilder.enableBinfmt = true;  # TODO this needs to be enabled for cross compilation
        disko.devices.disk.main.imageSize = "7G";  # disk is called 'main'

        vmImage.baseName = config.networking.hostName;
        system.builder = {
            package = pkgs.callPackage ({ stdenv, qemu }:
                stdenv.mkDerivation {
                    name = config.vmImage.name;
                    src = ./.;

                    buildInputs = [ qemu ];

                    buildPhase = ''
                        mkdir -p $out/raw-image
                        cd $out/raw-image
                        ${config.system.build.diskoImagesScript} --build-memory 4096
                        ${pkgs.qemu}/bin/qemu-img convert -p -f raw -O qcow2 ${compressArgs} main.raw main.qcow2
                        rm main.raw
                    '';
                    # https://github.com/nix-community/disko/blob/v1.11.0/docs/disko-images.md
                    # nix build .#nixosConfigurations.myhost.config.system.build.diskoImagesScript
                    # sudo ./result --build-memory 2048
                }
            ) {};
            outputDir = "raw-image";
        };
    };
}