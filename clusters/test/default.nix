{ lib, config, lib2, ... }:
let
    defaultModule = id: { pkgs, lib, ... }: {
        config = {
            time.timeZone = "Etc/UTC";
            nixpkgs.hostPlatform = "aarch64-linux";
            # vmImage.size = "20G";

            libraryofalexandria.node.deployment.colmena.hostName = "localhost";
        };
    };
in {
    config.libraryofalexandria.cluster = {
        name = "test";

        masters = {
            count = 3;
            ips = [ "192.168.56.12" "192.168.56.13" "192.168.56.14" ];
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

        apps.loa-core.values.overrides.seaweedfs.size = "1G";
        apps.loa-extras.enable = lib.mkForce true;
        apps.loa-federation.values.overrides.pgedge.instances = "2"; # TODO make not require quotes

        virtualIps = {
            enable = true;
            blocks = [{
                start = "192.168.56.100";
                end = "192.168.56.200";
            }];
        };
    };
}