{ pkgs, config, lib, inputs, ... }:
{
    imports = [
        ../platform.nix
        inputs.disko.nixosModules.disko
        ../submodules/imageable.nix
        ../submodules/simple-efi.nix
    ];

    options.vmImage = {
        name = lib.mkOption {
            default = "${config.vmImage.baseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.raw";
            description = "Name of the generated image file.";
            type = lib.types.str;
        };

        baseName = lib.mkOption {
            default = "nixos-vm-image";
            description = "Prefix of the name of the generated image file.";
            type = lib.types.str;
        };
    };

    config = {
        libraryofalexandria.node.platform = "vm";
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

        # disko.imageBuilder.enableBinfmt = true;  # TODO this needs to be enabled for cross compilation
        disko.devices.disk.main.imageSize = "7G";  # disk is called 'main'

        vmImage.baseName = config.networking.hostName;
        system.builder = {
            package = pkgs.callPackage ({ stdenv }:
                stdenv.mkDerivation {
                    name = config.vmImage.name;
                    src = ./.;

                    buildPhase = ''
                        mkdir -p $out/raw-image
                        cd $out/raw-image
                        ${config.system.build.diskoImagesScript} --build-memory 4096
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