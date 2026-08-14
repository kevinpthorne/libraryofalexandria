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
          node.deployment.colmena.hostName = "172.24.1.81";
          zarf.enable = lib.mkForce false;

          control-plane.longhorn.values.defaultSettings.defaultReplicaCount = "0";
        };

        networking = {
          enableIPv6 = true;

          nameservers = [
            "172.24.1.251"
            "172.24.1.252"
          ];
          defaultGateway = "172.24.1.2";

          interfaces = {
            ens33 = {
              useDHCP = false;
              ipv4.addresses = [
                {
                  address = "172.24.1.81";
                  prefixLength = 24; # Equivalent to subnet mask 255.255.255.0
                }
              ];
            };
          };
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
        "172.24.1.81"
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

    apps.loa-core.valuesOverrides.cloudflareExternaldns.enabled = false;
    federateTo = [ "k" ];

    virtualIps = {
      enable = true;
      k8sApiVip = "172.24.1.84";
      blocks = [
        {
          start = "172.24.1.85";
          stop = "172.24.1.95";
        }
      ];
      reservations = {
        dns = "172.24.1.95";
      };
      interfaces = [ "ens33" ];
    };
    externalDomain = "isp2.finepointsolutions.com";
  };
}
