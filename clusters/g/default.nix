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
      imports = [
        ../k/submodules/kevint.nix
      ];

      config = {
        time.timeZone = "Etc/UTC";
        nixpkgs.hostPlatform = "x86_64-linux";
        # vmImage.size = "20G";

        libraryofalexandria = {
          zarf.enable = lib.mkForce false;
        };

        security.pam.u2f.settings = {
          # we're abusing the k cluster's kevint module
          origin = lib.mkForce "pam://k.loa.internal";
          appid = lib.mkForce "pam://k.loa.internal";
        };
      };
    };
in
{
  config.libraryofalexandria.cluster = {
    name = "g";
    id = 2;

    masters = {
      count = 1;
      ips = [
        "172.24.2.21"
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

    apps.loa-core.valuesOverrides.seaweedfs.size = "230G";
    apps.loa-core.valuesOverrides.cloudflareExternaldns.enabled = "false";
    federateTo = [ "k" ];

    virtualIps = {
      enable = true;
      k8sApiVip = "172.24.2.30";
      blocks = [
        {
          start = "172.24.2.31";
          stop = "172.24.2.250";
        }
      ];
      reservations = {
        dns = "172.24.2.249";
      };
      interfaces = [ "enp0s9" ];
    };
    externalDomain = "g.kpt.link";
  };
}
