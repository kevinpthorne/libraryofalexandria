{ lib, config, lib2, ... }:
let
    defaultModule = id: { pkgs, lib, ... }: {
        config = {
            time.timeZone = "Etc/UTC";
        };
    };
in {
    config.libraryofalexandria.cluster = {
        name = "k";

        masters = {
            count = 1;
            ips = [ "10.69.69.100" ];
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/rpi5.nix)
                (defaultModule nodeId)
                (lib2.importIfExists ./master.nix)
                (lib2.importIfExists ./master-${toString nodeId}.nix)
            ];
        };
        workers = {
            count = 1;
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/rpi5.nix)
                (defaultModule nodeId)
                (lib2.importIfExists ./worker.nix)
                (lib2.importIfExists ./worker-${toString nodeId}.nix)
            ];
        };
    };
}