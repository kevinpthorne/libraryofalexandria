clusterConfig: nodeId:
{ pkgs, lib, ... }:
{
    imports = [
        ../../modules/node.nix
    ];

    config = {
        libraryofalexandria.node = {
            enable = true;
            clusterName = clusterConfig.name;
            masterIps = clusterConfig.masters.ips;
            id = nodeId;

            deployment.colmena.enable = (clusterConfig.deploymentMethod == "colmena");
        };
    };
}