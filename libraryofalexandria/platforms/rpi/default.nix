nodeConfig:
{ pkgs, lib, ... }:
{
  config = {
    users.users.root.initialPassword = "root";
    networking = {
      useDHCP = false;
      interfaces = {
        wlan0.useDHCP = false;
        eth0.useDHCP = true;
      };
    };
    raspberry-pi-nix.board = "bcm2712"; # pi 5
    security.rtkit.enable = true;
  };
}
