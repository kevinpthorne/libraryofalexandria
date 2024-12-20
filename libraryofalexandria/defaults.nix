nodeConfig:
{ pkgs, lib, ... }:
let
    iamConfig = import ./iam.nix;
    iamUserKeys = builtins.attrNames iamConfig;
    hostUsers = builtins.map (user: { "${user}" = iamConfig."${user}".host; }) iamUserKeys;
in
{
    config = {
        users.users = builtins.map (user: user.host) (import ./iam.nix);
        nix.trustedUsers = [ "root" "@wheel" ];
        environment.systemPackages = with pkgs; [ vim ];
    };
}