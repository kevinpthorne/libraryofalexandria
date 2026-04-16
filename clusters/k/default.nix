{
  lib,
  config,
  lib2,
  ...
}:
let
  defaultModule =
    isMaster: id:
    let
      firstIpOctet = 21;
      ipLastOctet =
        if isMaster then
          firstIpOctet + id
        else
          firstIpOctet + id + config.libraryofalexandria.cluster.masters.count;
    in
    { pkgs, lib, ... }:
    {
      config = {
        time.timeZone = "Etc/UTC";

        libraryofalexandria.node.deployment.mgmtVlan = {
          enable = true;
          vlanId = 101;
          staticIp = "192.168.101.${toString ipLastOctet}";
        };

        networking = {
          vlans.lowtrust121 = {
            id = 121;
            interface = "eth0";
          };

          interfaces = {
            eth0.useDHCP = false;

            lowtrust121.ipv4.addresses = [
              {
                address = "192.168.121.${toString ipLastOctet}";
                prefixLength = 24; # Equivalent to subnet mask 255.255.255.0
              }
            ];
          };
        };
      };
    };
in
{
  config.libraryofalexandria.cluster = {
    name = "k";
    id = 2;

    masters = {
      count = 3;
      ips = [
        "192.168.121.21"
        "192.168.121.22"
        "192.168.121.23"
      ];
      modules =
        with config.libraryofalexandria.cluster;
        nodeId: [
          (import ../../modules/platforms/rpi5.nix)
          (defaultModule true nodeId)
          (lib2.importIfExists ./master.nix)
          (lib2.importIfExists ./master-${toString nodeId}.nix)
        ];
    };
    workers = {
      count = 2;
      modules =
        with config.libraryofalexandria.cluster;
        nodeId: [
          (import ../../modules/platforms/rpi5.nix)
          (defaultModule false nodeId)
          (lib2.importIfExists ./worker.nix)
          (lib2.importIfExists ./worker-${toString nodeId}.nix)
        ];
    };

    apps = lib.mkMerge [
      {
        loa-extras = {
          repo = "https://github.com/kevinpthorne/libraryofalexandria.git";
          subPath = "apps/loa-extras";
        };
      }
    ];
    federate-to = [ "test" ];

    virtualIps = {
      enable = true;
      k8sApiVip = "192.168.121.30";
      blocks = [
        {
          start = "192.168.121.31";
          stop = "192.168.121.250";
        }
      ];
      interfaces = [ "eth0.121" ];
    };
  };
}
