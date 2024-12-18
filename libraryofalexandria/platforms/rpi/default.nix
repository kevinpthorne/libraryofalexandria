nodeConfig:
let
 hostname = let
            prefix = if nodeConfig.hostnamePrefix != "" then nodeConfig.hostnamePrefix + "-" else "";
            nodeType = if nodeConfig.isMaster then "master" else "worker";
            nodeNumber = "-" + toString nodeConfig.nodeNumber;
          in
            prefix + nodeType + nodeNumber;
in
{
  time.timeZone = "America/New_York";
  users.users = {
    root.initialPassword = "root";
    kevint = {
      isNormalUser = true;
      home = "/home/kevint";
      extraGroups = [ "wheel" "networkmanager" ];
    };
  };
  deployment = {
    targetHost = hostname;
    targetPort = 22;
    targetUser = "kevint";
  };
  networking = {
    hostName = hostname;
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
