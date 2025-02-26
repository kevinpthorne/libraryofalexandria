{ lib, config, ... }:
let
    importIfExists = import ../../lib/import-if-exists.nix;
    defaultModule = id: clusterName: masterIps: { pkgs, lib, ... }: {
        config = {
            nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
            time.timeZone = "Etc/UTC";

            libraryofalexandria.node.enable = true;
            libraryofalexandria.node = {
                inherit id clusterName masterIps;
            };
        };
    };
in {
    config.libraryofalexandria.cluster = {
        name = "k-new";

        masters = {
            count = 1;
            ips = [ "10.69.69.100" ];
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/rpi5.nix)
                (import ../../modules/node.nix)
                (defaultModule nodeId name masters.ips)
                ({ ... }: {
                    config.libraryofalexandria.node.type = "master";
                })
                (importIfExists ./master.nix)
                (importIfExists ./master-${toString nodeId}.nix)
            ];
        };
        workers = {
            count = 1;
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/rpi5.nix)
                (import ../../modules/node.nix)
                (defaultModule nodeId name masters.ips)
                (importIfExists ./worker.nix)
                (importIfExists ./worker-${toString nodeId}.nix)
            ];
        };
    };
}