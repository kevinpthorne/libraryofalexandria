{ platform, clusterLabel, hostname, ... } @ nodeConfig:
{ pkgs, lib, ... }:
let
    importIfExists = import ../libraryofalexandria/logic/import-if-exists.nix;
    deepMerge = import ../libraryofalexandria/logic/deep-merge.nix lib;
    #
    platformBase = import ../libraryofalexandria/platforms/${platform} nodeConfig { pkgs=pkgs; lib=lib; };
    clusterOverrides = importIfExists ../libraryofalexandria/clusters/${clusterLabel}/default.nix nodeConfig { pkgs=pkgs; lib=lib; };
    #
    iamConfig = import ./iam.nix;
    iamUserKeys = builtins.attrNames iamConfig;
    iamUserKeysWithHost = builtins.filter (user: builtins.hasAttr "host" iamConfig."${user}") iamUserKeys;
    hostUsersList = builtins.map (user: { "${user}" = iamConfig."${user}".host; }) iamUserKeysWithHost;
    colmenaUser = "colmena";
    hostUsersListWithColmenaUser = hostUsersList ++ [ (import ./colmena-user.nix colmenaUser) ];
    allHostUsers = deepMerge hostUsersListWithColmenaUser;
in
deepMerge [ clusterOverrides platformBase {
    config = {
        system.stateVersion = "24.05";

        time.timeZone = "Etc/UTC";
        users.users = allHostUsers;  # IAM + colmena

        # containerd requirement
        boot.kernelParams = [
            "cgroup_enable=cpuset"
            "cgroup_enable=memory"
        ];

        # colmena means of deployment
        deployment = {
            targetHost = hostname;
            targetPort = 22;
            targetUser = colmenaUser;
        };
        networking.hostName = hostname;
        services = {
            openssh.enable = true;
        };
        security.sudo.extraRules = [
            {  
                users = [ colmenaUser ];
                commands = [
                    { 
                        command = "ALL";
                        options= [ "NOPASSWD" ]; # "SETENV" # Adding the following could be a good idea
                    }
                ];
            }
        ];
        

        nix.settings = {
            experimental-features = [ "nix-command" "flakes" ];
            trusted-users = [ "root" colmenaUser ];
        };

        environment.systemPackages = with pkgs; [
            vim
            curl
            htop
            k9s
        ];
    };
} ]