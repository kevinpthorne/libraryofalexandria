{
  lib,
  config,
  lib2,
  ...
}:
let
  defaultModule =
    id:
    { pkgs, lib, ... }:
    {
      config = {
        time.timeZone = "Etc/UTC";
        nixpkgs.hostPlatform = "aarch64-linux";
        # vmImage.size = "20G";

        libraryofalexandria = {
          node.deployment.colmena.hostName = "127.0.0.1";
          node.deployment.deploy-rs.hostName = "127.0.0.1";
          zarf.enable = lib.mkForce false;
          helmCharts.installerEnabled = true;
        };
      };
    };
in
{
  config.libraryofalexandria.cluster = {
    name = "test";
    id = 1;

    masters = {
      count = 1;
      ips = [
        "192.168.56.15"
        # "192.168.56.14"
        # "192.168.56.13"
      ];
      modules =
        let
          cluster = config;
        in
        with config.libraryofalexandria.cluster;
        nodeId: [
          (import ../../modules/platforms/vm.nix)
          # (import ../../modules/submodules/stig.nix)
          (defaultModule nodeId)
          (lib2.importIfExistsArgs ./master.nix { inherit cluster nodeId; })
          (lib2.importIfExistsArgs ./master-${toString nodeId}.nix { inherit cluster nodeId; })
        ];
    };
    workers = {
      count = 0;
      modules =
        with config.libraryofalexandria.cluster;
        nodeId: [
          (import ../../modules/platforms/vm.nix)
          # (import ../../modules/submodules/stig.nix)
          (defaultModule nodeId)
          (lib2.importIfExistsArgs ./worker.nix { inherit cluster nodeId; })
          (lib2.importIfExistsArgs ./worker-${toString nodeId}.nix { inherit cluster nodeId; })
        ];
    };

    apps.loa-core.valuesOverrides.seaweedfs.size = "1G";
    federate-to = [ "k" ];
    # apps.loa-voip.enable = lib.mkForce true;

    virtualIps = {
      enable = true;
      k8sApiVip = "192.168.56.100";
      blocks = [
        {
          start = "192.168.56.101";
          stop = "192.168.56.200";
        }
      ];
      interfaces = [ "enp0s9" ];
    };
  };
}
