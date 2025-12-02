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
            count = 3;
            ips = [ "10.69.69.100" "10.69.69.101" "10.69.69.102" ];
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/rpi5.nix)
                (defaultModule nodeId)
                (lib2.importIfExists ./master.nix)
                (lib2.importIfExists ./master-${toString nodeId}.nix)
            ];
        };
        workers = {
            count = 2;
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/rpi5.nix)
                (defaultModule nodeId)
                (lib2.importIfExists ./worker.nix)
                (lib2.importIfExists ./worker-${toString nodeId}.nix)
            ];
        };

        shared-apps = [ "core" "extras" ];
    };
}