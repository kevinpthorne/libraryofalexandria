nodeConfig:
{ pkgs, lib, ... }:
let
    iamConfig = import ./iam.nix;
    iamUserKeys = builtins.attrNames iamConfig;
    iamUserKeysWithHost = builtins.filter (user: builtins.hasAttr "host" iamConfig."${user}") iamUserKeys;
    hostUsers = builtins.map (user: { "${user}" = iamConfig."${user}".host; }) iamUserKeysWithHost;
    deepMerge = import ../libraryofalexandria/logic/deep-merge.nix lib;
in
{
    config = {
        users.users = deepMerge hostUsers;
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        nix.settings.trusted-users = [ "root" "@wheel" ];
        environment.systemPackages = with pkgs; [ vim ];
    };
}