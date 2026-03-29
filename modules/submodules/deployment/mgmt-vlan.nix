{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.libraryofalexandria.node.deployment.mgmtVlan = {
    enable = lib.mkEnableOption "Configure a mgmt-specific vlan";

    vlanId = lib.mkOption {
      type = lib.types.ints.between 1 4096;
    };

    iface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
    };

    staticIp = lib.mkOption {
      type = lib.types.str;
    };

    staticIpPrefixLength = lib.mkOption {
      description = "subnet mask length";
      type = lib.types.ints.between 1 32;
      default = 24;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
    };
  };

  config =
    let
      thisConfig = config.libraryofalexandria.node.deployment.mgmtVlan;
      mgmtVlan = "clustermgmt${toString thisConfig.vlanId}";
      isStaticIpSet = thisConfig.staticIp != "";
      shouldUseDhcp = !isStaticIpSet;
    in
    lib.mkIf thisConfig.enable {
      networking.vlans = {
        "${mgmtVlan}" = {
          id = thisConfig.vlanId;
          interface = thisConfig.iface;
        };
      };

      networking.interfaces.${mgmtVlan} = {
        useDHCP = shouldUseDhcp;
        ipv4.addresses = lib.mkIf isStaticIpSet [
          {
            address = thisConfig.staticIp;
            prefixLength = thisConfig.staticIpPrefixLength;
          }
        ];
      };

      services.openssh = {
        listenAddresses = lib.mkForce [
          (
            {
              port = thisConfig.port;
            }
            // lib.mkIf isStaticIpSet {
              addr = thisConfig.staticIp;
            }
          )
        ];
      };
    };
}
