inputs @ { ... }:
let
    importIfExists = import ../../lib/import-if-exists.nix;
in
rec {
    name = "k";

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
            (import ../../modules/platforms/rpi5.nix)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
            (importIfExists ./master.nix)
            (importIfExists ./master-${toString nodeId}.nix)
        ];
    };
    workers = {
        count = 1;
        modules = nodeId: [
            (import ../../modules/platforms/rpi5.nix)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
            (importIfExists ./worker.nix)
            (importIfExists ./worker-${toString nodeId}.nix)
        ];
    };
}