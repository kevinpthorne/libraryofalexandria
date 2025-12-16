{ cluster, nodeId }:
{ lib, config, ... }: 
{
    imports = [
       ../../modules/apps.nix 
    ];

    config = {
        libraryofalexandria = {
            node.type = "master";
            apps = cluster.apps;
        };
    };
}