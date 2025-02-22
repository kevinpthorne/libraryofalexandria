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
            (import ../../modules/platforms/rpi5.nix inputs.raspberry-pi-nix)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
            (import ./master.nix)
        ];
    };
    workers = {
        count = 1;
        modules = nodeId: [
            (import ../../modules/platforms/rpi5.nix inputs.raspberry-pi-nix)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
        ];
    };
}