{ pkgs, lib, ... }:
{
    config = {
        networking.firewall = {
            enable = true;
            allowedTCPPorts = [ 8888 6443 ];
        };
    };
}