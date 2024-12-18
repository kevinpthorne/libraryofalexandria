nodeConfig:
let
    iamConfig = import ./iam.nix;
    iamUserKeys = builtins.attrNames iamConfig;
    hostUsers = builtins.map (user: { "${user}" = iamConfig."${user}".host; }) iamUserKeys;
in
{
    users.users = builtins.map (user: user.host) (import ./iam.nix);
}