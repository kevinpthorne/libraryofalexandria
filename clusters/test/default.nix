{ lib, config, lib2, ... }:
let
    defaultModule = id: { pkgs, lib, ... }: {
        config = {
            time.timeZone = "Etc/UTC";
            vmHostPlatform = "aarch64-linux";
            # vmImage.size = "20G";

            libraryofalexandria.node.deployment.colmena.hostName = "localhost";
        };
    };
in {
    config.libraryofalexandria.cluster = {
        name = "test";

        masters = {
            count = 3;
            ips = [ "192.168.56.11" "192.168.56.9" "192.168.56.8" ];
            modules = let cluster = config; in with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/vm.nix)
                # (import ../../modules/submodules/stig.nix)
                (defaultModule nodeId)
                (lib2.importIfExistsArgs ./master.nix { inherit cluster nodeId; })
                (lib2.importIfExistsArgs ./master-${toString nodeId}.nix { inherit cluster nodeId; })
            ];
        };
        workers = {
            count = 0;
            modules = with config.libraryofalexandria.cluster; nodeId: [
                (import ../../modules/platforms/vm.nix)
                # (import ../../modules/submodules/stig.nix)
                (defaultModule nodeId)
                (lib2.importIfExistsArgs ./worker.nix { inherit cluster nodeId; })
                (lib2.importIfExistsArgs ./worker-${toString nodeId}.nix { inherit cluster nodeId; })
            ];
        };

        shared-apps = [ "core" "extras" ];
    };
}