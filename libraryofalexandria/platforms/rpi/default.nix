nodeConfig:
{
  time.timeZone = "America/New_York";
  users.users.root.initialPassword = "root";
  networking = {
    hostName =  let
            prefix = if nodeConfig.hostnamePrefix != "" then nodeConfig.hostnamePrefix + "-" else "";
            nodeType = if nodeConfig.isMaster then "master" else "worker";
            nodeNumber = "-" + toString nodeConfig.nodeNumber;
          in
            prefix + nodeType + nodeNumber;
    useDHCP = false;
    interfaces = {
      wlan0.useDHCP = false;
      eth0.useDHCP = true;
    };
  };
  raspberry-pi-nix.board = "bcm2712"; # pi 5
  security.rtkit.enable = true;
  services = {
    openssh.enable = true;
  };
}
