{ cluster, nodeId }:
{ lib, config, ... }: 
{
    config = {
        libraryofalexandria = {
            node.type = "master";
            apps = cluster.apps;
        };
    };
}