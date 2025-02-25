inputs @ { ... }:
let
    importIfExists = import ../../lib/import-if-exists.nix;
in
rec {
    name = "test";

    defaultModule = id: clusterName: masterIps: { pkgs, lib, ... }: {
        config = {
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
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