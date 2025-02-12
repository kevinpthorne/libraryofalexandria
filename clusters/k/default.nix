inputs @ { ... }:
rec {
    name = "k";
    system = "aarch64-linux";

    defaultModule = nodeId: clusterName: masterIps: { pkgs, lib, ... }: {
        config = {
            time.timeZone = "Etc/UTC";

            libraryofalexandria.node.enable = true;
            libraryofalexandria.node = {
                inherit nodeId clusterName masterIps;
            };
        };
    };
    masters = {
        count = 1;
        ips = [ "10.69.69.100" ];
        modules = nodeId: [
            inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            inputs.raspberry-pi-nix.nixosModules.sd-image
            defaultModule nodeId name masters.ips ## TODO fix me
            import ./master.nix
        ];
    };
    workers = {
        count = 4;
        modules = nodeId: [
            inputs.raspberry-pi-nix.nixosModules.raspberry-pi
            inputs.raspberry-pi-nix.nixosModules.sd-image
            defaultModule nodeId name masters.ips
        ];
    };
}