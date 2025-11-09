{ cluster, nodeId }:
{ lib, ... }: 
{
    imports = [
       ../../modules/control-plane.nix 
    ];

    config = {
        libraryofalexandria = {
            node.type = "master";
            apps = cluster.apps;
        };
    };
}