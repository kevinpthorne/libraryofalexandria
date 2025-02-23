disko:
{ pkgs, config, lib, ... }:
{
    imports = [
        disko.nixosModules.disko
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
        # disko.imageBuilder.enableBinfmt = true;  # TODO this needs to be enabled for cross compilation
        disko.devices.disk.main.imageSize = "5G";

        system.builder = {
            package = pkgs.callPackage ({ stdenv }:
                stdenv.mkDerivation {
                    name = config.vmImage.name;
                    src = ./.;

                    buildInputs = [
                        config.system.build.diskoImagesScript
                    ];

                    buildPhase = ''
                        mkdir -p $out/raw-image
                        cd $out/raw-image
                        sudo ${config.system.build.diskoImagesScript}
                    '';
                    # nix build .#nixosConfigurations.myhost.config.system.build.diskoImagesScript
                    # sudo ./result --build-memory 2048
                }
            ) {};
            outputDir = "raw-image";
        };
    };
}