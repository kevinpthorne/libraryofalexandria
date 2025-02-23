inputs @ { ... }:
let
    importIfExists = import ../../lib/import-if-exists.nix;
in
rec {
    name = "test";
    system = "aarch64-linux";  # TODO make this a node-level override

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
        ips = [ "192.168.67.3" ];
        modules = nodeId: [
            (import ../../modules/platforms/vm.nix inputs.disko)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
            (importIfExists ./master.nix)
            (importIfExists ./master-${toString nodeId}.nix)
        ];
    };
    workers = {
        count = 1;
        modules = nodeId: [
            (import ../../modules/platforms/vm.nix inputs.disko)
            (import ../../modules/node.nix)
            (defaultModule nodeId name masters.ips)
            (importIfExists ./worker.nix)
            (importIfExists ./worker-${toString nodeId}.nix)
        ];
    };
}