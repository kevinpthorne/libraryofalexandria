{ lib, config, lib2, ... }:
let
    defaultModule = id: { pkgs, lib, ... }: {
        config = {
            time.timeZone = "Etc/UTC";
            vmHostPlatform = "aarch64-linux";

            libraryofalexandria.node.deployment.colmena = {
                hostName = "localhost";
            };
        };
    };
in {
    config.libraryofalexandria.cluster = {
        name = "test";

        masters = {
            count = 1;
            ips = [ "192.168.67.3" ];
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/vm.nix)
                (defaultModule nodeId)
                (lib2.importIfExists ./master.nix)
                (lib2.importIfExists ./master-${toString nodeId}.nix)
            ];
        };
        workers = {
            count = 1;
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/vm.nix)
                (defaultModule nodeId)
                (lib2.importIfExists ./worker.nix)
                (lib2.importIfExists ./worker-${toString nodeId}.nix)
            ];
        };
    };
}