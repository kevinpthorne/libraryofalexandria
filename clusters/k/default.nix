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
      imports = [
        ./submodules/kevint.nix
      ];

      config = {
        time.timeZone = "Etc/UTC";

        libraryofalexandria.node.deployment = {
          mgmtVlan = {
            enable = true;
            vlanId = 101;
            iface = "end0";
            staticIp = "192.168.101.${toString ipLastOctet}";
          };
          colmena.hostName = "192.168.101.${toString ipLastOctet}";
          # writing note for posterity: 1) sshOptions isn't real in this version of colmena
          # meaning 2) laptop4-builder currently has all sshOptions manually set in ~/.ssh/config
          # 3) the buidler VM can't reach the mgmt vlan directly, so I set up a jumphost on the host
          # 4) colmena's key is on my mac user, gross
          # 5) mac becomes jumphost
        };

        networking = {
          enableIPv6 = false;

          nameservers = [ "192.168.121.1" ];
          defaultGateway = "192.168.121.1";

          interfaces = {
            end0 = {
              useDHCP = false;
              ipv4.addresses = [
                {
                  address = "192.168.121.${toString ipLastOctet}";
                  prefixLength = 24; # Equivalent to subnet mask 255.255.255.0
                }
              ];
            };
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
    federateTo = [ "test" ];

    virtualIps = {
      enable = true;
      k8sApiVip = "192.168.121.30";
      blocks = [
        {
          start = "192.168.121.31";
          stop = "192.168.121.250";
        }
      ];
      interfaces = [ "end0" ];
    };
    externalDomain = "k.kpt.link";
  };
}
