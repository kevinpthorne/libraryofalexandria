{ cluster, nodeId }:
{ lib, ... }: 
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