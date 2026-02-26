{ modulesPath, pkgs, config, lib, inputs, ... }:
{
    imports = [
        ../platform.nix
        "${modulesPath}/virtualisation/vmware-image.nix"
        ../submodules/imageable.nix
        ../submodules/arm64/coredns-fix.nix
        ../submodules/arm64/etcd-fix.nix
    ];

    config = {
        libraryofalexandria.node.platform = "vmware";

        # Fix Virtualbox not finding disk
        boot.initrd.availableKernelModules = [ 
            "ata_piix" 
            "uhci_hcd" 
            "virtio_pci" 
            "virtio_scsi" 
            "virtio_blk" 
            "sd_mod" 
            "sr_mod" 
        ];

        # vmImage.baseName = config.networking.hostName;
        system.builder = let
                baseImage = config.system.build.image;
                fileName = "${config.networking.hostName}-${config.nixpkgs.hostPlatform.system}.vmdk";
            in {  # from imageable
            package = pkgs.runCommand fileName {} ''
                # pkgs.runCommand executes exactly this script, with no hidden phases.
                mkdir -p $out/${config.system.builder.outputDir}
                
                # Create the symlink directly
                ln -s ${baseImage} $out/${config.system.builder.outputDir}/${fileName}
            '';
            outputDir = "vmdk";
        };
    };
}