inputs @ { ... }:
rec {
    name = "k";
    system = "aarch64-linux";

    defaultModule = id: clusterName: masterIps: { pkgs, lib, ... }: {
        config = {
            time.timeZone = "Etc/UTC";

            libraryofalexandria.node.enable = true;
            libraryofalexandria.node = {
                inherit id clusterName masterIps;
            };
        };
    };
    masters = {
        count = 1;
        ips = [ "10.69.69.100" ];
        modules = nodeId: [
            inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            inputs.raspberry-pi-nix.nixosModules.sd-image
            (import ../../modules/platforms/rpi5.nix)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
            (import ./master.nix)
        ];
    };
    workers = {
        count = 4;
        modules = nodeId: [
            inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            inputs.raspberry-pi-nix.nixosModules.sd-image
            (import ../../modules/platforms/rpi5.nix)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
        ];
    };
}