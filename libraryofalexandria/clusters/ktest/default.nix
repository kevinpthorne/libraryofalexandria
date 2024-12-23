nodeConfig:
{ pkgs, lib, ... }:
{
    config = {
        time.timeZone = "America/New_York";

        users.users = {
            root.initialPassword = "root";
            kevint = {
                isNormalUser = true;
                home = "/home/kevint";
                extraGroups = [ "wheel" "networkmanager" ];
            };
        };

        boot.loader = {
            systemd-boot.enable = true;
            efi.canTouchEfiVariables = true;
        };
    };
}